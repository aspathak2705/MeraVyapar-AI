from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional


class MerchantBase(BaseModel):
    display_name: Optional[str] = None


class MerchantCreate(MerchantBase):
    pass


class MerchantUpdate(MerchantBase):
    status: Optional[str] = None


class MerchantResponse(MerchantBase):
    id: UUID
    auth_user_id: UUID
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
