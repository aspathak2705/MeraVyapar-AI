from pydantic import BaseModel, ConfigDict, Field
from uuid import UUID
from datetime import datetime
from typing import Optional, List, Dict, Any
from app.models.communication_action import ActionType, CommunicationChannel, ActionStatus


class CommunicationAuditEventResponse(BaseModel):
    id: UUID
    communication_action_id: UUID
    event_type: str
    previous_status: Optional[str] = None
    new_status: str
    actor_type: str
    metadata_info: Dict[str, Any] = {}
    occurred_at: datetime

    model_config = ConfigDict(from_attributes=True)



class CommunicationActionResponse(BaseModel):
    id: UUID
    merchant_id: UUID
    action_type: ActionType
    channel: CommunicationChannel
    status: ActionStatus
    draft_content: str
    final_content: Optional[str] = None
    recipient_info: Optional[Dict[str, Any]] = None
    target_entity_id: Optional[UUID] = None
    target_entity_type: Optional[str] = None
    promise_id: Optional[UUID] = None
    idempotency_key: str
    provider_message_id: Optional[str] = None
    error_code: Optional[str] = None
    error_message: Optional[str] = None
    confirmed_at: Optional[datetime] = None
    sent_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CommunicationActionDraftRequest(BaseModel):
    promise_id: UUID
    channel: Optional[str] = "whatsapp"


class CommunicationActionUpdateRequest(BaseModel):
    final_content: str
    recipient_info: Optional[Dict[str, Any]] = None


class CommunicationActionConfirmRequest(BaseModel):
    pass
