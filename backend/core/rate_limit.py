import time
from collections import defaultdict
from typing import Dict, List
from fastapi import Request, HTTPException, status

from core.config import settings


class InMemoryRateLimiter:
    """
    Sliding window in-memory rate limiter per SRS §7.3.
    Tracks timestamps per IP/client key.
    """

    def __init__(self, requests_limit: int = 10, window_seconds: int = 60):
        self.requests_limit = requests_limit
        self.window_seconds = window_seconds
        self.requests: Dict[str, List[float]] = defaultdict(list)

    async def __call__(self, request: Request) -> None:
        # Rate limiting disabled in local development unless configured otherwise (§3.3a)
        if settings.ENVIRONMENT == "local" and settings.DEBUG:
            return

        client_ip = request.client.host if request.client else "unknown"
        now = time.time()
        window_start = now - self.window_seconds

        # Clean old requests outside the sliding window
        self.requests[client_ip] = [
            req_time for req_time in self.requests[client_ip] if req_time > window_start
        ]

        if len(self.requests[client_ip]) >= self.requests_limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "error": {
                        "code": "RATE_LIMIT_EXCEEDED",
                        "message": f"Rate limit exceeded. Maximum {self.requests_limit} requests per minute.",
                        "details": {"retry_after_seconds": int(self.window_seconds - (now - self.requests[client_ip][0]))},
                    }
                },
            )

        self.requests[client_ip].append(now)


# Pre-configured rate limiters per SRS §7.3
auth_rate_limiter = InMemoryRateLimiter(requests_limit=10, window_seconds=60)
unauthenticated_rate_limiter = InMemoryRateLimiter(requests_limit=30, window_seconds=60)
