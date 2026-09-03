from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from typing import Optional, List, Dict, Any
from app.models.financial_counterparty import (
    CounterpartyRelationshipType,
    CounterpartyStatus,
    MerchantRelationshipStatus,
    FinancialEventType
)


class CounterpartyAliasResponse(BaseModel):
    id: UUID
    alias_value: str
    normalized_alias: str
    source: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class MerchantRelationshipProfileResponse(BaseModel):
    relationship_type: CounterpartyRelationshipType
    relationship_status: MerchantRelationshipStatus
    first_seen_at: datetime
    last_seen_at: datetime
    transaction_count: int

    model_config = ConfigDict(from_attributes=True)


class FinancialRelationshipEventResponse(BaseModel):
    id: UUID
    event_type: FinancialEventType
    canonical_transaction_id: Optional[UUID] = None
    payment_promise_id: Optional[UUID] = None
    occurred_at: datetime
    metadata_info: Dict[str, Any] = {}

    model_config = ConfigDict(from_attributes=True)


class FinancialCounterpartyResponse(BaseModel):
    id: UUID
    merchant_id: UUID
    display_name: str
    normalized_name: str
    relationship_type: CounterpartyRelationshipType
    status: CounterpartyStatus
    created_at: datetime
    updated_at: datetime
    aliases: List[CounterpartyAliasResponse] = []
    relationship_profile: Optional[MerchantRelationshipProfileResponse] = None

    model_config = ConfigDict(from_attributes=True)


class CounterpartyUpdateRequest(BaseModel):
    display_name: Optional[str] = None
    relationship_type: Optional[CounterpartyRelationshipType] = None
    status: Optional[CounterpartyStatus] = None
