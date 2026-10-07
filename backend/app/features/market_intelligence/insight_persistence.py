import logging
from datetime import datetime, timezone
from typing import Optional, List
from uuid import UUID
from sqlalchemy.orm import Session

from app.models.financial_event import FinancialEvent
from app.models.generated_insight import GeneratedInsight
from app.features.market_intelligence.fusion_models import GroundedMerchantInsight, GroundedEvidenceBundle
from app.features.market_intelligence.bundle_builder import EvidenceBundleBuilder
from app.features.market_intelligence.fusion_engine import EvidenceFusionEngine

logger = logging.getLogger(__name__)


class GroundedInsightPersistenceService:
    """
    Persists validated GroundedMerchantInsight instances to `generated_insights`.
    Guarantees immutability and merchant isolation.
    """

    def __init__(self, db: Session, fusion_engine: Optional[EvidenceFusionEngine] = None):
        self.db = db
        self.bundle_builder = EvidenceBundleBuilder(db)
        self.fusion_engine = fusion_engine or EvidenceFusionEngine()

    def generate_and_save_insight_for_event(
        self,
        event: FinancialEvent,
        research_status: str = "SUCCESS"
    ) -> GeneratedInsight:
        # 1. Build Grounded Evidence Bundle
        bundle = self.bundle_builder.build_bundle(event, research_status=research_status)

        # 2. Run Grounded Fusion Engine (Nemotron with Grounding Guards)
        grounded_insight = self.fusion_engine.generate_insight(bundle)

        # 3. Store in generated_insights table (Immutable record per generation)
        now = datetime.now(timezone.utc)
        content_dict = grounded_insight.model_dump(mode="json")

        source_refs = [
            {"entity_type": "market_source", "entity_id": ref_id}
            for ref_id in grounded_insight.evidence_references
        ]
        # Include originating event in source references
        source_refs.append({"entity_type": "financial_event", "entity_id": str(event.id)})

        db_insight = GeneratedInsight(
            merchant_id=event.merchant_id,
            insight_type=grounded_insight.insight_type.value,
            focus_entity_type="financial_event",
            focus_entity_id=event.id,
            context_version="2.0",
            content=content_dict,
            source_references=source_refs,
            model_identifier=grounded_insight.model_metadata.get("model", "nvidia/nemotron-3-super-120b-a12b:free"),
            status="CURRENT",
            generated_at=now
        )
        self.db.add(db_insight)
        self.db.commit()
        self.db.refresh(db_insight)
        return db_insight

    def get_latest_insight_for_event(
        self,
        merchant_id: UUID,
        event_id: UUID
    ) -> Optional[GeneratedInsight]:
        """
        Retrieves the latest insight for an event, ensuring strict merchant isolation.
        """
        return self.db.query(GeneratedInsight).filter(
            GeneratedInsight.merchant_id == merchant_id,
            GeneratedInsight.focus_entity_id == event_id,
            GeneratedInsight.status == "CURRENT"
        ).order_by(GeneratedInsight.generated_at.desc()).first()
