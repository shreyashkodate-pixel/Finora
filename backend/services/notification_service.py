import logging
import uuid
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy import select, func, update
from sqlalchemy.ext.asyncio import AsyncSession

from models.case import Case
from models.user import User
from models.message import Message
from models.notification import Notification
from models.enums import NotificationEventType, MessageVisibility
from providers.notifications.base import NotificationProvider
from providers.notifications import get_notification_provider

logger = logging.getLogger(__name__)


def _render_email_html(title: str, body_text: str, reference_number: Optional[str] = None) -> str:
    """Generate clean HTML email template for notifications."""
    ref_badge = f'<div style="font-size:12px;font-weight:bold;color:#4f46e5;margin-bottom:8px;">{reference_number}</div>' if reference_number else ''
    return f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;line-height:1.6;color:#1e293b;background-color:#f8fafc;margin:0;padding:20px;">
  <div style="max-width:600px;margin:0 auto;background:#ffffff;border:1px solid #e2e8f0;border-radius:8px;padding:24px;">
    {ref_badge}
    <h2 style="margin-top:0;color:#0f172a;font-size:20px;">{title}</h2>
    <div style="color:#334155;font-size:15px;white-space:pre-line;margin-bottom:20px;">{body_text}</div>
    <hr style="border:none;border-top:1px solid #e2e8f0;margin:20px 0;">
    <p style="font-size:12px;color:#94a3b8;margin:0;">AI IT Helpdesk Notification &bull; This is an automated message.</p>
  </div>
