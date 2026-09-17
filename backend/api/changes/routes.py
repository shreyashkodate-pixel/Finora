import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from api.deps import get_current_active_user, require_roles
from db.session import get_db_session
from models.enums import ChangeStatus, ChangeType, UserRole
from models.user import User
from schemas.problem_change import (
    ChangeRequestCreate,
    ChangeRequestUpdate,
    ChangeRequestOut,
    CABDecisionCreate,
)
from services.problem_change_service import ChangeService

router = APIRouter(prefix="/changes", tags=["Change Management"])


@router.post(
    "",
    response_model=ChangeRequestOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create Change Request",
)
async def create_change_request(
    payload: ChangeRequestCreate,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = ChangeService(db)
    return await service.create_change_request(payload, current_user)


@router.get(
    "",
    response_model=List[ChangeRequestOut],
    summary="List Change Requests",
)
async def list_change_requests(
    status: Optional[ChangeStatus] = Query(None),
    type: Optional[ChangeType] = Query(None),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = ChangeService(db)
    items, _ = await service.list_change_requests(
        status_filter=status,
        type_filter=type,
        limit=limit,
        offset=offset,
    )
    return items


@router.get(
    "/{change_id}",
    response_model=ChangeRequestOut,
    summary="Get Change Request by ID",
)
async def get_change_request(
    change_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = ChangeService(db)
    return await service.get_change_request(change_id)


@router.post(
    "/{change_id}/cab-decision",
    response_model=ChangeRequestOut,
    summary="Record CAB Decision for Change Request",
)
async def record_cab_decision(
    change_id: uuid.UUID,
    payload: CABDecisionCreate,
    current_user: User = Depends(
        require_roles([UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = ChangeService(db)
    return await service.cab_decision(change_id, payload, current_user)


@router.patch(
    "/{change_id}/status",
    response_model=ChangeRequestOut,
    summary="Advance Change Request status",
)
async def update_change_status(
    change_id: uuid.UUID,
    new_status: ChangeStatus = Query(..., description="Target change status"),
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = ChangeService(db)
    return await service.update_change_status(change_id, new_status, current_user)
