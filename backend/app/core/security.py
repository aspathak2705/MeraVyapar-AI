import jwt
from typing import Dict, Any, Optional
from app.core.config import settings
from app.core.exceptions import AuthenticationError


def verify_supabase_jwt(token: str) -> Dict[str, Any]:
    """
    Verifies Supabase JWT token and extracts token claims.
    Extracts 'sub' claim (Supabase auth user UUID).
    """
    try:
        # Decode token without verification if HS256 algorithm or HS256 with secret
        # In production, uses SUPABASE_JWT_SECRET
        payload = jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            options={"verify_aud": False}
        )
        sub = payload.get("sub")
        if not sub:
            raise AuthenticationError("Token missing required 'sub' claim")
        return payload
    except jwt.ExpiredSignatureError:
        raise AuthenticationError("Token has expired")
    except jwt.InvalidTokenError as e:
        raise AuthenticationError(f"Invalid authentication token: {str(e)}")
