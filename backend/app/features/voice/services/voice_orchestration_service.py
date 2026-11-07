import logging
from uuid import UUID
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session

from app.infrastructure.speech.gnani_stt_adapter import GnaniSTTAdapter
from app.infrastructure.speech.gnani_tts_adapter import GnaniTTSAdapter
from app.infrastructure.speech.gnani_models import GnaniConfigError, GnaniSpeechError
from app.features.voice.services.voice_action_router import VoiceActionRouter

logger = logging.getLogger(__name__)


class VoiceOrchestrationService:
    """
    Coordinates the voice pipeline:
    Audio Input -> Gnani STT (Prisma v2.5) -> Transcript -> VoiceActionRouter -> Response Text -> Gnani TTS (Timbre v2.5) -> Audio Output.
    Gracefully handles speech synthesis failures by returning the grounded text and action metadata cleanly.
    """

    def __init__(
        self,
        db: Session,
        stt_adapter: Optional[GnaniSTTAdapter] = None,
        tts_adapter: Optional[GnaniTTSAdapter] = None,
    ):
        self.db = db
        self.stt_adapter = stt_adapter or GnaniSTTAdapter()
        self.tts_adapter = tts_adapter or GnaniTTSAdapter()
        self.action_router = VoiceActionRouter(db)

    def process_voice_interaction(
        self,
        merchant_id: UUID,
        audio_bytes: bytes,
        filename: str = "voice_input.wav",
        language_code: Optional[str] = None,
        synthesize_voice: bool = True,
    ) -> Dict[str, Any]:
        """
        Processes voice audio from mobile merchant, executes deterministic financial intent,
        and produces natural spoken and textual responses.
        """
        # 1. Speech to Text via Gnani Prisma v2.5
        stt_result = self.stt_adapter.transcribe(
            audio_bytes=audio_bytes,
            filename=filename,
            language_code=language_code,
        )

        detected_lang = stt_result.language_code
        transcript = stt_result.transcript

        # 2. Route intent to existing MeraVyapar backend services
        routing_result = self.action_router.route_and_execute(
            merchant_id=merchant_id,
            transcript=transcript,
            language_code=detected_lang,
        )

        response_text = routing_result["response_text"]
        intent = routing_result["intent"]
        confirmation_required = routing_result["confirmation_required"]
        candidate_action = routing_result["candidate_action"]
        metadata = routing_result["metadata"]

        # 3. Text to Speech via Gnani Timbre v2.5 (Optional / Graceful Degradation)
        audio_response_bytes: Optional[bytes] = None
        tts_status = "SKIPPED"

        if synthesize_voice and response_text:
            try:
                tts_result = self.tts_adapter.synthesize(
                    text=response_text,
                    language_code=detected_lang,
                )
                audio_response_bytes = tts_result.audio_bytes
                tts_status = "SUCCESS"
            except (GnaniConfigError, GnaniSpeechError) as exc:
                logger.warning("Gnani TTS synthesis failed, degrading to text response: %s", str(exc))
                tts_status = f"FAILED: {exc.error_code if hasattr(exc, 'error_code') else str(exc)}"
            except Exception as exc:
                logger.error("Unexpected error in Gnani TTS synthesis: %s", str(exc))
                tts_status = "FAILED: UNEXPECTED"

        return {
            "success": True,
            "transcript": transcript,
            "language_code": detected_lang,
            "intent": intent,
            "response_text": response_text,
            "confirmation_required": confirmation_required,
            "candidate_action": candidate_action,
            "tts_status": tts_status,
            "audio_bytes": audio_response_bytes,
            "metadata": metadata,
            "stt_metrics": {
                "request_id": stt_result.request_id,
                "processing_time": stt_result.processing_time,
                "model": stt_result.model,
            }
        }
