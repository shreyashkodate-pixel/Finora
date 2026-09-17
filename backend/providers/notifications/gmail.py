import asyncio
import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

from core.config import settings
from providers.notifications.base import NotificationProvider

logger = logging.getLogger(__name__)


class GmailSmtpNotificationProvider(NotificationProvider):
    """
    Local development email provider using Gmail SMTP per SRS §3.9.
    Runs SMTP network calls off the main event loop via asyncio.to_thread.
    """

    def __init__(
        self,
        smtp_address: Optional[str] = None,
        smtp_password: Optional[str] = None,
        smtp_host: str = "smtp.gmail.com",
        smtp_port: int = 587,
    ):
        self.smtp_address = smtp_address or settings.GMAIL_SMTP_ADDRESS
        self.smtp_password = smtp_password or settings.GMAIL_SMTP_APP_PASSWORD
        self.smtp_host = smtp_host
        self.smtp_port = smtp_port
        self.sender_name = settings.EMAIL_SENDER_NAME

    def _send_sync(
        self,
        to_email: str,
        subject: str,
        body_text: str,
        body_html: Optional[str] = None,
        to_name: Optional[str] = None,
    ) -> bool:
        if not self.smtp_address or not self.smtp_password:
            logger.warning("Gmail SMTP credentials missing. Skipping email dispatch to %s.", to_email)
            return False

        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = f"{self.sender_name} <{self.smtp_address}>"
            msg["To"] = f"{to_name} <{to_email}>" if to_name else to_email

            # Attach plain text and HTML alternatives
            msg.attach(MIMEText(body_text, "plain", "utf-8"))
            if body_html:
                msg.attach(MIMEText(body_html, "html", "utf-8"))

            with smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=10) as server:
                server.ehlo()
                server.starttls()
                server.ehlo()
                server.login(self.smtp_address, self.smtp_password)
                server.sendmail(self.smtp_address, [to_email], msg.as_string())

            logger.info("Email sent successfully via Gmail SMTP to %s", to_email)
            return True
        except Exception as e:
            logger.error("Failed to send email via Gmail SMTP to %s: %s", to_email, str(e))
            return False

    async def send_email(
        self,
        to_email: str,
        subject: str,
        body_text: str,
        body_html: Optional[str] = None,
        to_name: Optional[str] = None,
    ) -> bool:
        return await asyncio.to_thread(
            self._send_sync,
            to_email,
            subject,
            body_text,
            body_html,
            to_name,
        )
