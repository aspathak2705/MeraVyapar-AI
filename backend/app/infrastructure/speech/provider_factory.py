from typing import Optional
from app.infrastructure.speech.gnani_stt_adapter import GnaniSTTAdapter
from app.infrastructure.speech.gnani_tts_adapter import GnaniTTSAdapter


def get_gnani_stt_adapter(
    api_key: Optional[str] = None,
    base_url: Optional[str] = None,
    timeout_seconds: Optional[float] = None
) -> GnaniSTTAdapter:
    """Returns configured Gnani Prisma STT adapter instance."""
    return GnaniSTTAdapter(api_key=api_key, base_url=base_url, timeout_seconds=timeout_seconds)


def get_gnani_tts_adapter(
    api_key: Optional[str] = None,
    base_url: Optional[str] = None,
    timeout_seconds: Optional[float] = None
) -> GnaniTTSAdapter:
    """Returns configured Gnani Timbre TTS adapter instance."""
    return GnaniTTSAdapter(api_key=api_key, base_url=base_url, timeout_seconds=timeout_seconds)
