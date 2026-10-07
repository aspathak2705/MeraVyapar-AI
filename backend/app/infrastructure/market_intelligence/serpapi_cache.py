import hashlib
import json
import logging
from abc import ABC, abstractmethod
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any, Tuple

logger = logging.getLogger(__name__)


def build_deterministic_cache_key(engine: str, params: Dict[str, Any]) -> str:
    """
    Constructs a deterministic SHA-256 cache key based on the engine and normalized query parameters.
    Keys are sorted, string values trimmed and lowercased where appropriate, and API keys are strictly excluded.
    """
    # Filter out api_key or any credentials
    sanitized_params = {
        k: v for k, v in params.items()
        if k not in ("api_key", "key", "access_token", "secret")
    }

    normalized_pairs = []
    for k in sorted(sanitized_params.keys()):
        v = sanitized_params[k]
        if isinstance(v, str):
            v_norm = v.strip().lower()
        elif isinstance(v, (int, float, bool)):
            v_norm = str(v)
        elif isinstance(v, (list, tuple)):
            v_norm = ",".join(str(item).strip().lower() if isinstance(item, str) else str(item) for item in v)
        elif isinstance(v, dict):
            v_norm = json.dumps(v, sort_keys=True)
        else:
            v_norm = str(v).strip()
        normalized_pairs.append(f"{k.strip().lower()}={v_norm}")

    canonical_repr = f"engine={engine.strip().lower()}&" + "&".join(normalized_pairs)
    return hashlib.sha256(canonical_repr.encode("utf-8")).hexdigest()


class SerpApiCache(ABC):
    @abstractmethod
    def get(self, key: str) -> Optional[Tuple[Dict[str, Any], datetime]]:
        """Returns (data, expires_at) if present and not expired, else None."""
        pass

    @abstractmethod
    def set(self, key: str, data: Dict[str, Any], ttl_seconds: int = 86400) -> None:
        """Stores data with a TTL in seconds."""
        pass

    @abstractmethod
    def clear(self) -> None:
        """Clears all cached entries."""
        pass


class InMemorySerpApiCache(SerpApiCache):
    """
    In-memory deterministic TTL cache.
    Safe default when Redis is not available or for unit testing.
    """
    def __init__(self, default_ttl_seconds: int = 86400):
        self._cache: Dict[str, Tuple[Dict[str, Any], datetime]] = {}
        self.default_ttl_seconds = default_ttl_seconds

    def get(self, key: str) -> Optional[Tuple[Dict[str, Any], datetime]]:
        if key not in self._cache:
            return None
        data, expires_at = self._cache[key]
        now = datetime.now(timezone.utc)
        if now > expires_at:
            del self._cache[key]
            return None
        return data, expires_at

    def set(self, key: str, data: Dict[str, Any], ttl_seconds: Optional[int] = None) -> None:
        ttl = ttl_seconds if ttl_seconds is not None else self.default_ttl_seconds
        expires_at = datetime.now(timezone.utc) + timedelta(seconds=ttl)
        self._cache[key] = (data, expires_at)

    def clear(self) -> None:
        self._cache.clear()
