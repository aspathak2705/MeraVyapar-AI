from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from app.core.config import settings
from app.gateway.installation_auth import (
    InstallationEnrollmentRequest,
    InstallationEnrollmentResponse,
    generate_gateway_session_token
)

router = APIRouter(prefix="/auth", tags=["Installation Enrollment"])


@router.post("/enroll", response_model=InstallationEnrollmentResponse)
def enroll_installation(payload: InstallationEnrollmentRequest):
    """
    Public enrollment route for genuine mobile installations.
    Returns a short-lived, signed gateway token bound to the installation.
    """
    if len(payload.installation_id) < 8 or len(payload.client_public_key) < 16:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid installation credentials provided."
        )

    server_secret = getattr(settings, "INTERNAL_INGEST_API_KEY", None) or settings.SUPABASE_JWT_SECRET
    token = generate_gateway_session_token(payload.installation_id, server_secret)

    return InstallationEnrollmentResponse(
        success=True,
        installation_id=payload.installation_id,
        gateway_session_token=token,
        expires_in_seconds=300
    )
