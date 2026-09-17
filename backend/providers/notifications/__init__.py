from typing import Optional
from core.config import settings
from providers.notifications.base import NotificationProvider
from providers.notifications.gmail import GmailSmtpNotificationProvider
from providers.notifications.brevo import BrevoNotificationProvider
from providers.notifications.mock import MockNotificationProvider


_notification_provider_instance: Optional[NotificationProvider] = None


def get_notification_provider() -> NotificationProvider:
    """
    Factory function returning the environment-appropriate notification provider per SRS §3.9.
    - Staging/Production: BrevoNotificationProvider (port 443 HTTPS REST)
    - Local: GmailSmtpNotificationProvider if credentials present, otherwise MockNotificationProvider
    """
    global _notification_provider_instance
    if _notification_provider_instance is not None:
        return _notification_provider_instance

    if settings.ENVIRONMENT in ("staging", "production"):
        _notification_provider_instance = BrevoNotificationProvider(
            api_key=settings.BREVO_API_KEY,
            sender_email=settings.EMAIL_SENDER_ADDRESS,
            sender_name=settings.EMAIL_SENDER_NAME,
        )
    elif settings.GMAIL_SMTP_ADDRESS and settings.GMAIL_SMTP_APP_PASSWORD and not settings.GMAIL_SMTP_ADDRESS.startswith("your_"):
        _notification_provider_instance = GmailSmtpNotificationProvider(
            smtp_address=settings.GMAIL_SMTP_ADDRESS,
            smtp_password=settings.GMAIL_SMTP_APP_PASSWORD,
        )
    else:
        _notification_provider_instance = MockNotificationProvider()

    return _notification_provider_instance


def set_notification_provider(provider: Optional[NotificationProvider]) -> None:
    """Override or reset the notification provider instance (for test fixtures)."""
    global _notification_provider_instance
    _notification_provider_instance = provider


__all__ = [
    "NotificationProvider",
    "GmailSmtpNotificationProvider",
    "BrevoNotificationProvider",
    "MockNotificationProvider",
    "get_notification_provider",
    "set_notification_provider",
]
