import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from api.deps import get_current_active_user, require_roles
from db.session import get_db_session
from models.enums import ProblemStatus, CasePriority, UserRole
from models.user import User
from schemas.problem_change import (
    ProblemCreate,
    ProblemUpdate,
    ProblemOut,
    ProblemCaseLinkOut,
    ProblemCaseLinkCreate,
    KnownErrorCreate,
    KnownErrorOut,
)
from services.problem_change_service import ProblemService

router = APIRouter(prefix="/problems", tags=["Problem Management"])


@router.post(
    "",
    response_model=ProblemOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Problem record",
)
async def create_problem(
    payload: ProblemCreate,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = ProblemService(db)
    return await service.create_problem(payload, current_user)


@router.get(
    "",
    response_model=List[ProblemOut],
    summary="List Problem records",
)
async def list_problems(
    status: Optional[ProblemStatus] = Query(None),
    priority: Optional[CasePriority] = Query(None),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = ProblemService(db)
    items, _ = await service.list_problems(
        status_filter=status,
        priority_filter=priority,
        limit=limit,
        offset=offset,
    )
    return items


@router.get(
    "/{problem_id}",
    response_model=ProblemOut,
    summary="Get Problem by ID",
)
async def get_problem(
    problem_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = ProblemService(db)
    return await service.get_problem(problem_id)


@router.patch(
    "/{problem_id}",
    response_model=ProblemOut,
    summary="Update Problem record",
)
async def update_problem(
    problem_id: uuid.UUID,
    payload: ProblemUpdate,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = ProblemService(db)
    return await service.update_problem(problem_id, payload, current_user)


@router.post(
    "/{problem_id}/link-case",
    response_model=ProblemCaseLinkOut,
    summary="Link an Incident/Case to a Problem",
)
async def link_case(
    problem_id: uuid.UUID,
    payload: ProblemCaseLinkCreate,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = ProblemService(db)
    return await service.link_case(problem_id, payload.case_id, current_user)


@router.delete(
    "/{problem_id}/unlink-case/{case_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Unlink a Case from a Problem",
)
async def unlink_case(
    problem_id: uuid.UUID,
    case_id: uuid.UUID,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = ProblemService(db)
    await service.unlink_case(problem_id, case_id, current_user)
    return None


@router.post(
    "/{problem_id}/known-error",
    response_model=KnownErrorOut,
    status_code=status.HTTP_201_CREATED,
    summary="Publish Known Error article for a Problem",
)
async def create_known_error(
    problem_id: uuid.UUID,
    payload: KnownErrorCreate,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = ProblemService(db)
    return await service.create_known_error(problem_id, payload, current_user)
