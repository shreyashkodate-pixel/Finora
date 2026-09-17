import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Tuple, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy import select, func, desc, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from models.case import Case, CaseRelationship
from models.sla import SLA
from models.message import Message
from models.audit import AuditLog
from models.user import User
from models.enums import (
    CaseType,
    CaseStatus,
    CasePriority,
    RelationshipType,
    MessageVisibility,
    UserRole,
)
from schemas.case import (
    CaseCreate,
    CaseUpdate,
    CaseStatusTransition,
    MessageCreate,
    CaseRelationshipCreate,
)
from services.notification_service import NotificationService


TYPE_PREFIXES: Dict[CaseType, str] = {
    CaseType.INCIDENT: "INC",
    CaseType.SERVICE_REQUEST: "REQ",
    CaseType.PROBLEM: "PRB",
    CaseType.CHANGE: "CHG",
}

# SLA 24/7 wall-clock durations per SRS §4.3
SLA_DELTAS: Dict[CasePriority, Dict[str, timedelta]] = {
    CasePriority.P1: {
        "response": timedelta(minutes=15),
        "resolve": timedelta(hours=4),
    },
    CasePriority.P2: {
        "response": timedelta(hours=1),
        "resolve": timedelta(hours=8),
    },
    CasePriority.P3: {
        "response": timedelta(hours=4),
        "resolve": timedelta(hours=72),
    },
    CasePriority.P4: {
        "response": timedelta(hours=24),
        "resolve": timedelta(hours=120),
    },
}

# State machine allowed transitions per SRS §6.1
ALLOWED_TRANSITIONS: Dict[CaseStatus, List[CaseStatus]] = {
    CaseStatus.DRAFT: [CaseStatus.NEW, CaseStatus.CANCELLED],
    CaseStatus.NEW: [CaseStatus.IN_ASSESSMENT, CaseStatus.CANCELLED],
    CaseStatus.IN_ASSESSMENT: [CaseStatus.ASSIGNED, CaseStatus.CANCELLED],
    CaseStatus.ASSIGNED: [
        CaseStatus.AWAITING_REQUESTER,
        CaseStatus.AWAITING_APPROVAL,
        CaseStatus.RESOLVED,
        CaseStatus.CANCELLED,
    ],
    CaseStatus.AWAITING_REQUESTER: [CaseStatus.ASSIGNED, CaseStatus.CANCELLED],
    CaseStatus.AWAITING_APPROVAL: [CaseStatus.ASSIGNED, CaseStatus.CANCELLED],
    CaseStatus.RESOLVED: [CaseStatus.CLOSED, CaseStatus.ASSIGNED],
    CaseStatus.CLOSED: [CaseStatus.ASSIGNED],
    CaseStatus.CANCELLED: [],
}


