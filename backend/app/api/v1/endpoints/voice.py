import base64
import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status, Response
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.models.merchant import Merchant
from app.core.config import settings
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
    GnaniSpeechError,
    GnaniLanguageCode,
)
from app.infrastructure.speech.provider_factory import get_gnani_stt_adapter, get_gnani_tts_adapter
from app.features.voice.services.voice_orchestration_service import VoiceOrchestrationService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/voice", tags=["Voice Intelligence"])


@router.get("/status", response_model=VoiceProviderStatusResponse)
def get_voice_provider_status():
    """
    Returns Gnani AI speech provider readiness and configuration status without exposing credentials.
    """
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


@router.post("/interact", response_model=VoiceInteractionResponse)
async def process_voice_interaction(
    audio_file: UploadFile = File(..., description="Audio file recorded by mobile merchant (WAV/MP3/AAC/FLAC)"),
    language_code: Optional[str] = Form(None, description="Optional target language (defaults to hi-IN)"),
    synthesize_audio: Optional[bool] = Form(True, description="Whether to generate spoken Timbre audio output"),
    current_merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db),
):
    """
    Receives spoken audio from an authenticated merchant, transcribes via Gnani Prisma v2.5,
    routes intent to existing financial services, generates a grounded response, and synthesizes
    spoken vernacular audio via Gnani Timbre v2.5.
    """
    try:
        audio_bytes = await audio_file.read()
        filename = audio_file.filename or "recording.wav"

        service = VoiceOrchestrationService(
            db=db,
            stt_adapter=get_gnani_stt_adapter(),
            tts_adapter=get_gnani_tts_adapter(),
        )

        result = service.process_voice_interaction(
            merchant_id=current_merchant.id,
            audio_bytes=audio_bytes,
            filename=filename,
            language_code=language_code,
            synthesize_voice=bool(synthesize_audio),
        )

        audio_b64 = None
        if result.get("audio_bytes"):
            audio_b64 = base64.b64encode(result["audio_bytes"]).decode("utf-8")

        return VoiceInteractionResponse(
            success=result["success"],
            transcript=result["transcript"],
            language_code=result["language_code"],
            intent=result["intent"],
            response_text=result["response_text"],
            confirmation_required=result["confirmation_required"],
            candidate_action=result["candidate_action"],
            audio_base64=audio_b64,
            tts_status=result["tts_status"],
            metadata=result["metadata"],
            stt_metrics=result.get("stt_metrics"),
        )

    except GnaniConfigError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=exc.message)
    except GnaniAudioValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message)
    except GnaniRateLimitError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=exc.message)
    except GnaniTimeoutError as exc:
        raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail=exc.message)
    except GnaniUnavailableError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=exc.message)
    except GnaniSpeechError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message)
    except Exception as exc:
        logger.error("Unhandled voice interaction exception: %s", str(exc), exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="An error occurred processing voice interaction.")


@router.post("/synthesize")
def synthesize_speech(
    payload: VoiceSynthesisRequest,
    current_merchant: Merchant = Depends(get_current_merchant),
):
    """
    Synthesizes approved text into binary audio via Gnani Timbre v2.5 and streams back WAV audio.
    """
    try:
        adapter = get_gnani_tts_adapter()
        res = adapter.synthesize(
            text=payload.text,
            language_code=payload.language_code,
            voice=payload.voice,
            speed=payload.speed or 1.0,
        )
        return Response(content=res.audio_bytes, media_type="audio/wav")

    except GnaniConfigError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=exc.message)
    except GnaniRateLimitError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=exc.message)
    except GnaniTimeoutError as exc:
        raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail=exc.message)
    except GnaniUnavailableError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=exc.message)
    except GnaniSpeechError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message)
    except Exception as exc:
        logger.error("Unhandled speech synthesis exception: %s", str(exc), exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to synthesize speech.")
