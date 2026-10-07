import uuid
from datetime import datetime, timezone, timedelta
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session

from app.models.financial_event import FinancialEvent
from app.models.business_profile import BusinessProfile
from app.models.market_source import MarketSource
from app.models.market_event import MarketEvent
from app.models.merchant_market_relevance import MerchantMarketRelevance
from app.features.market_intelligence.fusion_models import (
    GroundedEvidenceBundle,
    InternalFinancialFact,
    ExternalMarketSignal,
    EvidenceFreshness,
)


class EvidenceBundleBuilder:
    """
    Constructs a deterministic GroundedEvidenceBundle for an event.
    Applies strict merchant scoping, relevance filtering, and temporal categorization.
    """

    def __init__(self, db: Session):
        self.db = db

    def _compute_freshness(self, published_at: Optional[datetime], now: datetime) -> EvidenceFreshness:
        if not published_at:
            return EvidenceFreshness.UNKNOWN
        if published_at.tzinfo is None:
            published_at = published_at.replace(tzinfo=timezone.utc)
        diff = now - published_at
        if diff <= timedelta(days=7):
            return EvidenceFreshness.FRESH
        elif diff <= timedelta(days=30):
            return EvidenceFreshness.RECENT
        else:
            return EvidenceFreshness.STALE

    def build_bundle(
        self,
        event: FinancialEvent,
        research_status: str = "SUCCESS",
        limit_evidence: int = 10
    ) -> GroundedEvidenceBundle:
        now = datetime.now(timezone.utc)

        # 1. Fetch merchant profile context
        profile = self.db.query(BusinessProfile).filter(BusinessProfile.merchant_id == event.merchant_id).first()
        city = profile.city if profile else None
        state = profile.state if profile else None
        b_type = profile.business_type if profile else None

        meta = event.metadata_info or {}
        category = meta.get("category")
        counterparty_name = meta.get("counterparty_name")
        time_window = meta.get("time_window") or "evaluated period"

        # 2. Extract deterministic Internal Financial Facts
        internal_facts: List[InternalFinancialFact] = []
        if meta.get("current_amount"):
            internal_facts.append(InternalFinancialFact(
                fact_id=f"fact_{event.id}_current_amount",
                label="Current Amount",
                value=f"₹{meta['current_amount']}",
                metric_name="current_amount",
                current_value=meta.get("current_amount"),
                comparison_value=meta.get("previous_amount"),
                percentage_change=meta.get("percentage_change"),
                period_end=now.isoformat()
            ))
        if meta.get("previous_amount"):
            internal_facts.append(InternalFinancialFact(
                fact_id=f"fact_{event.id}_previous_amount",
                label="Baseline Amount",
                value=f"₹{meta['previous_amount']}",
                metric_name="previous_amount",
                comparison_value=meta.get("previous_amount")
            ))
        if meta.get("percentage_change"):
            internal_facts.append(InternalFinancialFact(
                fact_id=f"fact_{event.id}_pct_change",
                label="Percentage Change",
                value=f"{meta['percentage_change']}%",
                metric_name="percentage_change",
                percentage_change=meta.get("percentage_change")
            ))

        # 3. Retrieve and filter relevant external evidence items
        relevances = self.db.query(MerchantMarketRelevance).filter(
            MerchantMarketRelevance.merchant_id == event.merchant_id,
            MerchantMarketRelevance.status == "ACTIVE"
        ).all()

        external_evidence: List[ExternalMarketSignal] = []
        event_id_str = str(event.id)

        for rel in relevances:
            mkt_ev = rel.market_event or self.db.query(MarketEvent).filter(MarketEvent.id == rel.market_event_id).first()
            if not mkt_ev:
                continue

            src = mkt_ev.source or self.db.query(MarketSource).filter(MarketSource.id == mkt_ev.source_id).first()
            if not src:
                continue

            src_meta = src.raw_metadata or {}
            # Strict relevance check: match originating event_id or category keywords
            rel_snapshot = rel.context_snapshot or {}
            is_matching_event = (rel_snapshot.get("originating_event_id") == event_id_str or src_meta.get("event_id") == event_id_str)

            # Keyword relevance check if not directly linked
            is_keyword_relevant = False
            if category and (category.lower() in src.title.lower() or category.lower() in (src_meta.get("query") or "").lower()):
                is_keyword_relevant = True

            if not (is_matching_event or is_keyword_relevant):
                continue

            freshness = self._compute_freshness(src.published_at, now)

            signal = ExternalMarketSignal(
                evidence_id=str(src.id),
                source_name=src.source_name,
                engine=src_meta.get("engine", "google"),
                title=src.title,
                snippet=mkt_ev.summary,
                source_url=src.source_url,
                published_at=src.published_at,
                retrieved_at=src.retrieved_at,
                freshness=freshness,
                price=src_meta.get("price"),
                rating=src_meta.get("rating"),
                location=src_meta.get("location"),
                metrics=src_meta.get("metrics", {})
            )
            external_evidence.append(signal)

            if len(external_evidence) >= limit_evidence:
                break

        return GroundedEvidenceBundle(
            bundle_id=str(uuid.uuid4()),
            merchant_id=event.merchant_id,
            financial_event_id=event.id,
            event_type=event.event_type.value,
            event_title=event.title,
            event_summary=event.summary,
            reference_period=time_window,
            comparison_period=None,
            category=category,
            counterparty_name=counterparty_name,
            operating_city=city,
            operating_state=state,
            business_type=b_type,
            research_status=research_status,
            internal_facts=internal_facts,
            external_evidence=external_evidence,
            created_at=now
        )
