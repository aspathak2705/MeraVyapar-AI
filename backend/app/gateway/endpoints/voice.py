import io
import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status, Request
from fastapi.responses import StreamingResponse

from app.core.config import settings
from app.gateway.installation_auth import verify_installation_request, AuthenticatedInstallation
from app.gateway.rate_limiter import rate_limiter
from app.schemas.voice import (
    VoiceInteractionResponse,
    VoiceSynthesisRequest,
    VoiceProviderStatusResponse,
)
from app.infrastructure.speech.gnani_models import (
    GnaniConfigError,
    GnaniAudioValidationError,
    GnaniRateLimitError,
    GnaniTimeoutError,
    GnaniUnavailableError,
    GnaniLanguageCode,
)
from app.infrastructure.speech.provider_factory import get_gnani_stt_adapter, get_gnani_tts_adapter

logger = logging.getLogger(__name__)

# Max upload size: 10MB
MAX_AUDIO_BYTES = 10 * 1024 * 1024

router = APIRouter(prefix="/voice", tags=["Voice Intelligence"])


@router.get("/status", response_model=VoiceProviderStatusResponse)
def get_voice_provider_status(request: Request):
    """
    Stateless check returning Gnani AI speech provider readiness without exposing credentials.
    Zero database access.
    """
    client_ip = request.client.host if request.client else "unknown"
    rate_limiter.check_rate_limit(client_ip, "/api/v1/voice/status")

    is_configured = bool(settings.GNANI_API_KEY and settings.GNANI_API_KEY.strip())
    supported_langs = [l.value for l in GnaniLanguageCode]

    return VoiceProviderStatusResponse(
        stt_provider=f"Gnani Prisma ({settings.GNANI_STT_MODEL})",
        tts_provider=f"Gnani Timbre ({settings.GNANI_TTS_MODEL})",
        stt_configured=is_configured,
        tts_configured=is_configured,
        default_language=settings.GNANI_DEFAULT_LANGUAGE,
        default_voice=settings.GNANI_DEFAULT_VOICE,
        supported_languages=supported_langs,
    )


@router.post("/synthesize")
def synthesize_speech(
    payload: VoiceSynthesisRequest,
    request: Request,
    installation: AuthenticatedInstallation = Depends(verify_installation_request),
):
    """
    Synthesizes text into streaming PCM/WAV speech via Gnani Timbre v2.5.
    Completely stateless: does not query PostgreSQL or write to disk.
    Protected by per-installation rate limits and size limits.
    """
    rate_limiter.check_rate_limit(installation.installation_id, "/api/v1/voice/synthesize")

    if not payload.text or len(payload.text) > 1000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Synthesis text must be between 1 and 1000 characters."
        )

    try:
        tts_adapter = get_gnani_tts_adapter()
        tts_result = tts_adapter.synthesize(
            text=payload.text,
            language_code=payload.language or settings.GNANI_DEFAULT_LANGUAGE,
        )

        audio_bytes = tts_result.audio_bytes
        if not audio_bytes:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Empty audio buffer received from Gnani TTS provider."
            )

        return StreamingResponse(
            io.BytesIO(audio_bytes),
            media_type="audio/wav",
            headers={
                "Content-Disposition": "attachment; filename=synthesized_speech.wav",
                "X-Audio-Sample-Rate": "16000",
                "X-Audio-Format": "WAV_PCM_16BIT",
            }
        )
    except GnaniConfigError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=exc.message)
    except GnaniRateLimitError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=exc.message)
    except GnaniTimeoutError as exc:
        raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail=exc.message)
    except GnaniUnavailableError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=exc.message)
    except Exception as exc:
        logger.error("Unexpected error in gateway speech synthesis: %s", str(exc), exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Speech synthesis failed.")
