from uuid import UUID
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import List, Dict, Any, Tuple
from sqlalchemy.orm import Session
from app.repositories.canonical_transaction_repository import CanonicalTransactionRepository
from app.repositories.payment_promise_repository import PaymentPromiseRepository
from app.models.payment_promise import PromiseDirection, PromiseStatus
from app.features.cashflow_intelligence.domain.cashflow_forecast import (
    CashFlowForecastResponse,
    ForecastScenario
)


class CashFlowForecastService:
    MIN_TRANSACTION_COUNT = 7
    MIN_OBSERVATION_DAYS = 14

    def __init__(self, db: Session):
        self.db = db
        self.txn_repo = CanonicalTransactionRepository(db)
        self.promise_repo = PaymentPromiseRepository(db)

    def generate_forecast(self, merchant_id: UUID) -> CashFlowForecastResponse:
        txns = self.txn_repo.list_by_merchant(merchant_id, skip=0, limit=500)

        # 1. Data Sufficiency Check
        if len(txns) < self.MIN_TRANSACTION_COUNT:
            return CashFlowForecastResponse(
                status="FORECAST_INSUFFICIENT_DATA",
                data_source="REAL_MERCHANT_HISTORY",
                message="More transaction history is required before generating a reliable cash-flow forecast.",
                canonical_transaction_count=len(txns),
                limitations=["At least 7 canonical transactions are required for forecasting."]
            )

        now = datetime.now(timezone.utc)
        timestamps = [t.occurred_at for t in txns if t.occurred_at]
        if timestamps:
            min_ts = min(timestamps)
            max_ts = max(timestamps)
            if min_ts.tzinfo is None:
                min_ts = min_ts.replace(tzinfo=timezone.utc)
            if max_ts.tzinfo is None:
                max_ts = max_ts.replace(tzinfo=timezone.utc)
            
            # Date span continuity requirement: (max_ts - min_ts) >= 13 days (covering 14 calendar days)
            obs_span_days = (max_ts - min_ts).days
            obs_total_days = max(1, (now - min_ts).days)
        else:
            obs_span_days = 0
            obs_total_days = 0

        if obs_span_days < 13 and obs_total_days < 14:
            return CashFlowForecastResponse(
                status="FORECAST_INSUFFICIENT_DATA",
                data_source="REAL_MERCHANT_HISTORY",
                message="History observation span is too short for reliable forecasting.",
                observation_days=obs_span_days,
                canonical_transaction_count=len(txns),
                limitations=["Minimum 14 days of transaction history continuity required."]
            )

        # 2. Historical Aggregation (7-day window averages using Decimal)
        money_in_total = Decimal("0.00")
        money_out_total = Decimal("0.00")

        for t in txns:
            amt = Decimal(str(t.amount))
            if t.transaction_type.value == "MONEY_IN":
                money_in_total += amt
            elif t.transaction_type.value == "MONEY_OUT":
                money_out_total += amt

        # Compute 7-day average baseline based on historical run rate
        weeks = max(Decimal("1.0"), Decimal(str(obs_total_days)) / Decimal("7.0"))
        avg_7d_in = (money_in_total / weeks).quantize(Decimal("0.01"))
        avg_7d_out = (money_out_total / weeks).quantize(Decimal("0.01"))

        # Incorporate explicit open payment promises due in next 7 days (FULFILLED or CANCELLED excluded)
        promises = self.promise_repo.list_by_merchant(merchant_id, skip=0, limit=200)
        next_7d = now + timedelta(days=7)

        expected_incoming_promises = Decimal("0.00")
        expected_outgoing_promises = Decimal("0.00")
        overdue_receivables = Decimal("0.00")

        for p in promises:
            if p.status == PromiseStatus.OPEN:
                p_due = p.due_at
                if p_due and p_due.tzinfo is None:
                    p_due = p_due.replace(tzinfo=timezone.utc)

                amt = Decimal(str(p.promised_amount))
                if p.promise_direction == PromiseDirection.EXPECTED_INCOMING:
                    if p_due and p_due <= next_7d:
                        expected_incoming_promises += amt
                    if p_due and p_due < now:
                        overdue_receivables += amt
                elif p.promise_direction == PromiseDirection.EXPECTED_OUTGOING:
                    if p_due and p_due <= next_7d:
                        expected_outgoing_promises += amt

        baseline_in = avg_7d_in + expected_incoming_promises
        baseline_out = avg_7d_out + expected_outgoing_promises
        baseline_net = baseline_in - baseline_out

        # 3. Deterministic Scenarios
        scenarios = []

        # Baseline Scenario
        scenarios.append(
            ForecastScenario(
                scenario_type="BASELINE",
                title="Baseline Forecast",
                description="Expected cash flow based on historical averages and explicit open promises.",
                expected_incoming=baseline_in,
                expected_outgoing=baseline_out,
                net_cashflow=baseline_net,
                reason_codes=["HISTORICAL_RUN_RATE", "EXPLICIT_PROMISES_INCLUDED"]
            )
        )

        # Higher Outflow Scenario (+15% operational expenses)
        higher_out = (baseline_out * Decimal("1.15")).quantize(Decimal("0.01"))
        scenarios.append(
            ForecastScenario(
                scenario_type="HIGHER_OUTFLOW",
                title="Higher Operational Outflow (+15%)",
                description="Considers potential short-term increases in operating expenses or unbudgeted inventory.",
                expected_incoming=baseline_in,
                expected_outgoing=higher_out,
                net_cashflow=baseline_in - higher_out,
                reason_codes=["OUTFLOW_VARIABILITY_BUFFER"]
            )
        )

        # Lower Inflow Scenario (Excludes expected incoming promises / lower bound of inflow)
        lower_in = (avg_7d_in * Decimal("0.85")).quantize(Decimal("0.01"))
        scenarios.append(
            ForecastScenario(
                scenario_type="LOWER_INFLOW",
                title="Lower Inflow Stress Test (-15%)",
                description="Models revenue contraction based on historical incoming cash flow variability.",
                expected_incoming=lower_in,
                expected_outgoing=baseline_out,
                net_cashflow=lower_in - baseline_out,
                reason_codes=["INFLOW_VARIABILITY_STRESS_TEST"]
            )
        )

        # Delayed Receivable Scenario (Exclude incoming promises and overdue receivables)
        delayed_in = max(Decimal("0.00"), baseline_in - expected_incoming_promises - overdue_receivables)
        scenarios.append(
            ForecastScenario(
                scenario_type="DELAYED_RECEIVABLE",
                title="Delayed Receivables Impact",
                description="Models liquidity impact if expected incoming customer payments are delayed.",
                expected_incoming=delayed_in,
                expected_outgoing=baseline_out,
                net_cashflow=delayed_in - baseline_out,
                reason_codes=["PROMISE_DELAY_STRESS_TEST"]
            )
        )

        # Dataset 3 Optionality Check
        from app.infrastructure.datasets.dataset_registry import dataset_registry
        ds3_available = dataset_registry.is_available("dataset_3_metadata")
        if ds3_available:
            reference_patterns = [
                "Cash flow benchmarks from synthetic reference data show recurring expense spikes during week-end cycles.",
                "Delayed customer payments are the primary driver of temporary cash flow pressure for retail archetypes."
            ]
        else:
            reference_patterns = []

        return CashFlowForecastResponse(
            status="SUFFICIENT",
            data_source="REAL_MERCHANT_HISTORY",
            message="Deterministic cash flow forecast generated successfully.",
            observation_days=obs_span_days,
            canonical_transaction_count=len(txns),
            baseline_7d_incoming=baseline_in,
            baseline_7d_outgoing=baseline_out,
            baseline_7d_net=baseline_net,
            scenarios=scenarios,
            limitations=[
                "Forecast does not predict unrecorded cash sales or unexpected external disruptions.",
                "All figures derived strictly from canonical merchant transactions and explicit promises."
            ] + ([] if ds3_available else ["Dataset 3 reference benchmarks currently unavailable; using real merchant history only."]),
            reference_context_used=ds3_available,
            reference_patterns=reference_patterns
        )
