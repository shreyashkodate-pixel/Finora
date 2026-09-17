import logging
from typing import Optional
import httpx

from core.config import settings
from providers.notifications.base import NotificationProvider

logger = logging.getLogger(__name__)


class BrevoNotificationProvider(NotificationProvider):
    """
    Staging & production email provider using Brevo's HTTP API over port 443 per SRS §3.9 & §7.13.
    Bypasses cloud platform outbound SMTP port restrictions (e.g. Render free tier).
    """

    BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"

    def __init__(
        self,
        api_key: Optional[str] = None,
        sender_email: Optional[str] = None,
        sender_name: Optional[str] = None,
    ):
        self.api_key = api_key or settings.BREVO_API_KEY
        self.sender_email = sender_email or settings.EMAIL_SENDER_ADDRESS
        self.sender_name = sender_name or settings.EMAIL_SENDER_NAME

    async def send_email(
        self,
        to_email: str,
        subject: str,
        body_text: str,
        body_html: Optional[str] = None,
        to_name: Optional[str] = None,
    ) -> bool:
        if not self.api_key:
            logger.warning("Brevo API key missing. Skipping email dispatch to %s.", to_email)
            return False

        headers = {
            "api-key": self.api_key,
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

        recipient_payload = {"email": to_email}
        if to_name:
            recipient_payload["name"] = to_name

        payload = {
            "sender": {
                "name": self.sender_name,
                "email": self.sender_email,
            },
            "to": [recipient_payload],
            "subject": subject,
            "textContent": body_text,
        }
        if body_html:
            payload["htmlContent"] = body_html

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(self.BREVO_API_URL, headers=headers, json=payload)
                if response.status_code in (200, 201, 202):
                    logger.info("Email sent successfully via Brevo HTTP API to %s", to_email)
                    return True
                else:
                    logger.error(
                        "Brevo HTTP API error (%s): %s",
                        response.status_code,
                        response.text,
                    )
                    return False
        except Exception as e:
            logger.error("Failed to dispatch email via Brevo HTTP API to %s: %s", to_email, str(e))
            return False
