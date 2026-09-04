from uuid import UUID
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.models.generated_insight import GeneratedInsight


class InsightStalenessService:
    def __init__(self, db: Session):
        self.db = db

    def invalidate_for_entity(self, merchant_id: UUID, entity_type: str, entity_id: UUID) -> int:
        insights = self.db.query(GeneratedInsight).filter(
            GeneratedInsight.merchant_id == merchant_id,
            GeneratedInsight.focus_entity_type == entity_type,
            GeneratedInsight.focus_entity_id == entity_id,
            GeneratedInsight.status == "CURRENT"
        ).all()

        for ins in insights:
            ins.status = "STALE"
            ins.stale_at = datetime.now(timezone.utc)

        if insights:
            self.db.commit()
        return len(insights)

    def on_payment_promise_changed(self, merchant_id: UUID, promise_id: UUID) -> int:
        # Invalidates insights focused on payment_promise, general merchant insights, or receivables
        count1 = self.invalidate_for_entity(merchant_id, "payment_promise", promise_id)
        count2 = self.invalidate_for_entity(merchant_id, "general", promise_id)
        return count1 + count2

    def on_event_changed(self, merchant_id: UUID, event_id: UUID) -> int:
        # Invalidates insights focused on financial_event
        return self.invalidate_for_entity(merchant_id, "financial_event", event_id)
