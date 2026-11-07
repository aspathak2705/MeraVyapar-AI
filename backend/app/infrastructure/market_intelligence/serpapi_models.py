from enum import Enum
from typing import Optional, Dict, Any, List
from datetime import datetime
from pydantic import BaseModel, Field


class SerpApiEngine(str, Enum):
    SEARCH = "google"
    SHOPPING = "google_shopping"
    NEWS = "google_news"


class ExternalEvidenceSource(BaseModel):
    provider_name: str = "SerpApi"
    engine: str
    source_name: str
    source_url: str
    title: str
    published_at: Optional[datetime] = None
    retrieved_at: datetime
    content_hash: str
    external_identifier: Optional[str] = None
    raw_metadata: Dict[str, Any] = Field(default_factory=dict)


class ExternalEvidenceItem(BaseModel):
    title: str
    snippet: Optional[str] = None
    url: Optional[str] = None
    source_name: Optional[str] = None
    published_date: Optional[str] = None
    price: Optional[str] = None
    rating: Optional[float] = None
    reviews: Optional[int] = None
    location: Optional[str] = None
    metrics: Dict[str, Any] = Field(default_factory=dict)
    raw_payload: Dict[str, Any] = Field(default_factory=dict)


class SerpApiResult(BaseModel):
    engine: str
    query: str
    raw_response: Dict[str, Any]
    retrieved_at: datetime
    cached: bool = False
    cache_expires_at: Optional[datetime] = None
    normalized_items: List[ExternalEvidenceItem] = Field(default_factory=list)


class SerpApiError(Exception):
    """Base exception for SerpApi client errors."""
    pass


class SerpApiConfigError(SerpApiError):
    """Raised when SerpApi is misconfigured or API key is missing when required."""
    pass


class SerpApiRequestValidationError(SerpApiError):
    """Raised when input parameters fail bounds/type validation."""
    pass


class SerpApiRateLimitError(SerpApiError):
    """Raised when SerpApi rate limit or quota is exceeded."""
    pass


class SerpApiTimeoutError(SerpApiError):
    """Raised when SerpApi request times out."""
    pass


class SerpApiUnavailableError(SerpApiError):
    """Raised when SerpApi service returns an HTTP error or is unreachable."""
    pass
