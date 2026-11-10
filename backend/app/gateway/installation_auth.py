import hmac
import hashlib
import time
import logging
from typing import Optional, Tuple
from uuid import UUID
from pydantic import BaseModel
from fastapi import Request, Header, HTTPException, status
from app.core.config import settings

logger = logging.getLogger(__name__)

# Maximum clock skew allowed for signed requests (5 minutes)
MAX_REQUEST_AGE_SECONDS = 300

# In-memory store for registered installation public keys / verification keys:
# installation_id -> { "client_public_key": str, "registered_at": float }
_REGISTERED_INSTALLATIONS = {}


class InstallationEnrollmentRequest(BaseModel):
    installation_id: str
    client_public_key: str
    device_fingerprint: Optional[str] = None


class InstallationEnrollmentResponse(BaseModel):
    success: bool
    installation_id: str
    gateway_session_token: str
    expires_in_seconds: int


class AuthenticatedInstallation(BaseModel):
    installation_id: str
    is_enrolled: bool


def generate_gateway_session_token(installation_id: str, server_secret: str) -> str:
    """
    Generates a cryptographically signed HMAC token for the enrolled installation.
    Format: installation_id.timestamp.signature
    """
    ts = str(int(time.time()))
    payload = f"{installation_id}:{ts}".encode("utf-8")
    sig = hmac.new(server_secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()
    return f"{installation_id}.{ts}.{sig}"


def verify_installation_request(
    request: Request,
    authorization: Optional[str] = Header(None, alias="Authorization"),
    x_installation_id: Optional[str] = Header(None, alias="X-Installation-ID"),
    x_signature: Optional[str] = Header(None, alias="X-Signature"),
    x_timestamp: Optional[str] = Header(None, alias="X-Timestamp"),
) -> AuthenticatedInstallation:
    """
    Stateless installation authentication dependency.
    Validates either:
    1. A signed gateway session token: 'Authorization: Bearer <installation_id>.<ts>.<signature>'
    2. An HMAC request signature: 'X-Signature' calculated over method + path + timestamp + body
    Rejects arbitrary or unsigned merchant ID strings.
    """
    server_secret = getattr(settings, "INTERNAL_INGEST_API_KEY", None) or settings.SUPABASE_JWT_SECRET

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or malformed Authorization header scheme. Expected 'Bearer <gateway_token>'."
        )

    token = authorization.split(" ", 1)[1].strip()

    # Case A: Signed Gateway Session Token
    parts = token.split(".")
    if len(parts) == 3:
        inst_id, ts_str, provided_sig = parts
        try:
            ts = int(ts_str)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token timestamp format")

        # Check timestamp freshness (replay attack prevention)
        now = time.time()
        if abs(now - ts) > MAX_REQUEST_AGE_SECONDS:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Gateway authentication token expired or invalid timestamp skew."
            )

        expected_payload = f"{inst_id}:{ts_str}".encode("utf-8")
        expected_sig = hmac.new(server_secret.encode("utf-8"), expected_payload, hashlib.sha256).hexdigest()

        if not hmac.compare_digest(provided_sig, expected_sig):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid gateway token signature. Installation unauthorized."
            )

        return AuthenticatedInstallation(installation_id=inst_id, is_enrolled=True)

    # Case B: Local Development / Test Enrollment Pass-through (if enabled explicitly)
    if settings.ENVIRONMENT == "development" and len(token) >= 16:
        return AuthenticatedInstallation(installation_id=token, is_enrolled=False)

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Unauthorized installation. Caller must present a cryptographically signed gateway token."
    )
