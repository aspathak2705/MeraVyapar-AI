import logging
from typing import Optional, Dict, Any, Union
import httpx

from app.core.config import settings
from app.infrastructure.speech.gnani_models import (
    GnaniLanguageCode,
    AudioContainer,
    TranscriptionResult,
    GnaniConfigError,
    GnaniAudioValidationError,
    GnaniRateLimitError,
    GnaniTimeoutError,
    GnaniUnavailableError,
    GnaniSpeechError,
)

logger = logging.getLogger(__name__)

# Constants
MAX_AUDIO_BYTES = 10 * 1024 * 1024  # 10 MB limit for short audio


class GnaniSTTAdapter:
    """
    Production adapter for Gnani Prisma v2.5 Speech-to-Text (STT) API.
    Interacts with Gnani Vachana platform: POST /stt/v3
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        timeout_seconds: Optional[float] = None,
    ):
        self.api_key = api_key or settings.GNANI_API_KEY
        self.base_url = (base_url or settings.GNANI_API_BASE_URL).rstrip("/")
        self.timeout_seconds = timeout_seconds or settings.GNANI_TIMEOUT_SECONDS

    def _validate_configuration(self) -> None:
        if not self.api_key or not self.api_key.strip():
            raise GnaniConfigError("Gnani AI API key (GNANI_API_KEY) is not configured.")

    def _validate_audio(self, audio_bytes: bytes, filename: str) -> str:
        if not audio_bytes or len(audio_bytes) == 0:
            raise GnaniAudioValidationError("Audio payload is empty.")

        if len(audio_bytes) > MAX_AUDIO_BYTES:
            raise GnaniAudioValidationError(f"Audio payload exceeds maximum limit of {MAX_AUDIO_BYTES // (1024*1024)} MB.")

        ext = filename.lower().split(".")[-1] if "." in filename else ""
        allowed = {c.value for c in AudioContainer}
        if ext not in allowed:
            # Default to wav if unrecognized but binary present
            ext = "wav"
        return f"audio/{ext}"

    def transcribe(
        self,
        audio_bytes: bytes,
        filename: str = "recording.wav",
        language_code: Optional[Union[GnaniLanguageCode, str]] = None,
        format_mode: str = "transcribe",
        itn_native_numerals: bool = False,
    ) -> TranscriptionResult:
        """
        Submits audio bytes to Gnani Prisma v2.5 for transcription.
        """
        self._validate_configuration()
        content_type = self._validate_audio(audio_bytes, filename)

        lang_str = language_code.value if isinstance(language_code, GnaniLanguageCode) else (language_code or settings.GNANI_DEFAULT_LANGUAGE)

        endpoint = f"{self.base_url}/stt/v3"
        headers = {
            "X-API-Key-ID": self.api_key,
        }

        files = {
            "audio_file": (filename, audio_bytes, content_type)
        }
        data = {
            "language_code": lang_str,
            "format": format_mode,
            "itn_native_numerals": "true" if itn_native_numerals else "false",
            "model": settings.GNANI_STT_MODEL,
        }

        try:
            with httpx.Client(timeout=self.timeout_seconds) as client:
                response = client.post(endpoint, headers=headers, files=files, data=data)

            if response.status_code == 200:
                raw = response.json()
                transcript = raw.get("transcript", "").strip()
                return TranscriptionResult(
                    success=True,
                    transcript=transcript,
                    language_code=lang_str,
                    model=raw.get("model", settings.GNANI_STT_MODEL),
                    request_id=raw.get("request_id"),
                    processing_time=raw.get("processing_time"),
                    end_to_end_latency=raw.get("end_to_end_latency"),
                    raw_response=raw,
                )
            elif response.status_code == 401:
                logger.error("Gnani STT authentication failed: Invalid API key")
                raise GnaniConfigError("Gnani AI API authentication failed: Invalid or expired API key.")
            elif response.status_code == 429:
                logger.warning("Gnani STT rate limited")
                raise GnaniRateLimitError("Gnani STT service rate limit reached. Please retry in a few moments.")
            elif response.status_code in (500, 502, 503, 504):
                logger.error("Gnani STT server error: HTTP %d", response.status_code)
                raise GnaniUnavailableError(f"Gnani STT service returned server error ({response.status_code}).")
            else:
                logger.error("Gnani STT unexpected status %d: %s", response.status_code, response.text)
                raise GnaniSpeechError(f"Gnani STT returned unexpected status {response.status_code}: {response.text}")

        except httpx.TimeoutException as exc:
            logger.warning("Gnani STT request timed out: %s", str(exc))
            raise GnaniTimeoutError(f"Gnani STT request timed out after {self.timeout_seconds}s.") from exc
        except (httpx.ConnectError, httpx.NetworkError) as exc:
            logger.error("Gnani STT connection failed: %s", str(exc))
            raise GnaniUnavailableError("Unable to connect to Gnani AI speech platform.") from exc
