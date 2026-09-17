from abc import ABC, abstractmethod
from typing import Optional


class NotificationProvider(ABC):
    """
    Abstract interface for multi-channel email/notification delivery per SRS §3.9 & §11.
    All notification dispatching is routed through this interface.
    """

    @abstractmethod
    async def send_email(
        self,
        to_email: str,
        subject: str,
        body_text: str,
        body_html: Optional[str] = None,
        to_name: Optional[str] = None,
    ) -> bool:
        """
        Send an email message to a recipient.
        
        Args:
            to_email: Target recipient email address
            subject: Email subject line
            body_text: Plain-text fallback email body
            body_html: Rich HTML formatted email body
            to_name: Optional recipient display name
            
        Returns:
            True if accepted/sent by provider, False on failure.
            Must not raise unhandled exceptions (catches and logs errors).
        """
        pass
