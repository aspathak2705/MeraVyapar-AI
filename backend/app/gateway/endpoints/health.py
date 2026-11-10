from fastapi import APIRouter
from app.core.config import settings
from app.schemas.common import APIResponse

router = APIRouter()


@router.get("/health", response_model=APIResponse)
def gateway_health():
    """
    Stateless health check probe for Google Cloud Run.
    Verifies process liveness, environment flags, and AI provider configuration
    without connecting to PostgreSQL or creating database pools.
    """
    voice_configured = bool(settings.GNANI_API_KEY and settings.GNANI_API_KEY.strip())
    market_configured = bool(settings.SERPAPI_API_KEY and settings.SERPAPI_API_KEY.strip())
    nemotron_configured = bool(settings.OPENROUTER_API_KEY and settings.OPENROUTER_API_KEY.strip())

    return APIResponse(
        success=True,
        message="MeraVyapar AI Stateless Gateway Operational",
        data={
            "service": "meravyapar-stateless-gateway",
            "environment": settings.ENVIRONMENT,
            "status": "healthy",
            "version": "0.1.0",
            "database_connected": False,  # Strictly decoupled from PostgreSQL
            "providers": {
                "gnani_speech": voice_configured,
                "serpapi_market": market_configured,
                "nemotron_reasoning": nemotron_configured,
            }
        }
    )
