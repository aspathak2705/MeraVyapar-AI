from fastapi import APIRouter
from app.core.config import settings
from app.schemas.common import APIResponse

router = APIRouter()


@router.get("/health", response_model=APIResponse)
def gateway_health():
    """
    Stateless health check probe for Google Cloud Run.
    Verifies process liveness and environment flags without connecting to PostgreSQL.
    """
    return APIResponse(
        success=True,
        message="MeraVyapar AI Stateless Gateway Operational",
        data={
            "service": "meravyapar-stateless-gateway",
            "environment": settings.ENVIRONMENT,
            "status": "healthy",
            "version": "0.1.0",
            "database_connected": False,
        }
    )
