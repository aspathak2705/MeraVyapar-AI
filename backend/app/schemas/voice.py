import base64
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field


class VoiceSynthesisRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000, description="Approved response text to synthesize")
    language_code: Optional[str] = Field("hi-IN", description="Target vernacular language code (e.g. hi-IN, mr-IN, en-IN)")
    voice: Optional[str] = Field("Nalini", description="Voice profile name compatible with Timbre v2.5")
    speed: Optional[float] = Field(1.0, ge=0.5, le=2.0, description="Pacing rate")


class VoiceInteractionResponse(BaseModel):
    success: bool
    transcript: str
    language_code: str
    intent: str
    response_text: str
    confirmation_required: bool = False
    candidate_action: Optional[Dict[str, Any]] = None
    audio_base64: Optional[str] = None
    tts_status: str
    metadata: Dict[str, Any] = Field(default_factory=dict)
    stt_metrics: Optional[Dict[str, Any]] = None


class VoiceProviderStatusResponse(BaseModel):
    stt_provider: str = "Gnani Prisma v2.5"
    tts_provider: str = "Gnani Timbre v2.5"
    stt_configured: bool
    tts_configured: bool
    default_language: str
    default_voice: str
    supported_languages: list[str]
