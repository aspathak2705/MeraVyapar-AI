from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional, List
from app.models.capture_source_setting import CaptureSourceType


class SharedTextCaptureRequest(BaseModel):
    text: str
    metadata: Optional[dict] = None


class NotificationCaptureRequest(BaseModel):
    provider_identifier: str
    title: Optional[str] = None
    text: str
    posted_at: Optional[datetime] = None
    external_event_id: Optional[str] = None


class SmsCaptureRequest(BaseModel):
    sender: str
    body: str
    received_at: Optional[datetime] = None
    external_event_id: Optional[str] = None


class CaptureSourceSettingResponse(BaseModel):
    id: UUID
    merchant_id: UUID
    source_type: CaptureSourceType
    provider_identifier: str
    enabled: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CaptureSourceSettingUpdateRequest(BaseModel):
    source_type: CaptureSourceType
    provider_identifier: str
    enabled: bool
