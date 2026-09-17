import uuid
import time
from datetime import datetime, timezone
from typing import List, Optional, Tuple, Dict
from fastapi import HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from core.file_validator import (
    validate_file,
    MAX_FILE_SIZE_BYTES,
    MAX_CASE_ATTACHMENTS_SIZE_BYTES,
)
from models.case import Case
from models.attachment import Attachment
from models.audit import AuditLog
from models.user import User
from models.enums import UserRole, CaseStatus
from providers.storage.base import StorageProvider
from providers.storage import get_storage_provider
from schemas.attachment import AttachmentOut, AttachmentDownloadOut, CaseAttachmentQuotaOut


# In-memory idempotency cache: (idempotency_key, case_id) -> (created_timestamp, attachment_id)
# Evicted after 24 hours per SRS §3.6
_idempotency_store: Dict[Tuple[str, uuid.UUID], Tuple[float, uuid.UUID]] = {}
IDEMPOTENCY_TTL_SECONDS = 86400  # 24 hours


def _get_idempotent_attachment_id(key: str, case_id: uuid.UUID) -> Optional[uuid.UUID]:
    cache_key = (key, case_id)
    if cache_key in _idempotency_store:
        created_at, att_id = _idempotency_store[cache_key]
        if time.time() - created_at < IDEMPOTENCY_TTL_SECONDS:
            return att_id
        else:
            del _idempotency_store[cache_key]
    return None


def _set_idempotent_attachment_id(key: str, case_id: uuid.UUID, att_id: uuid.UUID) -> None:
    # Clean up expired entries if store grows large
    if len(_idempotency_store) > 1000:
        now = time.time()
        expired = [k for k, (ts, _) in _idempotency_store.items() if now - ts >= IDEMPOTENCY_TTL_SECONDS]
        for k in expired:
            del _idempotency_store[k]
    _idempotency_store[(key, case_id)] = (time.time(), att_id)


