from uuid import UUID
from datetime import datetime, timezone
from decimal import Decimal
from typing import Dict, Any
from sqlalchemy.orm import Session
from app.repositories.payment_promise_repository import PaymentPromiseRepository
from app.repositories.financial_event_repository import FinancialEventRepository
from app.repositories.counterparty_repository import CounterpartyRepository
from app.models.payment_promise import PromiseStatus, PromiseDirection
from app.models.financial_event import EventStatus


class FinancialFactsService:
    def __init__(self, db: Session):
        self.db = db
        self.promise_repo = PaymentPromiseRepository(db)
        self.event_repo = FinancialEventRepository(db)
        self.counterparty_repo = CounterpartyRepository(db)

    def compute_merchant_facts(self, merchant_id: UUID) -> Dict[str, Any]:
        now = datetime.now(timezone.utc)
        promises = self.promise_repo.list_by_merchant(merchant_id, skip=0, limit=200)

        open_promises = [p for p in promises if p.status == PromiseStatus.OPEN]
        overdue_promises = []
        open_receivables = []
        overdue_receivables = []

        total_receivable_amount = Decimal("0.00")
        total_overdue_receivable_amount = Decimal("0.00")

        for p in open_promises:
            due_at = p.due_at
            if due_at and due_at.tzinfo is None:
                due_at = due_at.replace(tzinfo=timezone.utc)

            is_overdue = due_at < now
            if is_overdue:
                overdue_promises.append(p)

            if p.promise_direction == PromiseDirection.EXPECTED_INCOMING:
                open_receivables.append(p)
                total_receivable_amount += p.promised_amount
                if is_overdue:
                    overdue_receivables.append(p)
                    total_overdue_receivable_amount += p.promised_amount

        active_events = self.event_repo.list_by_merchant(merchant_id, status=EventStatus.ACTIVE, skip=0, limit=100)
        counterparties = self.counterparty_repo.list_by_merchant(merchant_id, skip=0, limit=100)

        return {
            "open_promise_count": len(open_promises),
            "overdue_promise_count": len(overdue_promises),
            "open_receivable_count": len(open_receivables),
            "overdue_receivable_count": len(overdue_receivables),
            "total_open_receivable_amount": str(total_receivable_amount),
            "total_overdue_receivable_amount": str(total_overdue_receivable_amount),
            "active_event_count": len(active_events),
            "counterparty_count": len(counterparties),
            "calculated_at": now.isoformat()
        }
