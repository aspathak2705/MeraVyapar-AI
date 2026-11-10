import time
import logging
from collections import defaultdict
from typing import Dict, Tuple
from fastapi import Request, HTTPException, status
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger(__name__)


class GatewayRateLimiter:
    """
    In-memory rate limiter per installation/client IP.
    Applies sliding window rate limiting without requiring external Redis.
    Note: In-memory counters reset on server restart and are local to each container instance.
    """
    def __init__(self):
        # key -> list of timestamps
        self._history: Dict[str, list] = defaultdict(list)
        # Default limits: (max_requests, window_seconds)
        self._limits: Dict[str, Tuple[int, int]] = {
            "/api/v1/voice/interact": (15, 60),      # 15 voice interactions per minute
            "/api/v1/voice/synthesize": (30, 60),    # 30 TTS syntheses per minute
            "/api/v1/financial-intelligence/query": (20, 60), # 20 Nemotron queries per minute
            "/api/v1/financial-events/explain": (20, 60),
            "/api/v1/market-intelligence": (40, 60), # 40 market queries per minute
            "default": (100, 60)                     # 100 general requests per minute
        }

    def check_rate_limit(self, identifier: str, path: str):
        now = time.time()
        # Determine applicable limit
        matched_limit = self._limits["default"]
        for p, lim in self._limits.items():
            if p != "default" and p in path:
                matched_limit = lim
                break

        max_reqs, window = matched_limit
        key = f"{identifier}:{path}"
        history = self._history[key]

        # Prune timestamps outside window
        cutoff = now - window
        valid_history = [t for t in history if t > cutoff]
        self._history[key] = valid_history

        if len(valid_history) >= max_reqs:
            retry_after = int(window - (now - valid_history[0]))
            logger.warning(
                "Rate limit exceeded for %s on path %s. Limit: %d/%ds.",
                identifier, path, max_reqs, window
            )
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded. Maximum {max_reqs} requests per {window}s. Retry after {max_after(retry_after, 1)}s.",
                headers={"Retry-After": str(max(retry_after, 1))}
            )

        self._history[key].append(now)


def max_after(val: int, minimum: int) -> int:
    return val if val > minimum else minimum


rate_limiter = GatewayRateLimiter()
