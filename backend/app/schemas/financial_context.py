from pydantic import BaseModel, ConfigDict, Field
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from typing import Optional, List, Dict, Any


class InsightSourceReference(BaseModel):
    entity_type: str
    entity_id: str
    label: Optional[str] = None


class KeyFactItem(BaseModel):
    label: str
    value: str
    source_reference: Optional[str] = None


class GroundedInsightResponse(BaseModel):
    summary: str
    why_it_matters: str
    key_facts: List[KeyFactItem] = []
    suggested_actions: List[str] = []
    limitations: List[str] = []
    source_references: List[InsightSourceReference] = []
    is_ai_generated: bool = True
    status: str = "CURRENT"

    model_config = ConfigDict(from_attributes=True)


class FinancialContextPackage(BaseModel):
    context_version: str = "2.0"
    merchant_id: UUID
    focus_type: str  # EVENT, COUNTERPARTY, RECEIVABLE, GENERAL
    focus_entity_id: Optional[UUID] = None
    events: List[Dict[str, Any]] = []
    payment_promises: List[Dict[str, Any]] = []
    receivables: List[Dict[str, Any]] = []
    counterparties: List[Dict[str, Any]] = []
    computed_metrics: Dict[str, Any] = {}
    cashflow_context: Optional[Dict[str, Any]] = None
    receivable_behavior_context: Optional[Dict[str, Any]] = None
    reference_context: Optional[Dict[str, Any]] = None
    provenance_sources: List[InsightSourceReference] = []


class FinancialQueryRequest(BaseModel):
    question: str
    focus_entity_id: Optional[UUID] = None


class FinancialQueryResponse(BaseModel):
    intent_category: str
    is_allowed: bool
    scope_message: Optional[str] = None
    insight: Optional[GroundedInsightResponse] = None
