from uuid import UUID
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
from sqlalchemy.orm import Session
from app.models.generated_insight import GeneratedInsight
from app.schemas.financial_context import GroundedInsightResponse


class InsightPersistenceService:
    def __init__(self, db: Session):
        self.db = db

    def save_insight(
        self,
        merchant_id: UUID,
        insight_type: str,
        insight: GroundedInsightResponse,
        focus_entity_type: Optional[str] = None,
        focus_entity_id: Optional[UUID] = None,
        model_identifier: str = "gemini-1.5-flash"
    ) -> GeneratedInsight:
        db_insight = GeneratedInsight(
            merchant_id=merchant_id,
            insight_type=insight_type,
            focus_entity_type=focus_entity_type,
            focus_entity_id=focus_entity_id,
            context_version="1.0",
            content=insight.model_dump(mode="json"),
            source_references=[s.model_dump(mode="json") for s in insight.source_references],
            model_identifier=model_identifier,
            status="CURRENT",
            generated_at=datetime.now(timezone.utc)
        )
        self.db.add(db_insight)
        self.db.commit()
        self.db.refresh(db_insight)
        return db_insight

    def get_latest_insight(
        self,
        merchant_id: UUID,
        insight_type: str,
        focus_entity_id: Optional[UUID] = None
    ) -> Optional[GeneratedInsight]:
        query = self.db.query(GeneratedInsight).filter(
            GeneratedInsight.merchant_id == merchant_id,
            GeneratedInsight.insight_type == insight_type,
            GeneratedInsight.status == "CURRENT"
        )
        if focus_entity_id:
            query = query.filter(GeneratedInsight.focus_entity_id == focus_entity_id)
        return query.order_by(GeneratedInsight.generated_at.desc()).first()

    def mark_entity_insights_stale(self, merchant_id: UUID, focus_entity_id: UUID) -> int:
        insights = self.db.query(GeneratedInsight).filter(
            GeneratedInsight.merchant_id == merchant_id,
            GeneratedInsight.focus_entity_id == focus_entity_id,
            GeneratedInsight.status == "CURRENT"
        ).all()

        for ins in insights:
            ins.status = "STALE"
            ins.stale_at = datetime.now(timezone.utc)

        self.db.commit()
        return len(insights)