class CaseService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def _generate_reference_number(self, case_type: CaseType) -> str:
        """
        Generate sequential reference number: <TYPE>-<YEAR>-<sequential>
        e.g. INC-2026-000001 per SRS §4.2.
        """
        prefix = TYPE_PREFIXES.get(case_type, "INC")
        year = datetime.now(timezone.utc).year
        pattern = f"{prefix}-{year}-%"

        stmt = (
            select(Case.reference_number)
            .where(Case.reference_number.like(pattern))
            .order_by(desc(Case.reference_number))
            .limit(1)
        )
        result = await self.db.execute(stmt)
        latest_ref = result.scalar_one_or_none()

        if latest_ref:
            try:
                seq_part = latest_ref.split("-")[-1]
                next_seq = int(seq_part) + 1
            except (ValueError, IndexError):
                next_seq = 1
        else:
            next_seq = 1

        return f"{prefix}-{year}-{next_seq:06d}"

    def _calculate_sla(self, priority: CasePriority, created_at: datetime) -> Tuple[datetime, datetime]:
        """Compute 24/7 elapsed wall-clock UTC SLA targets per SRS §4.3."""
        deltas = SLA_DELTAS.get(priority, SLA_DELTAS[CasePriority.P3])
        target_response = created_at + deltas["response"]
        target_resolve = created_at + deltas["resolve"]
        return target_response, target_resolve

    async def _reload_case(self, case_id: uuid.UUID) -> Case:
        """Reload case with SLA eager loaded to prevent greenlet IO errors on serialization."""
        stmt = (
            select(Case)
            .options(selectinload(Case.sla))
            .where(Case.id == case_id)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one()

    async def create_case(self, current_user: User, payload: CaseCreate) -> Case:
        """Create a new Case with SLA targets, reference number, and audit log."""
        now = datetime.now(timezone.utc)
        ref_num = await self._generate_reference_number(payload.type)

        site = payload.site or current_user.site

        case = Case(
            reference_number=ref_num,
            type=payload.type,
            title=payload.title,
            description=payload.description,
            status=CaseStatus.NEW,
            priority=payload.priority,
            requester_id=current_user.id,
            site=site,
            service_id=payload.service_id,
            version=1,
            created_at=now,
        )
        self.db.add(case)
        await self.db.flush()

        # Initialize SLA
        target_resp, target_res = self._calculate_sla(payload.priority, now)
        sla = SLA(
            case_id=case.id,
            target_response_at=target_resp,
            target_resolve_at=target_res,
            created_at=now,
        )
        self.db.add(sla)

        # Audit log per SRS §4 & §5.11
        audit = AuditLog(
            actor_id=current_user.id,
            action="CASE_CREATED",
            target_type="Case",
            target_id=case.id,
            before_value=None,
            after_value={
                "reference_number": ref_num,
                "status": CaseStatus.NEW.value,
                "priority": payload.priority.value,
                "type": payload.type.value,
            },
            created_at=now,
        )
        self.db.add(audit)

        # Dispatch notification to requester per SRS §5.10
        notif_service = NotificationService(self.db)
        await notif_service.notify_case_created(case, current_user)

        await self.db.commit()

        # Non-blocking automatic AI Triage per SRS §5.2
        try:
            from services import ai_service
            await ai_service.triage_case(self.db, case.id)
        except Exception as e:
            logger.warning(f"Inline AI triage failed or deferred for case {case.id}: {e}")

        return await self._reload_case(case.id)

    async def get_case_by_id(
        self, case_id: uuid.UUID, current_user: User, include_deleted: bool = False
    ) -> Case:
        """Fetch a case by UUID with role-based access check and SLA eager loading."""
        stmt = (
            select(Case)
            .options(selectinload(Case.sla))
            .where(Case.id == case_id)
        )
        if not include_deleted:
            stmt = stmt.where(Case.deleted_at.is_(None))

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

        # Requesters can only view their own cases per SRS §2.2 & §7.6
        if current_user.role == UserRole.REQUESTER and case.requester_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "You do not have permission to view this case.",
                        "details": {},
                    }
                },
            )

        return case

    async def list_cases(
        self,
        current_user: User,
        status_filter: Optional[CaseStatus] = None,
        type_filter: Optional[CaseType] = None,
        priority_filter: Optional[CasePriority] = None,
        search: Optional[str] = None,
        page: int = 1,
        per_page: int = 20,
    ) -> Tuple[List[Case], int]:
        """List cases with role scoping, filtering, and pagination."""
        base_query = select(Case).options(selectinload(Case.sla)).where(Case.deleted_at.is_(None))

        # Requesters only see their own cases
        if current_user.role == UserRole.REQUESTER:
            base_query = base_query.where(Case.requester_id == current_user.id)

        if status_filter:
            base_query = base_query.where(Case.status == status_filter)
        if type_filter:
            base_query = base_query.where(Case.type == type_filter)
        if priority_filter:
            base_query = base_query.where(Case.priority == priority_filter)
        if search:
            pattern = f"%{search}%"
            base_query = base_query.where(
                or_(
                    Case.reference_number.ilike(pattern),
                    Case.title.ilike(pattern),
                    Case.description.ilike(pattern),
                )
            )

        # Count total
        count_stmt = select(func.count()).select_from(base_query.subquery())
        total_result = await self.db.execute(count_stmt)
        total = total_result.scalar() or 0

        # Paginate
        offset = (page - 1) * per_page
        query = base_query.order_by(desc(Case.created_at)).offset(offset).limit(per_page)
        cases_result = await self.db.execute(query)
        items = list(cases_result.scalars().all())

        return items, total

    async def update_case(
        self, case_id: uuid.UUID, current_user: User, payload: CaseUpdate
    ) -> Case:
        """Update case fields with optimistic concurrency locking per SRS §7.12."""
        case = await self.get_case_by_id(case_id, current_user)

        # Optimistic locking check
        if case.version != payload.version:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "error": {
                        "code": "STALE_VERSION",
                        "message": "This case was updated by someone else. Please reload to see the latest changes.",
                        "details": {
                            "expected_version": case.version,
                            "provided_version": payload.version,
                        },
                    }
                },
            )

        # Requesters cannot reassign or change owner/priority
        if current_user.role == UserRole.REQUESTER:
            if payload.owner_id is not None or payload.team_id is not None or payload.priority is not None:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail={
                        "error": {
                            "code": "PERMISSION_DENIED",
                            "message": "Requesters cannot modify case assignment or priority.",
                            "details": {},
                        }
                    },
                )

        before_state = {
            "title": case.title,
            "priority": case.priority.value if case.priority else None,
            "owner_id": str(case.owner_id) if case.owner_id else None,
            "team_id": str(case.team_id) if case.team_id else None,
            "version": case.version,
        }

        if payload.title is not None:
            case.title = payload.title
        if payload.priority is not None:
            case.priority = payload.priority
            # Recalculate SLA targets if priority changed and case still open
            if case.sla and case.status not in (CaseStatus.RESOLVED, CaseStatus.CLOSED):
                resp_tgt, res_tgt = self._calculate_sla(payload.priority, case.created_at)
                case.sla.target_response_at = resp_tgt
                case.sla.target_resolve_at = res_tgt
        before_owner_id = case.owner_id
        if payload.owner_id is not None:
            case.owner_id = payload.owner_id
        if payload.team_id is not None:
            case.team_id = payload.team_id
        if payload.service_id is not None:
            case.service_id = payload.service_id

        # Increment version
        case.version += 1

        after_state = {
            "title": case.title,
            "priority": case.priority.value if case.priority else None,
            "owner_id": str(case.owner_id) if case.owner_id else None,
            "team_id": str(case.team_id) if case.team_id else None,
            "version": case.version,
        }

        # Audit log
        audit = AuditLog(
            actor_id=current_user.id,
            action="CASE_UPDATED",
            target_type="Case",
            target_id=case.id,
            before_value=before_state,
            after_value=after_state,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(audit)

        # Dispatch assignment notification if owner was updated
        if payload.owner_id is not None and payload.owner_id != before_owner_id:
            assignee_stmt = select(User).where(User.id == payload.owner_id)
            assignee_res = await self.db.execute(assignee_stmt)
            assignee = assignee_res.scalar_one_or_none()
            if assignee:
                notif_service = NotificationService(self.db)
                await notif_service.notify_case_assigned(case, assignee, current_user)

        await self.db.commit()
        return await self._reload_case(case.id)

    async def transition_status(
        self, case_id: uuid.UUID, current_user: User, payload: CaseStatusTransition
    ) -> Case:
        """
        Transition case status through the formal state machine per SRS §6.1.
        Enforces allowed transitions, optimistic locking, and 7-day reopen window.
        """
        case = await self.get_case_by_id(case_id, current_user)

        # Optimistic locking check
        if case.version != payload.version:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "error": {
                        "code": "STALE_VERSION",
                        "message": "This case was updated by someone else. Please reload to see the latest changes.",
                        "details": {
                            "expected_version": case.version,
                            "provided_version": payload.version,
                        },
                    }
                },
            )

        allowed = ALLOWED_TRANSITIONS.get(case.status, [])
        if payload.new_status not in allowed:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_STATE_TRANSITION",
                        "message": f"Cannot transition case from {case.status.value} to {payload.new_status.value}.",
                        "details": {
                            "current_status": case.status.value,
                            "requested_status": payload.new_status.value,
                            "allowed_transitions": [s.value for s in allowed],
                        },
                    }
                },
            )

        now = datetime.now(timezone.utc)

        # Closed -> Assigned (Reopen) within 7-day window rule per SRS §6.1
        if case.status == CaseStatus.CLOSED and payload.new_status == CaseStatus.ASSIGNED:
            if case.closed_at:
                closed_at = case.closed_at
                if closed_at.tzinfo is None:
                    closed_at = closed_at.replace(tzinfo=timezone.utc)
                seven_days_ago = now - timedelta(days=7)
                if closed_at < seven_days_ago:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail={
                            "error": {
                                "code": "REOPEN_WINDOW_EXPIRED",
                                "message": "Closed cases can only be reopened within 7 days of closure.",
                                "details": {
                                    "closed_at": case.closed_at.isoformat(),
                                    "expired_at": (case.closed_at + timedelta(days=7)).isoformat(),
                                },
                            }
                        },
                    )

        before_status = case.status.value
        case.status = payload.new_status
        case.version += 1

        # State entry side-effects
        if payload.new_status == CaseStatus.RESOLVED:
            case.resolved_at = now
            if case.sla:
                case.sla.resolved_at = now
                target_res = case.sla.target_resolve_at
                if target_res and target_res.tzinfo is None:
                    target_res = target_res.replace(tzinfo=timezone.utc)
                if case.sla.resolved_at > target_res:
                    case.sla.resolution_breached = True
        elif payload.new_status == CaseStatus.CLOSED:
            case.closed_at = now
        elif payload.new_status == CaseStatus.ASSIGNED and before_status in (CaseStatus.RESOLVED.value, CaseStatus.CLOSED.value):
            # Reopened / fix rejected -> clear resolution
            case.resolved_at = None
            case.closed_at = None

        # Audit log
        audit = AuditLog(
            actor_id=current_user.id,
            action="STATUS_TRANSITION",
            target_type="Case",
            target_id=case.id,
            before_value={"status": before_status},
            after_value={"status": payload.new_status.value, "reason": payload.reason},
            created_at=now,
        )
        self.db.add(audit)

        # Dispatch resolution or reopen notifications per SRS §5.10
        notif_service = NotificationService(self.db)
        if payload.new_status == CaseStatus.RESOLVED:
            req_stmt = select(User).where(User.id == case.requester_id)
            req_res = await self.db.execute(req_stmt)
            requester = req_res.scalar_one_or_none()
            if requester:
                await notif_service.notify_case_resolved(case, current_user, requester)
        elif payload.new_status == CaseStatus.ASSIGNED and before_status in (CaseStatus.RESOLVED.value, CaseStatus.CLOSED.value):
            if case.owner_id:
                owner_stmt = select(User).where(User.id == case.owner_id)
                owner_res = await self.db.execute(owner_stmt)
                owner = owner_res.scalar_one_or_none()
                if owner:
                    await notif_service.notify_case_reopened(case, current_user, owner)

        await self.db.commit()
        return await self._reload_case(case.id)

    async def soft_delete_case(self, case_id: uuid.UUID, current_user: User) -> None:
        """
        Soft delete case per SRS §7.10.
        Requesters can only delete when case is still NEW or DRAFT.
        """
        case = await self.get_case_by_id(case_id, current_user)

        if current_user.role == UserRole.REQUESTER and case.status not in (CaseStatus.NEW, CaseStatus.DRAFT):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "Requesters can only cancel/delete cases in Draft or New status.",
                        "details": {},
                    }
                },
            )

        now = datetime.now(timezone.utc)
        case.deleted_at = now
        case.status = CaseStatus.CANCELLED
        case.version += 1

        audit = AuditLog(
            actor_id=current_user.id,
            action="CASE_DELETED",
            target_type="Case",
            target_id=case.id,
            before_value={"deleted_at": None},
            after_value={"deleted_at": now.isoformat()},
            created_at=now,
        )
        self.db.add(audit)

        await self.db.commit()

    async def add_message(
        self, case_id: uuid.UUID, current_user: User, payload: MessageCreate
    ) -> Message:
        """
        Post a note/message to a case.
        Enforces visibility restrictions (Requesters cannot create internal_only notes per SRS §4 & §7.6).
        First staff response triggers SLA response timestamp.
        """
        case = await self.get_case_by_id(case_id, current_user)

        # Requester permission check on message visibility
        if current_user.role == UserRole.REQUESTER and payload.visibility != MessageVisibility.REQUESTER_VISIBLE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "Requesters can only post requester-visible messages.",
                        "details": {},
                    }
                },
            )

        now = datetime.now(timezone.utc)
        message = Message(
            case_id=case.id,
            author_id=current_user.id,
            body=payload.body,
            visibility=payload.visibility,
            ai_generated=False,
            created_at=now,
        )
        self.db.add(message)

        # First staff response records SLA responded_at per SRS §4.3
        if current_user.role != UserRole.REQUESTER and case.sla and not case.sla.responded_at:
            case.sla.responded_at = now
            target_resp = case.sla.target_response_at
            if target_resp and target_resp.tzinfo is None:
                target_resp = target_resp.replace(tzinfo=timezone.utc)
            if case.sla.responded_at > target_resp:
                case.sla.response_breached = True

        # Audit log
        audit = AuditLog(
            actor_id=current_user.id,
            action="MESSAGE_ADDED",
            target_type="Case",
            target_id=case.id,
            before_value=None,
            after_value={
                "message_id": str(message.id),
                "visibility": payload.visibility.value,
            },
            created_at=now,
        )
        self.db.add(audit)

        # Dispatch notification to other party per SRS §5.10
        notif_service = NotificationService(self.db)
        if current_user.id != case.requester_id and payload.visibility == MessageVisibility.REQUESTER_VISIBLE:
            req_stmt = select(User).where(User.id == case.requester_id)
            req_res = await self.db.execute(req_stmt)
            requester = req_res.scalar_one_or_none()
            if requester:
                await notif_service.notify_new_message(case, message, current_user, requester)
        elif current_user.id == case.requester_id and case.owner_id:
            owner_stmt = select(User).where(User.id == case.owner_id)
            owner_res = await self.db.execute(owner_stmt)
            owner = owner_res.scalar_one_or_none()
            if owner:
                await notif_service.notify_new_message(case, message, current_user, owner)

        await self.db.commit()
        await self.db.refresh(message)

        # Synchronous-on-write living case summary update per SRS §5.3
        try:
            from services import ai_service
            await ai_service.summarize_case(self.db, case_id=case.id, new_message_id=message.id)
        except Exception as e:
            logger.warning(f"Inline living summary update failed for case {case.id}: {e}")

        return message

    async def list_messages(
        self, case_id: uuid.UUID, current_user: User
    ) -> List[Message]:
        """
        List messages for a case.
        Strictly filters out internal_only messages for Requesters per SRS §4 & §7.6.
        """
        # Ensure user has access to case
        await self.get_case_by_id(case_id, current_user)

        stmt = select(Message).where(Message.case_id == case_id)
        if current_user.role == UserRole.REQUESTER:
            stmt = stmt.where(Message.visibility == MessageVisibility.REQUESTER_VISIBLE)

        stmt = stmt.order_by(Message.created_at.asc())
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def link_case_relationship(
        self, case_id: uuid.UUID, current_user: User, payload: CaseRelationshipCreate
    ) -> CaseRelationship:
        """Create a relationship between two cases (duplicate, related, etc.)."""
        # Verify both cases exist
        case = await self.get_case_by_id(case_id, current_user)
        related_case = await self.get_case_by_id(payload.related_case_id, current_user)

        if case.id == related_case.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_RELATIONSHIP",
                        "message": "A case cannot be linked to itself.",
                        "details": {},
                    }
                },
            )

        now = datetime.now(timezone.utc)
        relationship = CaseRelationship(
            case_id=case.id,
            related_case_id=related_case.id,
            relationship_type=payload.relationship_type,
            created_at=now,
        )
        self.db.add(relationship)

        audit = AuditLog(
            actor_id=current_user.id,
            action="CASE_LINKED",
            target_type="Case",
            target_id=case.id,
            before_value=None,
            after_value={
                "related_case_id": str(related_case.id),
                "relationship_type": payload.relationship_type.value,
            },
            created_at=now,
        )
        self.db.add(audit)

        await self.db.commit()
        await self.db.refresh(relationship)
        return relationship

    async def list_audit_logs(
        self, case_id: uuid.UUID, current_user: User
    ) -> List[AuditLog]:
        """View append-only audit trail for a case (staff only per SRS §5.11)."""
        if current_user.role == UserRole.REQUESTER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "Requesters cannot inspect raw audit logs.",
                        "details": {},
                    }
                },
            )

        # Check case exists
        await self.get_case_by_id(case_id, current_user)

        stmt = (
            select(AuditLog)
            .where(AuditLog.target_id == case_id)
            .order_by(AuditLog.created_at.asc())
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())
