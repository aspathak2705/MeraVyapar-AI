from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.db.session import get_db
from app.schemas.common import APIResponse

router = APIRouter()


@router.get("/health", response_model=APIResponse)
def health_check(db: Session = Depends(get_db)):
    db_status = "healthy"
    try:
        db.execute(text("SELECT 1"))
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"

    return APIResponse(
        success=True,
        message="MeraVyapar AI Service Operational",
        data={
            "service": "meravyapar-api",
            "status": "healthy" if db_status == "healthy" else "degraded",
            "database": db_status,
            "version": "0.1.0"
        }
    )


@router.get("/health/providers", response_model=APIResponse)
def health_providers_check():
    """
    Check configuration readiness of external AI providers (Gnani, SerpApi, OpenRouter).
    Secrets are never exposed.
    """
    from app.core.config import settings

    gnani_configured = bool(settings.GNANI_API_KEY and len(settings.GNANI_API_KEY.strip()) > 5)
    serpapi_configured = bool(settings.SERPAPI_API_KEY and len(settings.SERPAPI_API_KEY.strip()) > 5)
    openrouter_configured = bool(settings.OPENROUTER_API_KEY and len(settings.OPENROUTER_API_KEY.strip()) > 5)

    all_configured = gnani_configured and serpapi_configured and openrouter_configured

    return APIResponse(
        success=True,
        message="Provider readiness verified",
        data={
            "gnani": {
                "configured": gnani_configured,
                "base_url": settings.GNANI_API_BASE_URL,
                "stt_model": settings.GNANI_STT_MODEL,
                "tts_model": settings.GNANI_TTS_MODEL,
            },
            "serpapi": {
                "configured": serpapi_configured,
                "base_url": settings.SERPAPI_BASE_URL,
            },
            "openrouter": {
                "configured": openrouter_configured,
                "model": settings.FINANCIAL_INTELLIGENCE_MODEL,
            },
            "all_providers_ready": all_configured
        }
    )
