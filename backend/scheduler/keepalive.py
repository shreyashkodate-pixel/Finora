import logging
import httpx

from core.config import settings

logger = logging.getLogger("helpdesk.scheduler.keepalive")


async def ping_self_health() -> None:
    """
    Periodic self-health pinger per SRS §3.1 & §3.5.
    Hits GET /api/v1/health to keep Render free-tier instances awake during active hours.
    """
    health_url = f"{settings.API_BASE_URL.rstrip('/')}/health"
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(health_url)
            if response.status_code == 200:
                logger.debug(f"Keepalive ping successful to {health_url}")
            else:
                logger.warning(f"Keepalive ping returned status {response.status_code}")
    except Exception as exc:
        logger.debug(f"Keepalive ping could not reach {health_url}: {exc}")
