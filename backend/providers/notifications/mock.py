import time
from typing import List, Dict, Any, Optional
from providers.notifications.base import NotificationProvider


class MockNotificationProvider(NotificationProvider):
    """
    In-memory mock notification provider for testing and offline environments.
    Captures sent messages and allows assertions on outbound emails.
    """

    def __init__(self, simulate_failure: bool = False):
        self.sent_emails: List[Dict[str, Any]] = []
        self.simulate_failure = simulate_failure

    async def send_email(
        self,
        to_email: str,
        subject: str,
        body_text: str,
        body_html: Optional[str] = None,
        to_name: Optional[str] = None,
    ) -> bool:
        if self.simulate_failure:
            return False

        self.sent_emails.append({
            "to_email": to_email,
            "to_name": to_name,
            "subject": subject,
            "body_text": body_text,
            "body_html": body_html,
            "timestamp": time.time(),
        })
        return True

    def clear(self) -> None:
        self.sent_emails.clear()
