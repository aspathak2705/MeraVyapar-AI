from pydantic import BaseModel, ConfigDict
from typing import Optional, List, Dict, Any


class MerchantArchetype(BaseModel):
    business_type: str
    business_size: str
    seasonality_pattern: str
    cash_flow_volatility: str
    receivable_behavior_profile: str
    supplier_payment_behavior: str


class ArchetypeMatchResult(BaseModel):
    matched_archetype: Optional[MerchantArchetype] = None
    matched_attributes: List[str] = []
    unmatched_attributes: List[str] = []
    reference_patterns: List[str] = []
    status: str = "AVAILABLE"  # AVAILABLE | REFERENCE_DATASET_UNAVAILABLE

    model_config = ConfigDict(from_attributes=True)
