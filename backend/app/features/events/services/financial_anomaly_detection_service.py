from uuid import UUID
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from typing import List, Dict, Any, Optional, Tuple
from sqlalchemy.orm import Session

from app.models.canonical_transaction import CanonicalTransaction
from app.models.financial_event import FinancialEvent, EventType, EventSeverity, EventStatus
from app.models.business_profile import BusinessProfile
from app.repositories.canonical_transaction_repository import CanonicalTransactionRepository
from app.repositories.financial_event_repository import FinancialEventRepository
from app.repositories.counterparty_repository import CounterpartyRepository
from app.features.market_intelligence.research_models import ResearchIntent, ResearchPlan
from app.features.market_intelligence.research_planner import DeterministicResearchPlanner


class FinancialAnomalyDetectionService:
    """
    Deterministic rule engine that monitors canonical transactions and detects:
    - EXPENSE_SPIKE: Significant outflow jump in recent period compared to baseline.
    - REVENUE_DROP: Significant inflow contraction in recent period compared to baseline.
    - CATEGORY_COST_PRESSURE: Consecutive cost increase across comparable periods.

    All calculations strictly use Decimal and canonical transaction data.
    """

    EXPENSE_SPIKE_THRESHOLD_PERCENT = Decimal("25.0")  # +25% jump
    REVENUE_DROP_THRESHOLD_PERCENT = Decimal("20.0")    # -20% drop
    CATEGORY_PRESSURE_THRESHOLD_PERCENT = Decimal("15.0") # +15% persistent rise

    def __init__(self, db: Session):
        self.db = db
        self.txn_repo = CanonicalTransactionRepository(db)
        self.event_repo = FinancialEventRepository(db)
        self.cp_repo = CounterpartyRepository(db)

    def evaluate_merchant_anomalies(
        self,
        merchant_id: UUID,
        reference_time: Optional[datetime] = None,
        window_days: int = 14
    ) -> List[FinancialEvent]:
        """
        Evaluates anomalies for the merchant up to `reference_time` (defaults to utcnow).
        Ensures strict temporal correctness by only looking at transactions <= reference_time.
        """
        now = reference_time or datetime.now(timezone.utc)
        if now.tzinfo is None:
            now = now.replace(tzinfo=timezone.utc)

        all_txns = self.txn_repo.list_by_merchant(merchant_id, skip=0, limit=1000)
        # Filter transactions chronologically up to now
        txns = []
        for t in all_txns:
            if t.occurred_at:
                t_occ = t.occurred_at
                if t_occ.tzinfo is None:
                    t_occ = t_occ.replace(tzinfo=timezone.utc)
                if t_occ <= now:
                    txns.append(t)

        if len(txns) < 4:
            return []

        # Current period: [now - window_days, now]
        current_period_start = now - timedelta(days=window_days)
        # Previous period: [current_period_start - window_days, current_period_start]
        prev_period_start = current_period_start - timedelta(days=window_days)

        current_inflow = Decimal("0.00")
        current_outflow = Decimal("0.00")
        prev_inflow = Decimal("0.00")
        prev_outflow = Decimal("0.00")

        # Track category/counterparty breakdown for outflows
        current_outflow_by_entity: Dict[str, Decimal] = {}
        prev_outflow_by_entity: Dict[str, Decimal] = {}

        for t in txns:
            t_occ = t.occurred_at
            if t_occ.tzinfo is None:
                t_occ = t_occ.replace(tzinfo=timezone.utc)

            amt = Decimal(str(t.amount or 0))
            is_money_in = (t.transaction_type.value == "MONEY_IN")
            is_money_out = (t.transaction_type.value == "MONEY_OUT")

            entity_key = t.counterparty_name or "General Operations"

            if current_period_start < t_occ <= now:
                if is_money_in:
                    current_inflow += amt
                elif is_money_out:
                    current_outflow += amt
                    current_outflow_by_entity[entity_key] = current_outflow_by_entity.get(entity_key, Decimal("0.00")) + amt

            elif prev_period_start < t_occ <= current_period_start:
                if is_money_in:
                    prev_inflow += amt
                elif is_money_out:
                    prev_outflow += amt
                    prev_outflow_by_entity[entity_key] = prev_outflow_by_entity.get(entity_key, Decimal("0.00")) + amt

        detected_events: List[FinancialEvent] = []

        # 1. EXPENSE_SPIKE Evaluation
        if prev_outflow > Decimal("0.00") and current_outflow > prev_outflow:
            outflow_diff = current_outflow - prev_outflow
            outflow_pct_change = ((outflow_diff / prev_outflow) * Decimal("100.0")).quantize(Decimal("0.01"))

            if outflow_pct_change >= self.EXPENSE_SPIKE_THRESHOLD_PERCENT:
                period_str = f"{current_period_start.strftime('%Y%m%d')}_{now.strftime('%Y%m%d')}"
                dedup_key = f"expense_spike_{merchant_id}_{period_str}"

                ev, _ = self.event_repo.create_or_update_event(
                    merchant_id=merchant_id,
                    event_type=EventType.EXPENSE_SPIKE,
                    severity=EventSeverity.ATTENTION,
                    title="Expense Spike Detected",
                    summary=f"Expenses increased by {outflow_pct_change}% (₹{prev_outflow} → ₹{current_outflow})",
                    source_entity_type="canonical_transaction_aggregate",
                    source_entity_id=None,
                    deduplication_key=dedup_key,
                    occurred_at=now,
                    metadata_info={
                        "previous_amount": str(prev_outflow),
                        "current_amount": str(current_outflow),
                        "percentage_change": str(outflow_pct_change),
                        "period_days": window_days,
                        "time_window": f"{current_period_start.strftime('%d %b')} - {now.strftime('%d %b %Y')}",
                        "subject": "Operational Expenses"
                    }
                )
                detected_events.append(ev)

        # 2. REVENUE_DROP Evaluation
        if prev_inflow > Decimal("0.00") and current_inflow < prev_inflow:
            inflow_drop = prev_inflow - current_inflow
            inflow_pct_drop = ((inflow_drop / prev_inflow) * Decimal("100.0")).quantize(Decimal("0.01"))

            if inflow_pct_drop >= self.REVENUE_DROP_THRESHOLD_PERCENT:
                period_str = f"{current_period_start.strftime('%Y%m%d')}_{now.strftime('%Y%m%d')}"
                dedup_key = f"revenue_drop_{merchant_id}_{period_str}"

                ev, _ = self.event_repo.create_or_update_event(
                    merchant_id=merchant_id,
                    event_type=EventType.REVENUE_DROP,
                    severity=EventSeverity.ATTENTION,
                    title="Revenue Drop Detected",
                    summary=f"Revenue contracted by {inflow_pct_drop}% (₹{prev_inflow} → ₹{current_inflow})",
                    source_entity_type="canonical_transaction_aggregate",
                    source_entity_id=None,
                    deduplication_key=dedup_key,
                    occurred_at=now,
                    metadata_info={
                        "previous_amount": str(prev_inflow),
                        "current_amount": str(current_inflow),
                        "percentage_change": f"-{inflow_pct_drop}",
                        "period_days": window_days,
                        "time_window": f"{current_period_start.strftime('%d %b')} - {now.strftime('%d %b %Y')}",
                        "subject": "Store Inflows"
                    }
                )
                detected_events.append(ev)

        # 3. CATEGORY / COUNTERPARTY COST PRESSURE Evaluation
        for entity_name, curr_amt in current_outflow_by_entity.items():
            prev_amt = prev_outflow_by_entity.get(entity_name, Decimal("0.00"))
            if prev_amt > Decimal("0.00") and curr_amt > prev_amt:
                cost_diff = curr_amt - prev_amt
                cost_pct = ((cost_diff / prev_amt) * Decimal("100.0")).quantize(Decimal("0.01"))

                if cost_pct >= self.CATEGORY_PRESSURE_THRESHOLD_PERCENT:
                    period_str = f"{current_period_start.strftime('%Y%m%d')}_{now.strftime('%Y%m%d')}"
                    slug = entity_name.lower().replace(" ", "_")[:30]
                    dedup_key = f"cost_pressure_{merchant_id}_{slug}_{period_str}"

                    ev, _ = self.event_repo.create_or_update_event(
                        merchant_id=merchant_id,
                        event_type=EventType.CATEGORY_COST_PRESSURE,
                        severity=EventSeverity.INFO,
                        title=f"Cost Pressure: {entity_name}",
                        summary=f"Expenses for {entity_name} rose {cost_pct}% (₹{prev_amt} → ₹{curr_amt})",
                        source_entity_type="counterparty_aggregate",
                        source_entity_id=None,
                        deduplication_key=dedup_key,
                        occurred_at=now,
                        metadata_info={
                            "category": entity_name,
                            "counterparty_name": entity_name,
                            "previous_amount": str(prev_amt),
                            "current_amount": str(curr_amt),
                            "percentage_change": str(cost_pct),
                            "time_window": f"{current_period_start.strftime('%d %b')} - {now.strftime('%d %b %Y')}",
                            "subject": entity_name
                        }
                    )
                    detected_events.append(ev)

        return detected_events

    def build_research_intent_for_event(self, event: FinancialEvent) -> Optional[ResearchIntent]:
        """
        Constructs a minimal, privacy-safe ResearchIntent for an eligible financial event.
        Extracts geographic context strictly from the merchant's BusinessProfile without fabrication.
        """
        # Look up merchant profile for safe business metadata
        profile = self.db.query(BusinessProfile).filter(BusinessProfile.merchant_id == event.merchant_id).first()
        city = profile.city if profile else None
        state = profile.state if profile else None
        b_type = profile.business_type if profile else None

        meta = event.metadata_info or {}
        subject = meta.get("subject") or meta.get("category") or event.title
        time_window = meta.get("time_window") or "recent 14 days"
        reason = f"Deterministic anomaly: {event.summary}"

        return ResearchIntent(
            event_id=event.id,
            merchant_id=event.merchant_id,
            event_type=event.event_type.value,
            subject=subject,
            category=meta.get("category"),
            counterparty_name=meta.get("counterparty_name"),
            operating_city=city,
            operating_state=state,
            business_type=b_type,
            time_window=time_window,
            reason=reason
        )

    def generate_research_plan_for_event(self, event: FinancialEvent) -> Optional[ResearchPlan]:
        intent = self.build_research_intent_for_event(event)
        if not intent:
            return None
        return DeterministicResearchPlanner.plan(intent)
