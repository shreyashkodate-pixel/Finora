import uuid
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from api.deps import get_current_active_user
from db.session import get_db_session
from models.user import User
from schemas.notification import (
    NotificationOut,
    NotificationListOut,
    UnreadCountOut,
)
from services.notification_service import NotificationService

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("", response_model=NotificationListOut, summary="List notifications for current user")
async def list_notifications(
    unread_only: bool = Query(False, description="Filter unread notifications only"),
    page: int = Query(1, ge=1, description="Page number"),
    per_page: int = Query(20, ge=1, le=100, description="Items per page"),
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Retrieve paginated in-app notifications for the authenticated user."""
    service = NotificationService(db)
    items, total, unread_count = await service.list_notifications(
        user_id=current_user.id,
        unread_only=unread_only,
        page=page,
        per_page=per_page,
    )
    return NotificationListOut(
        items=[NotificationOut.model_validate(n) for n in items],
        total=total,
        unread_count=unread_count,
        page=page,
        per_page=per_page,
    )


@router.get("/unread-count", response_model=UnreadCountOut, summary="Get unread notification count")
async def get_unread_count(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Get the current count of unread notifications for badge counters."""
    service = NotificationService(db)
    count = await service.get_unread_count(current_user.id)
    return UnreadCountOut(unread_count=count)


@router.patch("/{notification_id}/read", response_model=NotificationOut, summary="Mark notification as read")
async def mark_notification_read(
    notification_id: uuid.UUID,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Mark a specific notification as read."""
    service = NotificationService(db)
    notif = await service.mark_as_read(notification_id, current_user.id)
    return NotificationOut.model_validate(notif)


@router.post("/mark-all-read", summary="Mark all notifications as read")
async def mark_all_notifications_read(
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Mark all unread notifications as read for the authenticated user."""
    service = NotificationService(db)
    marked = await service.mark_all_as_read(current_user.id)
    return {"marked_count": marked, "unread_count": 0}
