from enum import Enum
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field


class GnaniLanguageCode(str, Enum):
    HINDI = "hi-IN"
    MARATHI = "mr-IN"
    ENGLISH = "en-IN"
    TAMIL = "ta-IN"
    TELUGU = "te-IN"
    KANNADA = "kn-IN"
    MALAYALAM = "ml-IN"
    GUJARATI = "gu-IN"
    PUNJABI = "pa-guru-IN"
    BENGALI = "bn-IN"
    URDU = "ur-IN"


class AudioContainer(str, Enum):
    WAV = "wav"
    MP3 = "mp3"
    OGG = "ogg"
    FLAC = "flac"
    AAC = "aac"
    M4A = "m4a"


class TranscriptionResult(BaseModel):
    success: bool
    transcript: str
    language_code: str
    model: str = "prisma-v2.5"
    request_id: Optional[str] = None
    processing_time: Optional[float] = None
    end_to_end_latency: Optional[float] = None
    raw_response: Dict[str, Any] = Field(default_factory=dict)


class SpeechSynthesisResult(BaseModel):
    success: bool
    audio_bytes: bytes
    content_type: str = "audio/wav"
    language_code: str
    voice: str = "Nalini"
    model: str = "timbre-v2.5"
    character_count: int = 0
    duration_estimate_seconds: Optional[float] = None


# Exception Hierarchy for Gnani Speech Stack
class GnaniSpeechError(Exception):
    """Base exception for all Gnani speech errors."""
    def __init__(self, message: str, status_code: int = 500, error_code: str = "GNANI_SPEECH_ERROR"):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.error_code = error_code


class GnaniConfigError(GnaniSpeechError):
    """Raised when Gnani API credentials or base settings are missing."""
    def __init__(self, message: str = "Gnani AI API key is not configured."):
        super().__init__(message, status_code=503, error_code="GNANI_NOT_CONFIGURED")


class GnaniAudioValidationError(GnaniSpeechError):
    """Raised when audio input fails validation (size, empty, format)."""
    def __init__(self, message: str):
        super().__init__(message, status_code=400, error_code="INVALID_AUDIO_INPUT")


class GnaniRateLimitError(GnaniSpeechError):
    """Raised when Gnani platform returns rate-limit error (HTTP 429)."""
    def __init__(self, message: str = "Gnani AI speech service rate limit exceeded."):
        super().__init__(message, status_code=429, error_code="GNANI_RATE_LIMITED")


class GnaniTimeoutError(GnaniSpeechError):
    """Raised when Gnani API request times out."""
    def __init__(self, message: str = "Gnani AI speech service timed out."):
        super().__init__(message, status_code=504, error_code="GNANI_TIMEOUT")


class GnaniUnavailableError(GnaniSpeechError):
    """Raised when Gnani API returns server error (HTTP 500/502/503)."""
    def __init__(self, message: str = "Gnani AI speech service is currently unavailable."):
        super().__init__(message, status_code=502, error_code="GNANI_UNAVAILABLE")
