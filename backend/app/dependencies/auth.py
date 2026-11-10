import hmac
from typing import Optional
from uuid import UUID
from fastapi import Depends, Header
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.core.config import settings
from app.core.security import verify_supabase_jwt
from app.core.exceptions import AuthenticationError, NotFoundError
from app.repositories.merchant_repository import MerchantRepository
from app.models.merchant import Merchant


def verify_internal_ingest_key(
    x_ingest_key: Optional[str] = Header(None, alias="X-Internal-Ingest-Key"),
    authorization: Optional[str] = Header(None, alias="Authorization"),
) -> bool:
    """
    Verifies that the caller provides the required internal ingestion key.
    Rejects unauthorized access to administrative market event ingestion.
    """
    key_to_check = x_ingest_key
    if not key_to_check and authorization and authorization.startswith("Bearer "):
        key_to_check = authorization.split(" ", 1)[1]

    expected_key = settings.INTERNAL_INGEST_API_KEY
    if not expected_key:
        if settings.ALLOW_INSECURE_INTERNAL_INGEST:
            return True
        raise AuthenticationError("Internal market ingestion is disabled: INTERNAL_INGEST_API_KEY not configured")

    if not key_to_check or not hmac.compare_digest(key_to_check, expected_key):
        raise AuthenticationError("Invalid or missing internal ingestion authorization key")

    return True


def get_current_user_id(authorization: str = Header(..., alias="Authorization")) -> UUID:
    """
    Extracts authenticated user UUID (sub) from Supabase Bearer JWT token.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise AuthenticationError("Missing or invalid Authorization header scheme")

    token = authorization.split(" ", 1)[1]
    claims = verify_supabase_jwt(token)
    sub = claims.get("sub")
    if not sub:
        raise AuthenticationError("Token missing user subject ('sub') claim")

    try:
        return UUID(sub)
    except ValueError:
        raise AuthenticationError("Invalid UUID format in user claim")


def get_current_merchant(
    auth_user_id: UUID = Depends(get_current_user_id),
    db: Session = Depends(get_db)
) -> Merchant:
    """
    Resolves merchant identity strictly from the authenticated user context.
    Never trusts client-supplied merchant_id parameters.
    """
    merchant_repo = MerchantRepository(db)
    merchant = merchant_repo.get_by_auth_user_id(auth_user_id)
    if not merchant:
        raise NotFoundError("Merchant profile not found for authenticated user. Initialize merchant first.")
    return merchant
