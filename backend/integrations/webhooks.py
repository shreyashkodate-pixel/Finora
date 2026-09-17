import logging
from typing import Dict, Any, Optional
import httpx

from core.config import settings

logger = logging.getLogger(__name__)


class WebhookDispatcher:
    """
    Asynchronous Webhook Dispatcher for Slack, Microsoft Teams, and custom HTTP endpoints.
    """

    @staticmethod
    async def dispatch_slack_alert(
        webhook_url: Optional[str],
        title: str,
        message: str,
        priority: str = "P1",
        color: str = "#dc2626",
        fields: Optional[Dict[str, str]] = None,
    ) -> bool:
        url = webhook_url or getattr(settings, "SLACK_WEBHOOK_URL", None)
        if not url:
            logger.info(f"[SLACK-SIMULATION] Slack webhook not configured. Alert '{title}' logged internally.")
            return True

        blocks = [
            {
                "type": "header",
                "text": {"type": "plain_text", "text": f"🚨 [{priority.upper()}] {title}"},
            },
            {
                "type": "section",
                "text": {"type": "mrkdwn", "text": message},
            },
        ]

        if fields:
            field_elements = [{"type": "mrkdwn", "text": f"*{k}:*\n{v}"} for k, v in fields.items()]
            blocks.append({
                "type": "section",
                "fields": field_elements[:10],
            })

        payload = {
            "attachments": [
                {
                    "color": color,
                    "blocks": blocks,
                }
            ]
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.post(url, json=payload)
                return res.status_code in (200, 204)
        except Exception as exc:
            logger.error(f"Failed to dispatch Slack webhook alert: {exc}")
            return False

    @staticmethod
    async def dispatch_teams_alert(
        webhook_url: Optional[str],
        title: str,
        message: str,
        priority: str = "P1",
        fields: Optional[Dict[str, str]] = None,
    ) -> bool:
        url = webhook_url or getattr(settings, "TEAMS_WEBHOOK_URL", None)
        if not url:
            logger.info(f"[TEAMS-SIMULATION] Teams webhook not configured. Alert '{title}' logged internally.")
            return True

        facts = []
        if fields:
            facts = [{"name": k, "value": v} for k, v in fields.items()]

        payload = {
            "@type": "MessageCard",
            "@context": "http://schema.org/extensions",
            "themeColor": "DC2626",
            "summary": f"[{priority.upper()}] {title}",
            "sections": [
                {
                    "activityTitle": f"🚨 [{priority.upper()}] {title}",
                    "activitySubtitle": "AI IT Helpdesk Critical Incident Alert",
                    "text": message,
                    "facts": facts,
                    "markdown": True,
                }
            ],
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.post(url, json=payload)
                return res.status_code in (200, 204)
        except Exception as exc:
            logger.error(f"Failed to dispatch Teams webhook alert: {exc}")
            return False
