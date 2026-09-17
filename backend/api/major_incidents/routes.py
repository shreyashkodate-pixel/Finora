import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from api.deps import get_current_active_user, require_roles
from db.session import get_db_session
from models.enums import MajorIncidentStatus, UserRole
from models.user import User
from schemas.problem_change import (
    MajorIncidentCreate,
    MajorIncidentUpdate,
    MajorIncidentOut,
    MajorIncidentTimelineCreate,
    MajorIncidentTimelineOut,
)
from services.problem_change_service import MajorIncidentService

router = APIRouter(prefix="/major-incidents", tags=["Major Incident Management"])


@router.post(
    "",
    response_model=MajorIncidentOut,
    status_code=status.HTTP_201_CREATED,
    summary="Declare a Major Incident for a critical P1 outage",
)
async def declare_major_incident(
    payload: MajorIncidentCreate,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = MajorIncidentService(db)
    return await service.declare_major_incident(payload, current_user)


@router.get(
    "",
    response_model=List[MajorIncidentOut],
    summary="List Major Incidents",
)
async def list_major_incidents(
    status: Optional[MajorIncidentStatus] = Query(None),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = MajorIncidentService(db)
    items, _ = await service.list_major_incidents(
        status_filter=status,
        limit=limit,
        offset=offset,
    )
    return items


@router.get(
    "/{incident_id}",
    response_model=MajorIncidentOut,
    summary="Get Major Incident by ID",
)
async def get_major_incident(
    incident_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    service = MajorIncidentService(db)
    return await service.get_major_incident(incident_id)


@router.patch(
    "/{incident_id}",
    response_model=MajorIncidentOut,
    summary="Update Major Incident status / details",
)
async def update_major_incident(
    incident_id: uuid.UUID,
    payload: MajorIncidentUpdate,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = MajorIncidentService(db)
    return await service.update_major_incident(incident_id, payload, current_user)


@router.post(
    "/{incident_id}/timeline",
    response_model=MajorIncidentTimelineOut,
    status_code=status.HTTP_201_CREATED,
    summary="Add chronological timeline event to Major Incident war-room",
)
async def add_timeline_event(
    incident_id: uuid.UUID,
    payload: MajorIncidentTimelineCreate,
    current_user: User = Depends(
        require_roles([UserRole.OPERATOR, UserRole.TEAM_LEAD, UserRole.MANAGER, UserRole.ADMINISTRATOR])
    ),
    db: AsyncSession = Depends(get_db_session),
):
    service = MajorIncidentService(db)
    return await service.add_timeline_event(incident_id, payload, current_user)
