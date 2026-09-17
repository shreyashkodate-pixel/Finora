import uuid
from datetime import datetime, timezone
from typing import List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from models.knowledge import Approval
from models.audit import AuditLog
from models.case import Case
from models.enums import ApprovalDecision, CaseStatus, MessageVisibility, NotificationEventType, UserRole
from models.message import Message
from models.notification import Notification
from models.user import User
from schemas.approval import ApprovalRequestCreate, ApprovalDecisionSubmit


class ApprovalService:
    """
    Manages multi-tier approval requests, case status gating (AWAITING_APPROVAL -> ASSIGNED),
    concurrency versioning, approver authorization, and audit trail logging per SRS §4 & §6.1.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def request_approval(
        self, case_id: uuid.UUID, payload: ApprovalRequestCreate, current_user: User
    ) -> Approval:
        """
        Request formal approval for a case.
        Permitted only for staff on cases currently in ASSIGNED status.
        Transitions case to AWAITING_APPROVAL per state machine.
        """
        # RBAC Check: Requesters cannot request approvals
        if current_user.role == UserRole.REQUESTER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "Requesters cannot request case approvals.",
                        "details": {},
                    }
                },
            )

        # Lookup case
        case_stmt = select(Case).where(Case.id == case_id)
        case_result = await self.db.execute(case_stmt)
        case = case_result.scalar_one_or_none()

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

        # Check for existing pending approval on this case
        pending_stmt = select(Approval).where(
            Approval.case_id == case.id,
            Approval.decision == ApprovalDecision.PENDING,
        )
        pending_result = await self.db.execute(pending_stmt)
        if pending_result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "error": {
                        "code": "APPROVAL_ALREADY_PENDING",
                        "message": "An active approval request is already pending for this case.",
                        "details": {"case_id": str(case.id)},
                    }
                },
            )

        # State machine check per SRS §6.1: only ASSIGNED cases can transition to AWAITING_APPROVAL
        if case.status != CaseStatus.ASSIGNED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_CASE_STATUS",
                        "message": f"Approvals can only be requested for cases in ASSIGNED status. Current status: '{case.status.value}'.",
                        "details": {"current_status": case.status.value},
                    }
                },
            )

        # Validate approver exists and holds authority (Team Lead, Manager, or Admin)
        approver_stmt = select(User).where(User.id == payload.approver_id, User.deleted_at.is_(None))
        approver_result = await self.db.execute(approver_stmt)
        approver = approver_result.scalar_one_or_none()

        if not approver:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "APPROVER_NOT_FOUND",
                        "message": f"Designated approver {payload.approver_id} does not exist.",
                        "details": {},
                    }
                },
            )

        authorized_approver_roles = {UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR}
        if approver.role not in authorized_approver_roles:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_APPROVER_ROLE",
                        "message": "Approvers must hold a Team Lead, Manager, or Administrator role.",
                        "details": {"approver_role": approver.role.value},
                    }
                },
            )

        now = datetime.now(timezone.utc)
        approval_id = uuid.uuid4()

        # Create approval record
        approval = Approval(
            id=approval_id,
            case_id=case.id,
            approver_id=payload.approver_id,
            decision=ApprovalDecision.PENDING,
            reason=payload.reason,
            created_at=now,
        )
        self.db.add(approval)

        # Transition case to AWAITING_APPROVAL with version increment
        case.status = CaseStatus.AWAITING_APPROVAL
        case.version += 1

        # Add timeline message to case
        timeline_msg = Message(
            case_id=case.id,
            author_id=current_user.id,
            body=f"Approval requested from {approver.email}. Reason: {payload.reason or 'None specified'}.",
            visibility=MessageVisibility.REQUESTER_VISIBLE,
            ai_generated=False,
            created_at=now,
        )
        self.db.add(timeline_msg)

        # Record audit log
        audit = AuditLog(
            actor_id=current_user.id,
            action="APPROVAL_REQUESTED",
            target_type="Case",
            target_id=case.id,
            before_value={"status": CaseStatus.ASSIGNED.value},
            after_value={
                "status": CaseStatus.AWAITING_APPROVAL.value,
                "approver_id": str(payload.approver_id),
                "reason": payload.reason,
            },
            created_at=now,
        )
        self.db.add(audit)

        # In-app alert to approver
        notif = Notification(
            user_id=approver.id,
            case_id=case.id,
            title=f"Approval Required: {case.reference_number}",
            message=f"Operator {current_user.email} requested your approval on case {case.reference_number}: {case.title}.",
            event_type=NotificationEventType.CASE_ASSIGNED,
            is_read=False,
            created_at=now,
        )
        self.db.add(notif)

        await self.db.commit()
        await self.db.refresh(approval)
        return approval

    async def decide_approval(
        self, approval_id: uuid.UUID, payload: ApprovalDecisionSubmit, current_user: User
    ) -> Approval:
        """
        Submit decision (APPROVED or REJECTED) on a pending approval.
        Authorized only for designated approver or Manager/Administrator override.
        Transitions case back to ASSIGNED per state machine.
        """
        if payload.decision == ApprovalDecision.PENDING:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "INVALID_DECISION",
                        "message": "Decision must be 'approved' or 'rejected'.",
                        "details": {},
                    }
                },
            )

        # Lookup approval
        stmt = select(Approval).where(Approval.id == approval_id)
        result = await self.db.execute(stmt)
        approval = result.scalar_one_or_none()

        if not approval:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "APPROVAL_NOT_FOUND",
                        "message": f"Approval request {approval_id} not found.",
                        "details": {},
                    }
                },
            )

        if approval.decision != ApprovalDecision.PENDING:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": {
                        "code": "APPROVAL_ALREADY_DECIDED",
                        "message": f"This approval request was already decided as '{approval.decision.value}'.",
                        "details": {"current_decision": approval.decision.value},
                    }
                },
            )

        # Authority check: designated approver or Manager/Admin override
        elevated_roles = {UserRole.MANAGER, UserRole.ADMINISTRATOR}
        if approval.approver_id != current_user.id and current_user.role not in elevated_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "Only the assigned approver or a Manager/Administrator can decide this approval.",
                        "details": {},
                    }
                },
            )

        now = datetime.now(timezone.utc)

        # Update approval
        approval.decision = payload.decision
        if payload.reason:
            approval.reason = payload.reason
        approval.decided_at = now

        # Fetch case and transition state back to ASSIGNED
        case_stmt = select(Case).where(Case.id == approval.case_id)
        case_res = await self.db.execute(case_stmt)
        case = case_res.scalar_one_or_none()

        if case and case.status == CaseStatus.AWAITING_APPROVAL:
            case.status = CaseStatus.ASSIGNED
            case.version += 1

            # Timeline message
            status_text = "APPROVED" if payload.decision == ApprovalDecision.APPROVED else "REJECTED"
            msg = Message(
                case_id=case.id,
                author_id=current_user.id,
                body=f"Approval {status_text} by {current_user.email}. Justification: {payload.reason or 'None provided'}.",
                visibility=MessageVisibility.REQUESTER_VISIBLE,
                ai_generated=False,
                created_at=now,
            )
            self.db.add(msg)

            # Notification to case assignee if present
            if case.owner_id:
                notif = Notification(
                    user_id=case.owner_id,
                    case_id=case.id,
                    title=f"Approval {status_text}: {case.reference_number}",
                    message=f"Approval on case {case.reference_number} was {payload.decision.value} by {current_user.email}.",
                    event_type=NotificationEventType.CASE_ASSIGNED,
                    is_read=False,
                    created_at=now,
                )
                self.db.add(notif)

        # Audit log
        audit = AuditLog(
            actor_id=current_user.id,
            action="APPROVAL_DECIDED",
            target_type="Approval",
            target_id=approval.id,
            before_value={"decision": ApprovalDecision.PENDING.value},
            after_value={
                "decision": payload.decision.value,
                "reason": payload.reason,
                "case_id": str(approval.case_id),
            },
            created_at=now,
        )
        self.db.add(audit)

        await self.db.commit()
        await self.db.refresh(approval)
        return approval

    async def list_approvals_for_case(
        self, case_id: uuid.UUID, current_user: User
    ) -> List[Approval]:
        """
        List approval history for a specific case.
        Requesters can only view approvals for their own cases.
        """
        case_stmt = select(Case).where(Case.id == case_id)
        case_result = await self.db.execute(case_stmt)
        case = case_result.scalar_one_or_none()

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

        if current_user.role == UserRole.REQUESTER and case.requester_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "PERMISSION_DENIED",
                        "message": "You do not have permission to view approvals for this case.",
                        "details": {},
                    }
                },
            )

        stmt = (
            select(Approval)
            .where(Approval.case_id == case_id)
            .order_by(Approval.created_at.desc())
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def list_pending_approvals(
        self, current_user: User, limit: int = 50, offset: int = 0
    ) -> Tuple[List[Approval], int]:
        """
        List pending approvals awaiting decision.
        Managers and Administrators see all pending approvals across the platform.
        Team Leads see pending approvals where approver_id == current_user.id.
        """
        query = select(Approval).where(Approval.decision == ApprovalDecision.PENDING)

        if current_user.role not in {UserRole.MANAGER, UserRole.ADMINISTRATOR}:
            query = query.where(Approval.approver_id == current_user.id)

        count_query = select(func.count()).select_from(query.subquery())
        total_res = await self.db.execute(count_query)
        total = total_res.scalar() or 0

        paginated_query = (
            query.order_by(Approval.created_at.asc())
            .offset(offset)
            .limit(min(limit, 100))
        )
        result = await self.db.execute(paginated_query)
        return list(result.scalars().all()), total