</body>
</html>"""


class NotificationService:
    """Service orchestrating in-app notifications and email dispatching per SRS §3.9 & §5.10."""

    def __init__(self, db: AsyncSession, provider: Optional[NotificationProvider] = None):
        self.db = db
        self.provider = provider or get_notification_provider()

    async def _create_and_send(
        self,
        user_id: uuid.UUID,
        to_email: Optional[str],
        case_id: Optional[uuid.UUID],
        title: str,
        message: str,
        event_type: NotificationEventType,
        reference_number: Optional[str] = None,
    ) -> Notification:
        """Persist in-app notification and dispatch email non-blockingly."""
        notif = Notification(
            user_id=user_id,
            case_id=case_id,
            title=title,
            message=message,
            event_type=event_type,
            is_read=False,
        )
        self.db.add(notif)
        await self.db.flush()

        if to_email:
            html_content = _render_email_html(title, message, reference_number)
            try:
                await self.provider.send_email(
                    to_email=to_email,
                    subject=title,
                    body_text=message,
                    body_html=html_content,
                )
            except Exception as e:
                # Per SRS §7.7 & §7.14: Email failure must never block or roll back DB transaction
                logger.warning(
                    "Email send failed for event %s to %s: %s",
                    event_type.value,
                    to_email,
                    str(e),
                )

        return notif

    async def notify_case_created(self, case: Case, requester: User) -> Optional[Notification]:
        """Intake confirmation notification with reference number and SLA targets."""
        title = f"Case Received: {case.reference_number} — {case.title}"
        body = (
            f"Your support request '{case.title}' has been received and registered under "
            f"reference number {case.reference_number}.\n\n"
            f"Priority: {case.priority.value.upper()}\n"
            f"Type: {case.type.value.replace('_', ' ').title()}\n\n"
            f"Our team will begin assessment shortly. You can track progress or reply with additional details anytime."
        )
        return await self._create_and_send(
            user_id=requester.id,
            to_email=requester.email,
            case_id=case.id,
            title=title,
            message=body,
            event_type=NotificationEventType.CASE_CREATED,
            reference_number=case.reference_number,
        )

    async def notify_case_assigned(
        self,
        case: Case,
        assignee: User,
        assigner: Optional[User] = None,
    ) -> Optional[Notification]:
        """Alert assignee when a case is assigned or reassigned to them."""
        assigner_desc = assigner.email if assigner else "System"
        title = f"Case Assigned: {case.reference_number}"
        body = (
            f"Case {case.reference_number} ('{case.title}') has been assigned to you by {assigner_desc}.\n\n"
            f"Priority: {case.priority.value.upper()}\n"
            f"Status: {case.status.value.replace('_', ' ').title()}\n\n"
            f"Please review the intake details and initiate assessment."
        )
        return await self._create_and_send(
            user_id=assignee.id,
            to_email=assignee.email,
            case_id=case.id,
            title=title,
            message=body,
            event_type=NotificationEventType.CASE_ASSIGNED,
            reference_number=case.reference_number,
        )

    async def notify_new_message(
        self,
        case: Case,
        message: Message,
        author: User,
        recipient: User,
    ) -> Optional[Notification]:
        """
        Notify recipient of a new communication.
        Never notifies requesters on internal_only messages.
        """
        if message.visibility == MessageVisibility.INTERNAL_ONLY and recipient.id == case.requester_id:
            # Strictly forbidden per SRS §2.2 & §7.6
            return None

        title = f"New Message: {case.reference_number}"
        snippet = message.body[:200] + ("..." if len(message.body) > 200 else "")
        body = (
            f"{author.email} added an update to case {case.reference_number}:\n\n"
            f"\"{snippet}\"\n\n"
            f"Log in to view the complete message thread."
        )
        return await self._create_and_send(
            user_id=recipient.id,
            to_email=recipient.email,
            case_id=case.id,
            title=title,
            message=body,
            event_type=NotificationEventType.NEW_MESSAGE,
            reference_number=case.reference_number,
        )

    async def notify_case_resolved(
        self,
        case: Case,
        resolver: User,
        requester: User,
    ) -> Optional[Notification]:
        """Notify requester when their case is marked Resolved."""
        title = f"Case Resolved: {case.reference_number}"
        body = (
            f"Your case {case.reference_number} ('{case.title}') has been marked as Resolved by {resolver.email}.\n\n"
            f"If you are satisfied with this resolution, no further action is needed.\n"
            f"If the issue persists, you may reopen this case within 7 calendar days."
        )
        return await self._create_and_send(
            user_id=requester.id,
            to_email=requester.email,
            case_id=case.id,
            title=title,
            message=body,
            event_type=NotificationEventType.CASE_RESOLVED,
            reference_number=case.reference_number,
        )

    async def notify_case_reopened(
        self,
        case: Case,
        reopener: User,
        target_user: User,
    ) -> Optional[Notification]:
        """Notify staff owner/lead when a case is reopened."""
        title = f"Case Reopened: {case.reference_number}"
        body = (
            f"Case {case.reference_number} ('{case.title}') was reopened by {reopener.email}.\n\n"
            f"The case status has returned to Assigned and a new SLA clock is active."
        )
        return await self._create_and_send(
            user_id=target_user.id,
            to_email=target_user.email,
            case_id=case.id,
            title=title,
            message=body,
            event_type=NotificationEventType.CASE_REOPENED,
            reference_number=case.reference_number,
        )

    async def list_notifications(
        self,
        user_id: uuid.UUID,
        unread_only: bool = False,
        page: int = 1,
        per_page: int = 20,
    ) -> Tuple[List[Notification], int, int]:
        """Query paginated notifications and total/unread counts for a user."""
        base_stmt = select(Notification).where(Notification.user_id == user_id)
        if unread_only:
            base_stmt = base_stmt.where(Notification.is_read.is_(False))

        # Total matching count
        count_stmt = select(func.count(Notification.id)).where(Notification.user_id == user_id)
        if unread_only:
            count_stmt = count_stmt.where(Notification.is_read.is_(False))
        total_res = await self.db.execute(count_stmt)
        total = total_res.scalar() or 0

        # Unread count (always total unread for badges)
        unread_stmt = select(func.count(Notification.id)).where(
            Notification.user_id == user_id,
            Notification.is_read.is_(False),
        )
        unread_res = await self.db.execute(unread_stmt)
        unread_count = unread_res.scalar() or 0

        # Paginated items
        stmt = (
            base_stmt
            .order_by(Notification.created_at.desc())
            .offset((page - 1) * per_page)
            .limit(per_page)
        )
        res = await self.db.execute(stmt)
        items = list(res.scalars().all())

        return items, total, unread_count

    async def get_unread_count(self, user_id: uuid.UUID) -> int:
        """Get badge count of unread notifications."""
        stmt = select(func.count(Notification.id)).where(
            Notification.user_id == user_id,
            Notification.is_read.is_(False),
        )
        res = await self.db.execute(stmt)
        return res.scalar() or 0

    async def mark_as_read(self, notification_id: uuid.UUID, user_id: uuid.UUID) -> Notification:
        """Mark a single notification as read."""
        stmt = select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == user_id,
        )
        res = await self.db.execute(stmt)
        notif = res.scalar_one_or_none()
        if not notif:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": {
                        "code": "NOTIFICATION_NOT_FOUND",
                        "message": f"Notification {notification_id} not found.",
                        "details": {},
                    }
                },
            )
        notif.is_read = True
        await self.db.commit()
        await self.db.refresh(notif)
        return notif

    async def mark_all_as_read(self, user_id: uuid.UUID) -> int:
        """Mark all notifications as read for a user."""
        stmt = (
            update(Notification)
            .where(Notification.user_id == user_id, Notification.is_read.is_(False))
            .values(is_read=True)
        )
        res = await self.db.execute(stmt)
        await self.db.commit()
        return res.rowcount or 0
