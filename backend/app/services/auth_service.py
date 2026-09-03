from typing import Dict, Any
from app.core.security import verify_supabase_jwt


class AuthService:
    @staticmethod
    def verify_token(token: str) -> Dict[str, Any]:
        return verify_supabase_jwt(token)
