import base64
import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status, Request
from app.gateway.installation_auth import verify_installation_request, AuthenticatedInstallation
from app.gateway.rate_limiter import rate_limiter
from app.infrastructure.speech.provider_factory import get_gnani_stt_adapter, get_gnani_tts_adapter
from app.infrastructure.speech.gnani_models import (
    GnaniConfigError,
    GnaniAudioValidationError,
    GnaniRateLimitError,
    GnaniTimeoutError,
    GnaniUnavailableError,
    GnaniSpeechError,
)
from app.schemas.voice import VoiceInteractionResponse
from app.features.financial_context.services.intent_router import DeterministicIntentRouter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/voice", tags=["Voice Interaction"])


@router.post("/interact", response_model=VoiceInteractionResponse)
async def process_voice_interaction_stateless(
    request: Request,
    audio_file: UploadFile = File(..., description="Audio file recorded by mobile merchant"),
    language_code: Optional[str] = Form(None, description="Optional target language (defaults to hi-IN)"),
    synthesize_audio: Optional[bool] = Form(True, description="Whether to generate spoken Timbre audio output"),
    installation: AuthenticatedInstallation = Depends(verify_installation_request),
):
    """
    Stateless Gnani voice interaction endpoint.
    Performs real STT (Gnani Prisma v2.5), determines intent deterministically,
    generates grounded explanation, and synthesizes spoken response (Gnani Timbre v2.5).
    Zero PostgreSQL persistence.
    """
    rate_limiter.check_rate_limit(installation.installation_id, "/api/v1/voice/interact")

    try:
        audio_bytes = await audio_file.read()
        filename = audio_file.filename or "recording.wav"

        # 1. Real Speech-to-Text via Gnani Prisma v2.5
        stt_adapter = get_gnani_stt_adapter()
        stt_result = stt_adapter.transcribe(
            audio_bytes=audio_bytes,
            filename=filename,
            language_code=language_code,
        )

        detected_lang = stt_result.language_code
        transcript = stt_result.transcript

        # 2. Deterministic Intent Classification
        intent_cat, is_allowed, scope_msg = DeterministicIntentRouter.classify_intent(transcript)

        response_text = ""
        candidate_action = None
        confirmation_required = False

        if not is_allowed:
            response_text = scope_msg or "Yeh sawaal MeraVyapar ke karyakshetra se baahar hai."
        elif intent_cat == "RECEIVABLE_STATUS":
            response_text = "Aapke baaki lenden aur graahakon ke bhugtaan receivables screen par darj hain."
        elif intent_cat == "PAYMENT_PROMISE_STATUS":
            response_text = "Aapke payment promises memory me darj hain."
        elif intent_cat == "COUNTERPARTY_CONTEXT":
            response_text = "Aapke vyaparik sambandh aur counterparties local passbook me surakshit hain."
        else:
            response_text = f"Maine aapki baat samjhi: '{transcript}'. Kripya zaroori financial action chunen."

        # 3. Text-to-Speech via Gnani Timbre v2.5
        audio_b64 = None
        tts_status = "SKIPPED"

        if synthesize_audio and response_text:
            try:
                tts_adapter = get_gnani_tts_adapter()
                tts_result = tts_adapter.synthesize(
                    text=response_text,
                    language_code=detected_lang,
                )
                if tts_result.audio_bytes:
                    audio_b64 = base64.b64encode(tts_result.audio_bytes).decode("utf-8")
                    tts_status = "SUCCESS"
            except Exception as tts_err:
                logger.warning("Stateless voice synthesis failed gracefully: %s", str(tts_err))
                tts_status = "FAILED_FALLBACK_TEXT"

        return VoiceInteractionResponse(
            success=True,
            transcript=transcript,
            language_code=detected_lang,
            intent=intent_cat,
            response_text=response_text,
            confirmation_required=confirmation_required,
            candidate_action=candidate_action,
            audio_base64=audio_b64,
            tts_status=tts_status,
            metadata={"stateless": True, "provider": "Gnani AI"},
            stt_metrics={"duration_seconds": stt_result.duration_seconds if hasattr(stt_result, "duration_seconds") else 0.0},
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
        logger.error("Unhandled error in stateless voice interaction: %s", str(exc), exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Voice interaction processing failed.")
