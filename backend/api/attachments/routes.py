import uuid
from typing import List, Optional
from fastapi import (
    APIRouter,
    Depends,
    File,
    Header,
    HTTPException,
    Query,
    Response,
    UploadFile,
    status,
)
from sqlalchemy.ext.asyncio import AsyncSession

from api.deps import get_current_active_user
from db.session import get_db_session
from models.user import User
from providers.storage import get_storage_provider
from providers.storage.local import LocalStorageProvider
from schemas.attachment import (
    AttachmentOut,
    AttachmentDownloadOut,
    CaseAttachmentQuotaOut,
)
from services.attachment_service import AttachmentService


router = APIRouter(tags=["Attachments"])


@router.post(
    "/cases/{case_id}/attachments",
    response_model=AttachmentOut,
    status_code=status.HTTP_201_CREATED,
    summary="Upload file attachment to case",
)
async def upload_attachment(
    case_id: uuid.UUID,
    file: UploadFile = File(..., description="Binary file upload (max 10MB)"),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Upload an evidence file/attachment for a case per SRS §7.5.
    
    - Validates binary magic bytes (jpg, png, webp, gif, pdf, docx, txt, log).
    - Enforces 10MB per-file limit and 50MB per-case cumulative quota.
    - Generates server-side UUID storage path.
    - Emits immutable AuditLog entry.
    - Supports idempotent retries with Idempotency-Key header.
    """
    file_bytes = await file.read()
    service = AttachmentService(db)
    
    return await service.upload_attachment(
        case_id=case_id,
        current_user=current_user,
        file_name=file.filename or "unnamed_file",
        file_bytes=file_bytes,
        content_type=file.content_type,
        idempotency_key=idempotency_key,
    )


@router.get(
    "/cases/{case_id}/attachments",
    response_model=List[AttachmentOut],
    summary="List all attachments for a case",
)
async def list_attachments(
    case_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """List all attachments associated with a case that the current user has access to."""
    service = AttachmentService(db)
    return await service.list_case_attachments(case_id, current_user)


@router.get(
    "/cases/{case_id}/attachments/quota",
    response_model=CaseAttachmentQuotaOut,
    summary="Get storage quota metrics for a case",
)
async def get_case_quota(
    case_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Retrieve cumulative attachment storage usage, limit (50MB), and remaining capacity for a case."""
    service = AttachmentService(db)
    return await service.get_case_quota(case_id, current_user)


@router.get(
    "/attachments/{attachment_id}",
    response_model=AttachmentOut,
    summary="Get attachment metadata",
)
async def get_attachment_metadata(
    attachment_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Retrieve attachment metadata by UUID with case permission verification."""
    service = AttachmentService(db)
    return await service.get_attachment(attachment_id, current_user)


@router.get(
    "/attachments/{attachment_id}/download",
    response_model=AttachmentDownloadOut,
    summary="Generate presigned download URL",
)
async def get_attachment_download_url(
    attachment_id: uuid.UUID,
    expires_in: int = Query(3600, ge=60, le=86400, description="URL validity in seconds"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Generate a secure, time-limited presigned download link for an attachment."""
    service = AttachmentService(db)
    return await service.get_download_url(attachment_id, current_user, expires_in=expires_in)


@router.delete(
    "/attachments/{attachment_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete an attachment",
)
async def delete_attachment(
    attachment_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Delete an attachment file from storage and database.
    Requires ownership or elevated staff permissions (Team Lead, Manager, Administrator).
    """
    service = AttachmentService(db)
    await service.delete_attachment(attachment_id, current_user)
    return None


@router.get(
    "/attachments/raw/{storage_path:path}",
    summary="Local raw storage streaming (dev/test only)",
    include_in_schema=False,
)
async def stream_local_raw_attachment(
    storage_path: str,
    expires: int = Query(..., description="Expiry timestamp"),
    signature: str = Query(..., description="HMAC signature"),
):
    """Internal endpoint serving signed local uploads during offline dev/test mode."""
    provider = get_storage_provider()
    if not isinstance(provider, LocalStorageProvider):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "Raw streaming only available in local mode.", "details": {}}},
        )

    if not provider.verify_signed_url_signature(storage_path, expires, signature):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "INVALID_SIGNATURE", "message": "Download link is expired or invalid.", "details": {}}},
        )

    file_bytes = await provider.get_file_bytes(storage_path)
    # Determine content-type from extension
    ext = storage_path.rsplit(".", 1)[-1].lower() if "." in storage_path else "bin"
    mime_types = {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "gif": "image/gif",
        "webp": "image/webp",
        "pdf": "application/pdf",
        "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "txt": "text/plain",
        "log": "text/plain",
    }
    media_type = mime_types.get(ext, "application/octet-stream")
    return Response(content=file_bytes, media_type=media_type)
