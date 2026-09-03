from pydantic import BaseModel
from typing import Optional, Any, Dict


class APIResponse(BaseModel):
    success: bool = True
    message: str = "Operation successful"
    data: Optional[Any] = None
    error: Optional[Dict[str, Any]] = None