class AttachmentService:
    """Service orchestrating evidence uploads, quota enforcement, storage dispatch, and audit logging."""

    def __init__(self, db: AsyncSession, storage_provider: Optional[StorageProvider] = None):
        self.db = db
        self.storage = storage_provider or get_storage_provider()

    async def _get_accessible_case(
        self,
        case_id: uuid.UUID,
        current_user: User,
        for_mutation: bool = False,
    ) -> Case:
        """Fetch case and enforce RBAC and lifecycle mutation restrictions per SRS §2.2 & §6.1."""
        stmt = select(Case).where(Case.id == case_id, Case.deleted_at.is_(None))
        result = await self.db.execute(stmt)
        case = result.scalar_one_or_none()

        if not case:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "CASE_NOT_FOUND",
                        "message": f"Case {case_id} not found.",
                        "details": {},
                    }
                },
            )

        # Requesters can only access their own cases
        if current_user.role == UserRole.REQUESTER and case.requester_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "You do not have permission to access attachments for this case.",
                        "details": {},
                    }
                },
            )

        # Mutation restriction on Closed or Cancelled cases for Requesters
        if for_mutation and current_user.role == UserRole.REQUESTER:
            if case.status in (CaseStatus.CLOSED, CaseStatus.CANCELLED):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={
                        "error": {
                            "code": "CASE_CLOSED_OR_CANCELLED",
                            "message": f"Cannot add or modify attachments on a {case.status.value} case.",
                            "details": {"status": case.status.value},
                        }
                    },
                )

        return case

    async def get_case_quota(
        self,
        case_id: uuid.UUID,
        current_user: User,
    ) -> CaseAttachmentQuotaOut:
        """Calculate current cumulative storage consumption for a case per SRS §7.5."""
        case = await self._get_accessible_case(case_id, current_user, for_mutation=False)

        stmt = select(
            func.coalesce(func.sum(Attachment.file_size), 0).label("used_bytes"),
            func.count(Attachment.id).label("attachment_count"),
        ).where(Attachment.case_id == case.id)
        
        res = await self.db.execute(stmt)
        row = res.one()
        used_bytes = int(row.used_bytes)
        count = int(row.attachment_count)
        remaining = max(0, MAX_CASE_ATTACHMENTS_SIZE_BYTES - used_bytes)
        pct = round((used_bytes / MAX_CASE_ATTACHMENTS_SIZE_BYTES) * 100, 2)

        return CaseAttachmentQuotaOut(
            case_id=case.id,
            used_bytes=used_bytes,
            max_bytes=MAX_CASE_ATTACHMENTS_SIZE_BYTES,
            remaining_bytes=remaining,
            attachment_count=count,
            used_percentage=pct,
        )

    async def upload_attachment(
        self,
        case_id: uuid.UUID,
        current_user: User,
        file_name: str,
        file_bytes: bytes,
        content_type: Optional[str] = None,
        idempotency_key: Optional[str] = None,
    ) -> AttachmentOut:
        """
        Validate, store, and record a new attachment on a case.
        Enforces binary magic-bytes validation, 10MB file limit, 50MB case quota,
        server-generated UUID storage paths, and emits an immutable AuditLog entry.
        """
        # Check idempotency first if key is provided
        if idempotency_key:
            existing_id = _get_idempotent_attachment_id(idempotency_key, case_id)
            if existing_id:
                existing_att = await self.get_attachment(existing_id, current_user)
                return existing_att

        case = await self._get_accessible_case(case_id, current_user, for_mutation=True)

        # 1. Validate file extension, size, and magic bytes
        safe_name, verified_mime, file_size = validate_file(
            file_name=file_name,
            file_bytes=file_bytes,
            declared_content_type=content_type,
        )

        # 2. Enforce 50MB cumulative case quota per SRS §7.5
        quota = await self.get_case_quota(case.id, current_user)
        if quota.used_bytes + file_size > MAX_CASE_ATTACHMENTS_SIZE_BYTES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "CASE_ATTACHMENT_QUOTA_EXCEEDED",
                        "message": (
                            f"Uploading this file ({file_size // 1024} KB) would exceed the "
                            f"50MB case limit. Current usage: {quota.used_bytes // 1024} KB."
                        ),
                        "details": {
                            "used_bytes": quota.used_bytes,
                            "attempted_file_bytes": file_size,
                            "max_bytes": MAX_CASE_ATTACHMENTS_SIZE_BYTES,
                            "remaining_bytes": quota.remaining_bytes,
                        },
                    }
                },
            )

        # 3. Generate server-side UUID storage path per SRS §7.5
        ext = safe_name.rsplit(".", 1)[-1].lower()
        storage_uuid = str(uuid.uuid4())
        storage_path = f"cases/{case.id}/{storage_uuid}.{ext}"

        # 4. Upload to active storage provider (Supabase / Local)
        uploaded_path = await self.storage.upload_file(
            storage_path=storage_path,
            data=file_bytes,
            content_type=verified_mime,
        )

        # 5. Persist Attachment entity in database
        now = datetime.now(timezone.utc)
        attachment = Attachment(
            case_id=case.id,
            file_name=safe_name,
            storage_path=uploaded_path,
            file_type=verified_mime,
            file_size=file_size,
            uploaded_by=current_user.id,
            created_at=now,
        )
        self.db.add(attachment)
        await self.db.flush()

        # 6. Record append-only AuditLog entry per SRS §5.11
        audit = AuditLog(
            actor_id=current_user.id,
            action="ATTACHMENT_UPLOADED",
            target_type="case",
            target_id=case.id,
            before_value=None,
            after_value={
                "attachment_id": str(attachment.id),
                "file_name": safe_name,
                "file_type": verified_mime,
                "file_size": file_size,
                "storage_path": uploaded_path,
            },
            created_at=now,
        )
        self.db.add(audit)
        await self.db.commit()
        await self.db.refresh(attachment)

        # Store idempotency mapping if key provided
        if idempotency_key:
            _set_idempotent_attachment_id(idempotency_key, case.id, attachment.id)

        return AttachmentOut(
            id=attachment.id,
            case_id=attachment.case_id,
            file_name=attachment.file_name,
            storage_path=attachment.storage_path,
            file_type=attachment.file_type,
            file_size=attachment.file_size,
            uploaded_by=attachment.uploaded_by,
            uploader_email=current_user.email,
            created_at=attachment.created_at,
        )

    async def list_case_attachments(
        self,
        case_id: uuid.UUID,
        current_user: User,
    ) -> List[AttachmentOut]:
        """List all attachments for an accessible case."""
        case = await self._get_accessible_case(case_id, current_user, for_mutation=False)

        stmt = (
            select(Attachment)
            .options(selectinload(Attachment.uploader))
            .where(Attachment.case_id == case.id)
            .order_by(Attachment.created_at.asc())
        )
        result = await self.db.execute(stmt)
        items = result.scalars().all()

        return [
            AttachmentOut(
                id=att.id,
                case_id=att.case_id,
                file_name=att.file_name,
                storage_path=att.storage_path,
                file_type=att.file_type,
                file_size=att.file_size,
                uploaded_by=att.uploaded_by,
                uploader_email=att.uploader.email if att.uploader else None,
                created_at=att.created_at,
            )
            for att in items
        ]

    async def get_attachment(
        self,
        attachment_id: uuid.UUID,
        current_user: User,
    ) -> AttachmentOut:
        """Fetch attachment metadata by ID with case access verification."""
        stmt = (
            select(Attachment)
            .options(selectinload(Attachment.uploader))
            .where(Attachment.id == attachment_id)
        )
        result = await self.db.execute(stmt)
        attachment = result.scalar_one_or_none()

        if not attachment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "ATTACHMENT_NOT_FOUND",
                        "message": f"Attachment {attachment_id} not found.",
                        "details": {},
                    }
                },
            )

        # Enforce case access rules
        await self._get_accessible_case(attachment.case_id, current_user, for_mutation=False)

        return AttachmentOut(
            id=attachment.id,
            case_id=attachment.case_id,
            file_name=attachment.file_name,
            storage_path=attachment.storage_path,
            file_type=attachment.file_type,
            file_size=attachment.file_size,
            uploaded_by=attachment.uploaded_by,
            uploader_email=attachment.uploader.email if attachment.uploader else None,
            created_at=attachment.created_at,
        )

    async def get_download_url(
        self,
        attachment_id: uuid.UUID,
        current_user: User,
        expires_in: int = 3600,
    ) -> AttachmentDownloadOut:
        """Generate a secure presigned download URL for an attachment."""
        stmt = select(Attachment).where(Attachment.id == attachment_id)
        result = await self.db.execute(stmt)
        attachment = result.scalar_one_or_none()

        if not attachment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "ATTACHMENT_NOT_FOUND",
                        "message": f"Attachment {attachment_id} not found.",
                        "details": {},
                    }
                },
            )

        # Verify caller has permission to view the case
        await self._get_accessible_case(attachment.case_id, current_user, for_mutation=False)

        url = await self.storage.get_signed_download_url(
            storage_path=attachment.storage_path,
            expires_in=expires_in,
        )

        return AttachmentDownloadOut(
            attachment_id=attachment.id,
            file_name=attachment.file_name,
            download_url=url,
            expires_in_seconds=expires_in,
        )

    async def delete_attachment(
        self,
        attachment_id: uuid.UUID,
        current_user: User,
    ) -> None:
        """
        Delete an attachment record and remove binary file from storage provider.
        Enforces ownership and role permissions, and records an AuditLog entry.
        """
        stmt = select(Attachment).where(Attachment.id == attachment_id)
        result = await self.db.execute(stmt)
        attachment = result.scalar_one_or_none()

        if not attachment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "ATTACHMENT_NOT_FOUND",
                        "message": f"Attachment {attachment_id} not found.",
                        "details": {},
                    }
                },
            )

        # Verify access to the parent case
        case = await self._get_accessible_case(attachment.case_id, current_user, for_mutation=True)

        # Permission check:
        # Can be deleted by:
        # 1. The original uploader (if case is not closed/cancelled)
        # 2. Staff: Team Lead, Manager, Administrator
        # 3. Assigned Operator on the case
        is_uploader = attachment.uploaded_by == current_user.id
        is_privileged_staff = current_user.role in (
            UserRole.TEAM_LEAD,
            UserRole.MANAGER,
            UserRole.ADMINISTRATOR,
        )
        is_assigned_operator = (
            current_user.role == UserRole.OPERATOR and case.owner_id == current_user.id
        )

        if not (is_uploader or is_privileged_staff or is_assigned_operator):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "You do not have permission to delete this attachment.",
                        "details": {},
                    }
                },
            )

        # Delete from storage provider
        await self.storage.delete_file(attachment.storage_path)

        # Log audit entry before deletion
        now = datetime.now(timezone.utc)
        audit = AuditLog(
            actor_id=current_user.id,
            action="ATTACHMENT_DELETED",
            target_type="case",
            target_id=case.id,
            before_value={
                "attachment_id": str(attachment.id),
                "file_name": attachment.file_name,
                "storage_path": attachment.storage_path,
                "file_size": attachment.file_size,
            },
            after_value=None,
            created_at=now,
        )
        self.db.add(audit)

        # Delete Attachment row
        await self.db.delete(attachment)
        await self.db.commit()
