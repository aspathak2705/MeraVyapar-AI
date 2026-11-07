import logging
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
import httpx

from app.core.config import settings
from app.infrastructure.market_intelligence.serpapi_models import (
    SerpApiEngine,
    SerpApiResult,
    SerpApiError,
    SerpApiConfigError,
    SerpApiRequestValidationError,
    SerpApiRateLimitError,
    SerpApiTimeoutError,
    SerpApiUnavailableError,
)
from app.infrastructure.market_intelligence.serpapi_cache import (
    SerpApiCache,
    InMemorySerpApiCache,
    build_deterministic_cache_key,
)
from app.infrastructure.market_intelligence.serpapi_normalizer import SerpApiNormalizer

logger = logging.getLogger(__name__)


class SerpApiClient:
    """
    Production client for SerpApi external market intelligence foundation.
    Provides locked access to exactly 3 Google engines:
    - Google Search
    - Google Shopping
    - Google News

    Features:
    - Strict server-side isolation (API key never leaked or returned in response)
    - Deterministic 24-hour cache layer (query normalization & param canonicalization)
    - Request validation & bounds checking
    - Explicit exception handling (RateLimit, Timeout, Unavailable, Validation)
    - Output normalization to standard external evidence structures
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        cache: Optional[SerpApiCache] = None,
        timeout_seconds: Optional[float] = None,
        cache_ttl_seconds: Optional[int] = None,
    ):
        self.api_key = api_key if api_key is not None else getattr(settings, "SERPAPI_API_KEY", None)
        self.base_url = (base_url or getattr(settings, "SERPAPI_BASE_URL", "https://serpapi.com/search")).rstrip("/")
        self.timeout_seconds = timeout_seconds or getattr(settings, "SERPAPI_TIMEOUT_SECONDS", 10.0)
        self.cache_ttl_seconds = cache_ttl_seconds or getattr(settings, "SERPAPI_CACHE_TTL_SECONDS", 86400)
        self.cache = cache or InMemorySerpApiCache(default_ttl_seconds=self.cache_ttl_seconds)

    @property
    def is_configured(self) -> bool:
        return bool(self.api_key and self.api_key.strip())

    def _validate_common_query(self, query: str) -> str:
        if not query or not query.strip():
            raise SerpApiRequestValidationError("Query cannot be empty or whitespace only.")
        q = query.strip()
        if len(q) > 500:
            raise SerpApiRequestValidationError("Query exceeds maximum allowed length of 500 characters.")
        return q

    def _execute_query(
        self,
        engine: SerpApiEngine,
        raw_params: Dict[str, Any],
        bypass_cache: bool = False,
    ) -> SerpApiResult:
        if not self.is_configured:
            raise SerpApiConfigError("SerpApi API key is not configured.")

        # Compute deterministic cache key (credentials stripped inside build_deterministic_cache_key)
        cache_key = build_deterministic_cache_key(engine.value, raw_params)

        if not bypass_cache and self.cache:
            cached_entry = self.cache.get(cache_key)
            if cached_entry:
                cached_data, expires_at = cached_entry
                items = SerpApiNormalizer.normalize(engine, cached_data, raw_params.get("q", ""))
                return SerpApiResult(
                    engine=engine.value,
                    query=raw_params.get("q", ""),
                    raw_response=cached_data,
                    retrieved_at=datetime.now(timezone.utc),
                    cached=True,
                    cache_expires_at=expires_at,
                    normalized_items=items,
                )

        # Build outbound request params
        request_params = {**raw_params, "engine": engine.value, "api_key": self.api_key}

        try:
            with httpx.Client(timeout=self.timeout_seconds) as client:
                response = client.get(self.base_url, params=request_params)
        except httpx.TimeoutException as exc:
            logger.error("SerpApi request timed out for engine %s: %s", engine.value, str(exc))
            raise SerpApiTimeoutError(f"SerpApi request timed out after {self.timeout_seconds}s") from exc
        except httpx.RequestError as exc:
            logger.error("SerpApi connection failure for engine %s: %s", engine.value, str(exc))
            raise SerpApiUnavailableError(f"SerpApi connection error: {str(exc)}") from exc

        if response.status_code == 429:
            raise SerpApiRateLimitError("SerpApi rate limit or quota exceeded (HTTP 429).")
        elif response.status_code == 400:
            raise SerpApiRequestValidationError(f"SerpApi invalid request parameter (HTTP 400): {response.text}")
        elif response.status_code == 401 or response.status_code == 403:
            raise SerpApiConfigError(f"SerpApi authentication error (HTTP {response.status_code}). Check SERPAPI_API_KEY.")
        elif response.status_code >= 500:
            raise SerpApiUnavailableError(f"SerpApi server error (HTTP {response.status_code}): {response.text}")
        elif response.status_code != 200:
            raise SerpApiUnavailableError(f"SerpApi unexpected HTTP {response.status_code}: {response.text}")

        try:
            data = response.json()
        except Exception as exc:
            raise SerpApiUnavailableError("SerpApi returned non-JSON response payload.") from exc

        # Check for SerpApi-level error in payload
        if "error" in data and isinstance(data["error"], str):
            err_msg = data["error"]
            if "quota" in err_msg.lower() or "searches" in err_msg.lower():
                raise SerpApiRateLimitError(f"SerpApi quota reached: {err_msg}")
            raise SerpApiUnavailableError(f"SerpApi error: {err_msg}")

        # Store in cache
        if self.cache:
            self.cache.set(cache_key, data, ttl_seconds=self.cache_ttl_seconds)

        now = datetime.now(timezone.utc)
        items = SerpApiNormalizer.normalize(engine, data, raw_params.get("q", ""))

        return SerpApiResult(
            engine=engine.value,
            query=raw_params.get("q", ""),
            raw_response=data,
            retrieved_at=now,
            cached=False,
            cache_expires_at=None,
            normalized_items=items,
        )

    # 1. Google Search API
    def search(
        self,
        query: str,
        location: Optional[str] = "India",
        hl: Optional[str] = "en",
        gl: Optional[str] = "in",
        num: int = 10,
        bypass_cache: bool = False,
    ) -> SerpApiResult:
        q = self._validate_common_query(query)
        if not (1 <= num <= 100):
            raise SerpApiRequestValidationError("num must be between 1 and 100.")

        params = {"q": q, "hl": hl or "en", "gl": gl or "in", "num": num}
        if location:
            params["location"] = location

        return self._execute_query(SerpApiEngine.SEARCH, params, bypass_cache=bypass_cache)

    # 2. Google Shopping API
    def shopping(
        self,
        query: str,
        location: Optional[str] = "India",
        hl: Optional[str] = "en",
        gl: Optional[str] = "in",
        direct_link: bool = True,
        bypass_cache: bool = False,
    ) -> SerpApiResult:
        q = self._validate_common_query(query)
        params = {
            "q": q,
            "hl": hl or "en",
            "gl": gl or "in",
            "direct_link": "true" if direct_link else "false",
        }
        if location:
            params["location"] = location
        return self._execute_query(SerpApiEngine.SHOPPING, params, bypass_cache=bypass_cache)

    # 4. Google News API
    def news(
        self,
        query: str,
        gl: Optional[str] = "in",
        hl: Optional[str] = "en",
        bypass_cache: bool = False,
    ) -> SerpApiResult:
        q = self._validate_common_query(query)
        params = {
            "q": q,
            "gl": gl or "in",
            "hl": hl or "en",
        }
        return self._execute_query(SerpApiEngine.NEWS, params, bypass_cache=bypass_cache)
