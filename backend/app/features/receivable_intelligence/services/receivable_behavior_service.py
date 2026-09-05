from uuid import UUID
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from app.repositories.payment_promise_repository import PaymentPromiseRepository
from app.repositories.counterparty_repository import CounterpartyRepository
from app.models.payment_promise import PromiseStatus, PromiseDirection
from app.features.receivable_intelligence.domain.receivable_behavior_pattern import CounterpartyBehaviorResponse


class ReceivableBehaviorService:
    MIN_OBSERVATION_COUNT = 2

    def __init__(self, db: Session):
        self.db = db
        self.promise_repo = PaymentPromiseRepository(db)
        self.cp_repo = CounterpartyRepository(db)

    def analyze_counterparty_behavior(self, merchant_id: UUID, counterparty_id: UUID) -> CounterpartyBehaviorResponse:
        cp = self.cp_repo.get_by_id(counterparty_id, merchant_id)
        cp_name = cp.display_name if cp else None

        # Fetch all historical promises for this counterparty
        promises = self.promise_repo.list_by_merchant(merchant_id, skip=0, limit=200)
        cp_promises = [
            p for p in promises
            if p.counterparty_id == counterparty_id and p.promise_direction == PromiseDirection.EXPECTED_INCOMING
        ]

        total_cnt = len(cp_promises)
        if total_cnt < self.MIN_OBSERVATION_COUNT:
            return CounterpartyBehaviorResponse(
                counterparty_id=counterparty_id,
                counterparty_name=cp_name,
                pattern_type="INSUFFICIENT_HISTORY",
                total_promises_observed=total_cnt,
                kept_count=0,
                broken_count=0,
                overdue_count=0,
                reason_codes=["INSUFFICIENT_PROMISE_HISTORY"],
                explanation="Not enough recorded payment history with this customer to establish a behavioral pattern."
            )

        now = datetime.now(timezone.utc)
        fulfilled_cnt = 0
        cancelled_cnt = 0
        overdue_cnt = 0

        for p in cp_promises:
            if p.status == PromiseStatus.FULFILLED:
                fulfilled_cnt += 1
            elif p.status == PromiseStatus.CANCELLED:
                cancelled_cnt += 1
            elif p.status == PromiseStatus.OPEN:
                p_due = p.due_at
                if p_due and p_due.tzinfo is None:
                    p_due = p_due.replace(tzinfo=timezone.utc)
                if p_due and p_due < now:
                    overdue_cnt += 1

        reason_codes = []

        # Explicit Deterministic Precedence Hierarchy:
        # 1. REPEATED_DELAY (overdue_cnt >= 2)
        # 2. PROMISE_BROKEN_PATTERN (cancelled_cnt >= 2)
        # 3. PARTIAL_PAYMENT_PATTERN (cancelled_cnt >= 1 and fulfilled_cnt >= 1)
        # 4. PROMISE_KEPT_PATTERN (fulfilled_cnt >= 2 and overdue_cnt == 0 and cancelled_cnt == 0)
        # 5. OCCASIONAL_DELAY (overdue_cnt == 1 or cancelled_cnt == 1)
        # 6. CONSISTENT_ON_TIME (fulfilled_cnt >= 2)
        # 7. INSUFFICIENT_HISTORY (default fallback)

        if overdue_cnt >= 2:
            pattern = "REPEATED_DELAY"
            reason_codes.append("REPEATED_OVERDUE_PROMISES")
            explanation = f"Recorded history shows repeated delays ({overdue_cnt} overdue)."
        elif cancelled_cnt >= 2:
            pattern = "PROMISE_BROKEN_PATTERN"
            reason_codes.append("MULTIPLE_BROKEN_PROMISES")
            explanation = f"Customer has repeatedly cancelled or broken payment promises ({cancelled_cnt} broken)."
        elif cancelled_cnt >= 1 and fulfilled_cnt >= 1:
            pattern = "PARTIAL_PAYMENT_PATTERN"
            reason_codes.append("PARTIAL_OR_MIXED_PAYMENTS")
            explanation = f"Customer exhibits partial payment or mixed fulfillment pattern ({fulfilled_cnt} kept, {cancelled_cnt} broken)."
        elif fulfilled_cnt >= 2 and overdue_cnt == 0 and cancelled_cnt == 0:
            pattern = "PROMISE_KEPT_PATTERN"
            reason_codes.append("ALL_PROMISES_KEPT")
            explanation = f"Customer has consistently kept all recorded payment promises on time ({fulfilled_cnt} kept)."
        elif overdue_cnt == 1 or cancelled_cnt == 1:
            pattern = "OCCASIONAL_DELAY"
            reason_codes.append("OCCASIONAL_PAYMENT_DELAY")
            explanation = "Customer generally pays on time with occasional minor delays."
        elif fulfilled_cnt >= 2:
            pattern = "CONSISTENT_ON_TIME"
            reason_codes.append("CONSISTENT_FULFILLMENT_HISTORY")
            explanation = f"Customer has consistently fulfilled recorded payment commitments ({fulfilled_cnt} fulfilled)."
        else:
            pattern = "INSUFFICIENT_HISTORY"
            reason_codes.append("INSUFFICIENT_PROMISE_HISTORY")
            explanation = "Not enough clear pattern indicators in recorded promise history."

        return CounterpartyBehaviorResponse(
            counterparty_id=counterparty_id,
            counterparty_name=cp_name,
            pattern_type=pattern,
            total_promises_observed=total_cnt,
            kept_count=fulfilled_cnt,
            broken_count=cancelled_cnt,
            overdue_count=overdue_cnt,
            reason_codes=reason_codes,
            explanation=explanation
        )
