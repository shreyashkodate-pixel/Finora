import uuid
from typing import Optional, List
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from api.deps import get_current_active_user
from db.session import get_db_session
from models.user import User
from models.enums import CaseType, CaseStatus, CasePriority
from schemas.case import (
    CaseCreate,
    CaseUpdate,
    CaseStatusTransition,
    CaseOut,
    CaseListOut,
    MessageCreate,
    MessageOut,
    CaseRelationshipCreate,
    CaseRelationshipOut,
    AuditLogOut,
)
from services.case_service import CaseService

router = APIRouter(prefix="/cases", tags=["Cases"])


@router.post("", response_model=CaseOut, status_code=status.HTTP_201_CREATED)
async def create_case(
    payload: CaseCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Create a new case with auto-generated reference number and 24/7 SLA targets."""
    service = CaseService(db)
    return await service.create_case(current_user, payload)


@router.get("", response_model=CaseListOut)
async def list_cases(
    status: Optional[CaseStatus] = Query(None, description="Filter by case status"),
    type: Optional[CaseType] = Query(None, description="Filter by case type"),
    priority: Optional[CasePriority] = Query(None, description="Filter by case priority"),
    search: Optional[str] = Query(None, description="Full-text search in reference, title, description"),
    page: int = Query(1, ge=1, description="Page number"),
    per_page: int = Query(20, ge=1, le=100, description="Items per page"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """List cases with role-based scoping, pagination, and multi-field search."""
    service = CaseService(db)
    items, total = await service.list_cases(
        current_user=current_user,
        status_filter=status,
        type_filter=type,
        priority_filter=priority,
        search=search,
        page=page,
        per_page=per_page,
    )
    return CaseListOut(
        items=[CaseOut.model_validate(c) for c in items],
        total=total,
        page=page,
        per_page=per_page,
    )


@router.get("/{case_id}", response_model=CaseOut)
async def get_case(
    case_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Retrieve detailed case information with SLA data and role-based access validation."""
    service = CaseService(db)
    return await service.get_case_by_id(case_id, current_user)


@router.patch("/{case_id}", response_model=CaseOut)
async def update_case(
    case_id: uuid.UUID,
    payload: CaseUpdate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Update case metadata and assignment with optimistic concurrency locking."""
    service = CaseService(db)
    return await service.update_case(case_id, current_user, payload)


@router.post("/{case_id}/transition", response_model=CaseOut)
@router.patch("/{case_id}/status", response_model=CaseOut)
async def transition_case_status(
    case_id: uuid.UUID,
    payload: CaseStatusTransition,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Transition case status through formal lifecycle state machine per SRS §6.1."""
    service = CaseService(db)
    return await service.transition_status(case_id, current_user, payload)


@router.post("/{case_id}/reopen", response_model=CaseOut)
async def reopen_case(
    case_id: uuid.UUID,
    payload: CaseStatusTransition,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Reopen a resolved or closed case within 7 days per SRS §6.1."""
    payload.new_status = CaseStatus.ASSIGNED
    service = CaseService(db)
    return await service.transition_status(case_id, current_user, payload)


@router.delete("/{case_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_case(
    case_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Soft delete case per SRS §7.10."""
    service = CaseService(db)
    await service.soft_delete_case(case_id, current_user)
    return None


@router.post("/{case_id}/messages", response_model=MessageOut, status_code=status.HTTP_201_CREATED)
async def add_message(
    case_id: uuid.UUID,
    payload: MessageCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Add message/note to case with visibility enforcement (Requesters restricted to requester_visible)."""
    service = CaseService(db)
    return await service.add_message(case_id, current_user, payload)


@router.get("/{case_id}/messages", response_model=List[MessageOut])
async def list_messages(
    case_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """List messages for case with strict requester-side masking of internal_only notes."""
    service = CaseService(db)
    return await service.list_messages(case_id, current_user)


@router.post("/{case_id}/relationships", response_model=CaseRelationshipOut, status_code=status.HTTP_201_CREATED)
async def link_relationship(
    case_id: uuid.UUID,
    payload: CaseRelationshipCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Link case relationship (duplicate_of, related_to, part_of_major_incident)."""
    service = CaseService(db)
    return await service.link_case_relationship(case_id, current_user, payload)


@router.get("/{case_id}/audit-logs", response_model=List[AuditLogOut])
async def list_audit_logs(
    case_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """View append-only audit trail for a case (staff only)."""
    service = CaseService(db)
    return await service.list_audit_logs(case_id, current_user)
