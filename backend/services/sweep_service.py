import logging
import uuid
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, Optional, List

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status

from core.config import settings
from models.case import Case
from models.sla import SLA
from models.user import User, Team
from models.ai import EscalationEvent, CaseRiskAssessment
from models.audit import AuditLog
from models.enums import (
    CaseStatus,
    RiskLevel,
    EscalationTrigger,
    EscalationStatus,
    UserRole,
    NotificationEventType,
)
from services.notification_service import NotificationService
from services import ai_service

logger = logging.getLogger("helpdesk.services.sweep")

TERMINAL_STATUSES = [CaseStatus.RESOLVED, CaseStatus.CLOSED, CaseStatus.CANCELLED]


class SweepService:
    """
    The Sweep Engine per SRS §3.5, §5.7, and §5.8.
    Periodic background job re-evaluating SLA deadlines, risk levels, and escalation states.
    """

    def __init__(self, db: AsyncSession):
        self.db = db
        self.notif_service = NotificationService(db)

    async def run_sweep(self) -> Dict[str, Any]:
        """
        Execute a full sweep iteration across all active cases.
        """
        now = datetime.now(timezone.utc)
        logger.info(f"Starting The Sweep iteration at {now.isoformat()}")

        cases_evaluated = 0
        sla_warnings_emitted = 0
        sla_breaches_detected = 0
        escalations_raised = 0
        escalations_promoted = 0

        # 1. Query all active, open cases
        stmt = (
            select(Case)
            .options(
                selectinload(Case.sla),
                selectinload(Case.team),
                selectinload(Case.owner),
                selectinload(Case.escalations),
            )
            .where(
                Case.status.notin_(TERMINAL_STATUSES),
                Case.deleted_at.is_(None),
            )
        )
        result = await self.db.execute(stmt)
        active_cases = result.scalars().all()

        for case in active_cases:
            cases_evaluated += 1
            created_at = case.created_at or now
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)

            # Target staff user to notify (case owner, team lead, or general lead)
            target_user = await self._resolve_case_lead_or_owner(case)

            # --- A. SLA Target Evaluations ---
            if case.sla:
                sla = case.sla

                # 1. Response SLA
                if not sla.responded_at and sla.target_response_at:
                    target_resp = sla.target_response_at
                    if target_resp.tzinfo is None:
                        target_resp = target_resp.replace(tzinfo=timezone.utc)

                    if now > target_resp:
                        if not sla.response_breached:
                            sla.response_breached = True
                            sla_breaches_detected += 1
                            esc = await self._raise_escalation_if_new(
                                case_id=case.id,
                                reason=EscalationTrigger.MISSED_DEADLINE,
                                role="team_lead",
                                by="system",
                            )
                            if esc:
                                escalations_raised += 1
                                if target_user:
                                    await self.notif_service.notify_escalation_raised(case, esc, target_user)

                            if target_user:
                                await self.notif_service.notify_sla_breach(case, target_user, "Response")

                            self.db.add(AuditLog(
                                actor_id=None,
                                action="SLA_RESPONSE_BREACHED",
                                target_type="Case",
                                target_id=case.id,
                                before_value={"response_breached": False},
                                after_value={"response_breached": True, "breached_at": now.isoformat()},
                                created_at=now,
                            ))
                    else:
                        # Check 80% threshold (within 20% remaining target window)
                        total_window = max(1.0, (target_resp - created_at).total_seconds())
                        remaining = (target_resp - now).total_seconds()
                        if remaining <= total_window * 0.20:
                            sent = await self._emit_sla_warning_if_due(case, target_user, "Response", remaining)
                            if sent:
                                sla_warnings_emitted += 1

                # 2. Resolution SLA
                if not sla.resolved_at and sla.target_resolve_at:
                    target_res = sla.target_resolve_at
                    if target_res.tzinfo is None:
                        target_res = target_res.replace(tzinfo=timezone.utc)

                    if now > target_res:
                        if not sla.resolution_breached:
                            sla.resolution_breached = True
                            sla_breaches_detected += 1
                            esc = await self._raise_escalation_if_new(
                                case_id=case.id,
                                reason=EscalationTrigger.MISSED_DEADLINE,
                                role="team_lead",
                                by="system",
                            )
                            if esc:
                                escalations_raised += 1
                                if target_user:
                                    await self.notif_service.notify_escalation_raised(case, esc, target_user)

                            if target_user:
                                await self.notif_service.notify_sla_breach(case, target_user, "Resolution")

                            self.db.add(AuditLog(
                                actor_id=None,
                                action="SLA_RESOLUTION_BREACHED",
                                target_type="Case",
                                target_id=case.id,
                                before_value={"resolution_breached": False},
                                after_value={"resolution_breached": True, "breached_at": now.isoformat()},
                                created_at=now,
                            ))
                    else:
                        total_window = max(1.0, (target_res - created_at).total_seconds())
                        remaining = (target_res - now).total_seconds()
                        if remaining <= total_window * 0.20:
                            sent = await self._emit_sla_warning_if_due(case, target_user, "Resolution", remaining)
                            if sent:
                                sla_warnings_emitted += 1

            # --- B. Risk Assessment & High-Risk Trigger ---
            try:
                assessment = await ai_service.assess_case_risk(self.db, case.id)
                if assessment and assessment.risk_level in [RiskLevel.HIGH, RiskLevel.CRITICAL]:
                    esc = await self._raise_escalation_if_new(
                        case_id=case.id,
                        reason=EscalationTrigger.HIGH_RISK,
                        role="team_lead",
                        by="system",
                    )
                    if esc:
                        escalations_raised += 1
                        if target_user:
                            await self.notif_service.notify_escalation_raised(case, esc, target_user)
            except Exception as e:
                logger.warning(f"Risk evaluation during sweep for case {case.id} skipped: {e}")

        # --- C. Managerial Escalation Promotion (SRS §5.8) ---
        # Escalate unacknowledged events older than 2 hours to Manager
        cutoff = now - timedelta(hours=settings.ESCALATION_UNACKNOWLEDGED_HOURS)
        esc_stmt = (
            select(EscalationEvent)
            .where(
                EscalationEvent.status == EscalationStatus.OPEN,
                EscalationEvent.escalated_to_role != "manager",
                EscalationEvent.created_at <= cutoff,
            )
        )
        esc_res = await self.db.execute(esc_stmt)
        stale_escalations = esc_res.scalars().all()

        manager_user = await self._get_fallback_manager()

        for esc in stale_escalations:
            esc.escalated_to_role = "manager"
            if manager_user:
                esc.escalated_to_user_id = manager_user.id

            escalations_promoted += 1

            case_stmt = select(Case).where(Case.id == esc.case_id)
            c_res = await self.db.execute(case_stmt)
            c = c_res.scalar_one_or_none()

            if c and manager_user:
                await self.notif_service.notify_escalation_raised(c, esc, manager_user)

            self.db.add(AuditLog(
                actor_id=None,
                action="ESCALATION_PROMOTED_TO_MANAGER",
                target_type="EscalationEvent",
                target_id=esc.id,
                before_value={"role": "team_lead"},
                after_value={"role": "manager", "promoted_at": now.isoformat()},
                created_at=now,
            ))

        await self.db.commit()

        summary = {
            "cases_evaluated": cases_evaluated,
            "sla_warnings_emitted": sla_warnings_emitted,
            "sla_breaches_detected": sla_breaches_detected,
            "escalations_raised": escalations_raised,
            "escalations_promoted": escalations_promoted,
            "timestamp": now,
        }
        logger.info(f"The Sweep completed: {summary}")
        return summary

    async def manual_escalate(
        self,
        case_id: uuid.UUID,
        user_id: uuid.UUID,
        reason: Optional[str] = None,
    ) -> EscalationEvent:
        """
        Operator manually requests managerial escalation per SRS §5.8 (Level 2 user action).
        """
        case_stmt = (
            select(Case)
            .options(selectinload(Case.team), selectinload(Case.owner))
            .where(Case.id == case_id, Case.deleted_at.is_(None))
        )
        c_res = await self.db.execute(case_stmt)
        case = c_res.scalar_one_or_none()
        if not case:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found")

        lead = await self._resolve_case_lead_or_owner(case)
        now = datetime.now(timezone.utc)

        esc = EscalationEvent(
            case_id=case_id,
            trigger_reason=EscalationTrigger.OPERATOR_REQUESTED,
            escalated_to_role="team_lead",
            escalated_to_user_id=lead.id if lead else None,
            escalated_by=str(user_id),
            status=EscalationStatus.OPEN,
            created_at=now,
        )
        self.db.add(esc)
        await self.db.flush()

        if lead:
            await self.notif_service.notify_escalation_raised(case, esc, lead)

        self.db.add(AuditLog(
            actor_id=user_id,
            action="OPERATOR_ESCALATION_REQUESTED",
            target_type="Case",
            target_id=case_id,
            before_value=None,
            after_value={"escalation_id": str(esc.id), "reason": reason or "Operator assistance requested"},
            created_at=now,
        ))

        await self.db.commit()
        await self.db.refresh(esc)
        logger.info(f"Operator {user_id} manually escalated case {case.reference_number}")
        return esc

    async def acknowledge_escalation(
        self,
        escalation_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> EscalationEvent:
        """Acknowledge an open escalation event per SRS §5.8."""
        stmt = select(EscalationEvent).where(EscalationEvent.id == escalation_id)
        res = await self.db.execute(stmt)
        esc = res.scalar_one_or_none()
        if not esc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Escalation not found")

        if esc.status != EscalationStatus.OPEN:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Escalation is already in '{esc.status.value}' state.",
            )

        now = datetime.now(timezone.utc)
        esc.status = EscalationStatus.ACKNOWLEDGED
        esc.escalated_to_user_id = user_id

        self.db.add(AuditLog(
            actor_id=user_id,
            action="ESCALATION_ACKNOWLEDGED",
            target_type="EscalationEvent",
            target_id=esc.id,
            before_value={"status": EscalationStatus.OPEN.value},
            after_value={"status": EscalationStatus.ACKNOWLEDGED.value, "acknowledged_by": str(user_id)},
            created_at=now,
        ))

        await self.db.commit()
        await self.db.refresh(esc)
        logger.info(f"Escalation {esc.id} acknowledged by user {user_id}")
        return esc

    async def resolve_escalation(
        self,
        escalation_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> EscalationEvent:
        """Resolve an escalation event."""
        stmt = select(EscalationEvent).where(EscalationEvent.id == escalation_id)
        res = await self.db.execute(stmt)
        esc = res.scalar_one_or_none()
        if not esc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Escalation not found")

        now = datetime.now(timezone.utc)
        esc.status = EscalationStatus.RESOLVED

        self.db.add(AuditLog(
            actor_id=user_id,
            action="ESCALATION_RESOLVED",
            target_type="EscalationEvent",
            target_id=esc.id,
            before_value={"status": esc.status.value},
            after_value={"status": EscalationStatus.RESOLVED.value, "resolved_by": str(user_id)},
            created_at=now,
        ))

        await self.db.commit()
        await self.db.refresh(esc)
        logger.info(f"Escalation {esc.id} resolved by user {user_id}")
        return esc

    # --- Internal Helpers ---

    async def _resolve_case_lead_or_owner(self, case: Case) -> Optional[User]:
        """Find the most appropriate staff user to notify."""
        if case.team and case.team.lead_id:
            lead_stmt = select(User).where(User.id == case.team.lead_id)
            res = await self.db.execute(lead_stmt)
            lead = res.scalar_one_or_none()
            if lead:
                return lead

        if case.owner_id:
            owner_stmt = select(User).where(User.id == case.owner_id)
            res = await self.db.execute(owner_stmt)
            owner = res.scalar_one_or_none()
            if owner:
                return owner

        # Fallback to any active team lead or manager
        stmt = select(User).where(User.role.in_([UserRole.TEAM_LEAD, UserRole.MANAGER])).limit(1)
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def _get_fallback_manager(self) -> Optional[User]:
        """Find a manager to escalate to."""
        stmt = select(User).where(User.role == UserRole.MANAGER).limit(1)
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def _raise_escalation_if_new(
        self,
        case_id: uuid.UUID,
        reason: EscalationTrigger,
        role: str = "team_lead",
        by: str = "system",
    ) -> Optional[EscalationEvent]:
        """Avoid duplicate open escalations with the same trigger reason."""
        stmt = select(EscalationEvent).where(
            EscalationEvent.case_id == case_id,
            EscalationEvent.trigger_reason == reason,
            EscalationEvent.status == EscalationStatus.OPEN,
        )
        res = await self.db.execute(stmt)
        existing = res.scalar_one_or_none()
        if existing:
            return None

        esc = EscalationEvent(
            case_id=case_id,
            trigger_reason=reason,
            escalated_to_role=role,
            escalated_by=by,
            status=EscalationStatus.OPEN,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(esc)
        await self.db.flush()
        return esc

    async def _emit_sla_warning_if_due(
        self,
        case: Case,
        target_user: Optional[User],
        deadline_type: str,
        remaining_seconds: float,
    ) -> bool:
        """Idempotently emit SLA warning if one hasn't been emitted recently."""
        if not target_user:
            return False

        mins_remaining = max(1, int(remaining_seconds / 60.0))
        time_str = f"{mins_remaining} minutes" if mins_remaining < 60 else f"{mins_remaining // 60} hours"

        # Check if warning was already emitted in the last 2 hours
        cutoff = datetime.now(timezone.utc) - timedelta(hours=2)
        from models.notification import Notification
        notif_stmt = select(Notification).where(
            Notification.case_id == case.id,
            Notification.event_type == NotificationEventType.SLA_WARNING,
            Notification.created_at >= cutoff,
        )
        n_res = await self.db.execute(notif_stmt)
        if n_res.scalar_one_or_none():
            return False

        await self.notif_service.notify_sla_warning(
            case=case,
            target_user=target_user,
            deadline_type=deadline_type,
            time_remaining_str=time_str,
        )
        return True
