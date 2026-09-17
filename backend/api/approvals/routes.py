import uuid
from typing import List
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from api.deps import get_current_active_user, require_roles
from db.session import get_db_session
from models.enums import UserRole
from models.user import User
from schemas.approval import (
    ApprovalRequestCreate,
    ApprovalDecisionSubmit,
    ApprovalOut,
    ApprovalListOut,
)
from services.approval_service import ApprovalService

router = APIRouter(tags=["Approvals"])


@router.post(
    "/cases/{case_id}/approvals",
    response_model=ApprovalOut,
    status_code=status.HTTP_201_CREATED,
    summary="Request business approval on a case (Staff only)",
)
async def request_approval(
    case_id: uuid.UUID,
    payload: ApprovalRequestCreate,
    current_user: User = Depends(
        require_roles([
            UserRole.OPERATOR,
            UserRole.TEAM_LEAD,
            UserRole.MANAGER,
            UserRole.ADMINISTRATOR,
        ])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = ApprovalService(db)
    return await service.request_approval(case_id, payload, current_user)


@router.get(
    "/cases/{case_id}/approvals",
    response_model=List[ApprovalOut],
    summary="List all approval requests for a case",
)
async def list_approvals_for_case(
    case_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = ApprovalService(db)
    return await service.list_approvals_for_case(case_id, current_user)


@router.get(
    "/approvals/pending",
    response_model=ApprovalListOut,
    summary="List pending approvals awaiting decision",
)
async def list_pending_approvals(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(
        require_roles([
            UserRole.TEAM_LEAD,
            UserRole.MANAGER,
            UserRole.ADMINISTRATOR,
        ])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = ApprovalService(db)
    items, total = await service.list_pending_approvals(
        current_user=current_user,
        limit=limit,
        offset=offset,
    )
    return ApprovalListOut(items=items, total=total)


@router.post(
    "/approvals/{approval_id}/decision",
    response_model=ApprovalOut,
    summary="Submit approval decision (Designated Approver or Manager)",
)
async def decide_approval(
    approval_id: uuid.UUID,
    payload: ApprovalDecisionSubmit,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = ApprovalService(db)
    return await service.decide_approval(approval_id, payload, current_user)
