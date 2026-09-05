from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from typing import Optional, List, Dict, Any


class ForecastScenario(BaseModel):
    scenario_type: str  # BASELINE, HIGHER_OUTFLOW, LOWER_INFLOW, DELAYED_RECEIVABLE
    title: str
    description: str
    expected_incoming: Decimal
    expected_outgoing: Decimal
    net_cashflow: Decimal
    reason_codes: List[str] = []


class CashFlowForecastResponse(BaseModel):
    status: str  # SUFFICIENT | FORECAST_INSUFFICIENT_DATA | REFERENCE_DATASET_UNAVAILABLE
    data_source: str = "REAL_MERCHANT_HISTORY"
    message: Optional[str] = None
    observation_days: int = 0
    canonical_transaction_count: int = 0
    baseline_7d_incoming: Optional[Decimal] = None
    baseline_7d_outgoing: Optional[Decimal] = None
    baseline_7d_net: Optional[Decimal] = None
    scenarios: List[ForecastScenario] = []
    limitations: List[str] = []
    reference_context_used: bool = False
    reference_patterns: List[str] = []

    model_config = ConfigDict(from_attributes=True)
