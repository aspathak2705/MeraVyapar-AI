from uuid import UUID
from fastapi import Depends, Header
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.core.security import verify_supabase_jwt
from app.core.exceptions import AuthenticationError, NotFoundError
from app.repositories.merchant_repository import MerchantRepository
from app.models.merchant import Merchant


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
