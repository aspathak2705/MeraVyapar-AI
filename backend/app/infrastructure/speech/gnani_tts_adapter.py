import logging
from typing import Optional, Union, Dict, Any
import httpx

from app.core.config import settings
from app.infrastructure.speech.gnani_models import (
    GnaniLanguageCode,
    SpeechSynthesisResult,
    GnaniConfigError,
    GnaniSpeechError,
    GnaniRateLimitError,
    GnaniTimeoutError,
    GnaniUnavailableError,
)

logger = logging.getLogger(__name__)

# Constants
MAX_TEXT_CHARACTERS = 2000  # Safe boundary for single synthesis turn


class GnaniTTSAdapter:
    """
    Production adapter for Gnani Timbre v2.5 Text-to-Speech (TTS) API.
    Interacts with Gnani Vachana platform: POST /api/v1/tts/inference
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

    def synthesize(
        self,
        text: str,
        voice: Optional[str] = None,
        language_code: Optional[Union[GnaniLanguageCode, str]] = None,
        speed: float = 1.0,
        sample_rate: int = 16000,
    ) -> SpeechSynthesisResult:
        """
        Synthesizes approved text into natural speech audio bytes using Timbre v2.5.
        """
        self._validate_configuration()

        clean_text = (text or "").strip()
        if not clean_text:
            raise GnaniSpeechError("Synthesis text cannot be empty.", status_code=400, error_code="EMPTY_TEXT")

        if len(clean_text) > MAX_TEXT_CHARACTERS:
            clean_text = clean_text[:MAX_TEXT_CHARACTERS]

        lang_str = language_code.value if isinstance(language_code, GnaniLanguageCode) else (language_code or settings.GNANI_DEFAULT_LANGUAGE)
        voice_str = voice or settings.GNANI_DEFAULT_VOICE

        endpoint = f"{self.base_url}/api/v1/tts/inference"
        headers = {
            "X-API-Key-ID": self.api_key,
            "Content-Type": "application/json",
        }

        payload: Dict[str, Any] = {
            "text": clean_text,
            "model": settings.GNANI_TTS_MODEL,
            "voice": voice_str,
            "language": lang_str,
            "speed": max(0.5, min(speed, 2.0)),
            "audio_config": {
                "encoding": "linear_pcm",
                "container": "wav",
                "num_channels": 1,
                "sample_rate": sample_rate,
                "sample_width": 2,
            }
        }

        try:
            with httpx.Client(timeout=self.timeout_seconds) as client:
                response = client.post(endpoint, headers=headers, json=payload)

            if response.status_code == 200:
                audio_bytes = response.content
                return SpeechSynthesisResult(
                    success=True,
                    audio_bytes=audio_bytes,
                    content_type="audio/wav",
                    language_code=lang_str,
                    voice=voice_str,
                    model=settings.GNANI_TTS_MODEL,
                    character_count=len(clean_text),
                    duration_estimate_seconds=round(len(clean_text) / 15.0, 2),
                )
            elif response.status_code == 401:
                logger.error("Gnani TTS authentication failed: Invalid API key")
                raise GnaniConfigError("Gnani AI API authentication failed: Invalid or expired API key.")
            elif response.status_code == 429:
                logger.warning("Gnani TTS rate limited")
                raise GnaniRateLimitError("Gnani TTS service rate limit reached. Please retry in a few moments.")
            elif response.status_code in (500, 502, 503, 504):
                logger.error("Gnani TTS server error: HTTP %d", response.status_code)
                raise GnaniUnavailableError(f"Gnani TTS service returned server error ({response.status_code}).")
            else:
                logger.error("Gnani TTS unexpected status %d: %s", response.status_code, response.text)
                raise GnaniSpeechError(f"Gnani TTS returned unexpected status {response.status_code}: {response.text}")

        except httpx.TimeoutException as exc:
            logger.warning("Gnani TTS request timed out: %s", str(exc))
            raise GnaniTimeoutError(f"Gnani TTS request timed out after {self.timeout_seconds}s.") from exc
        except (httpx.ConnectError, httpx.NetworkError) as exc:
            logger.error("Gnani TTS connection failed: %s", str(exc))
            raise GnaniUnavailableError("Unable to connect to Gnani AI speech platform.") from exc
