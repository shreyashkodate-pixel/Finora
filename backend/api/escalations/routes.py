import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from api.deps import get_current_active_user, require_roles
from db.session import get_db_session
from models.user import User
from models.enums import UserRole, EscalationStatus
from models.case import Case
from models.ai import EscalationEvent
from schemas.escalation import EscalationEventOut, ManualEscalateRequest, SweepResultOut
from services.sweep_service import SweepService

router = APIRouter(tags=["Escalations & The Sweep"])

STAFF_ROLES = [
    UserRole.OPERATOR,
    UserRole.TEAM_LEAD,
    UserRole.MANAGER,
    UserRole.ADMINISTRATOR,
]

MANAGEMENT_ROLES = [
    UserRole.TEAM_LEAD,
    UserRole.MANAGER,
    UserRole.ADMINISTRATOR,
]


@router.post("/cases/{case_id}/escalate", response_model=EscalationEventOut, status_code=status.HTTP_201_CREATED)
async def manual_case_escalation(
    case_id: uuid.UUID,
    payload: ManualEscalateRequest,
    current_user: User = Depends(require_roles(STAFF_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Operator explicitly requests managerial help per SRS §5.8 (Level 2 action).
    Always human-triggered; never automatic.
    """
    sweep_service = SweepService(db)
    return await sweep_service.manual_escalate(
        case_id=case_id,
        user_id=current_user.id,
        reason=payload.reason,
    )


@router.get("/cases/{case_id}/escalations", response_model=List[EscalationEventOut])
async def list_case_escalations(
    case_id: uuid.UUID,
    current_user: User = Depends(require_roles(STAFF_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """List all escalation events for a given case."""
    stmt = (
        select(EscalationEvent)
        .where(EscalationEvent.case_id == case_id)
        .order_by(EscalationEvent.created_at.desc())
    )
    res = await db.execute(stmt)
    return res.scalars().all()


@router.patch("/escalations/{escalation_id}/acknowledge", response_model=EscalationEventOut)
async def acknowledge_escalation(
    escalation_id: uuid.UUID,
    current_user: User = Depends(require_roles(MANAGEMENT_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """Team Lead or Manager acknowledges an active escalation."""
    sweep_service = SweepService(db)
    return await sweep_service.acknowledge_escalation(
        escalation_id=escalation_id,
        user_id=current_user.id,
    )


@router.patch("/escalations/{escalation_id}/resolve", response_model=EscalationEventOut)
async def resolve_escalation(
    escalation_id: uuid.UUID,
    current_user: User = Depends(require_roles(MANAGEMENT_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """Team Lead or Manager resolves an active escalation."""
    sweep_service = SweepService(db)
    return await sweep_service.resolve_escalation(
        escalation_id=escalation_id,
        user_id=current_user.id,
    )


@router.post("/sweep/trigger", response_model=SweepResultOut)
async def trigger_sweep_on_demand(
    current_user: User = Depends(require_roles(MANAGEMENT_ROLES)),
    db: AsyncSession = Depends(get_db_session),
):
    """Trigger an immediate execution of The Sweep (Staff / Admin only)."""
    sweep_service = SweepService(db)
    summary = await sweep_service.run_sweep()
    return summary
