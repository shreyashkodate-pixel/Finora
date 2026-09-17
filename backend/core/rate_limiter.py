import time
from collections import defaultdict, deque
from typing import Dict, Deque
from fastapi import Request, HTTPException, status


class InMemoryRateLimiter:
    """
    In-memory sliding window rate limiter tracking request timestamps per client key.
    Zero external dependencies required.
    """

    def __init__(self, max_requests: int = 100, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._clients: Dict[str, Deque[float]] = defaultdict(deque)

    def is_allowed(self, client_key: str) -> bool:
        now = time.time()
        window_start = now - self.window_seconds
        timestamps = self._clients[client_key]

        # Purge timestamps older than the sliding window
        while timestamps and timestamps[0] < window_start:
            timestamps.popleft()

        if len(timestamps) >= self.max_requests:
            return False

        timestamps.append(now)
        return True

    def get_retry_after(self, client_key: str) -> int:
        timestamps = self._clients.get(client_key)
        if not timestamps:
            return 1
        oldest = timestamps[0]
        remaining = int(self.window_seconds - (time.time() - oldest))
        return max(1, remaining)


# Standard rate limiters
auth_rate_limiter = InMemoryRateLimiter(max_requests=60, window_seconds=60)
api_rate_limiter = InMemoryRateLimiter(max_requests=300, window_seconds=60)


async def check_api_rate_limit(request: Request):
    """
    FastAPI dependency to enforce sliding-window rate limits per client IP or Auth token.
    """
    client_ip = request.client.host if request.client else "unknown"
    auth_header = request.headers.get("Authorization", "")
    key = f"{client_ip}:{auth_header[:20]}"

    if not api_rate_limiter.is_allowed(key):
        retry_after = api_rate_limiter.get_retry_after(key)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "error": {
                    "code": "RATE_LIMIT_EXCEEDED",
                    "message": f"Too many requests. Please retry in {retry_after} seconds.",
                    "details": {"retry_after_seconds": retry_after},
                }
            },
            headers={"Retry-After": str(retry_after)},
        )
