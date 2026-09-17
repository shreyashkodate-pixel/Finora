import uuid
from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from api.deps import get_current_active_user, require_roles
from db.session import get_db_session
from models.enums import UserRole
from models.user import User
from schemas.autofix import (
    AutoFixProposeRequest,
    AutoFixExecuteRequest,
    AutoFixActionOut,
)
from services.autofix_service import AutoFixService

router = APIRouter(prefix="/autofix", tags=["Controlled Auto-Fix"])


@router.post(
    "/propose/{case_id}",
    response_model=AutoFixActionOut,
    status_code=status.HTTP_201_CREATED,
    summary="Propose a controlled auto-fix remediation action",
)
async def propose_autofix(
    case_id: uuid.UUID,
    payload: AutoFixProposeRequest,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = AutoFixService(db)
    return await service.propose_autofix(case_id, payload, current_user)


@router.post(
    "/execute/{action_id}",
    response_model=AutoFixActionOut,
    summary="Execute proposed auto-fix with human confirmation",
)
async def execute_autofix(
    action_id: uuid.UUID,
    payload: AutoFixExecuteRequest,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = AutoFixService(db)
    return await service.execute_autofix(action_id, payload, current_user)


@router.post(
    "/rollback/{action_id}",
    response_model=AutoFixActionOut,
    summary="Rollback executed auto-fix action",
)
async def rollback_autofix(
    action_id: uuid.UUID,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = AutoFixService(db)
    return await service.rollback_autofix(action_id, current_user)


@router.get(
    "/case/{case_id}",
    response_model=List[AutoFixActionOut],
    summary="List all auto-fix actions for a case",
)
async def list_actions_for_case(
    case_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = AutoFixService(db)
    return await service.list_actions_for_case(case_id, current_user)
