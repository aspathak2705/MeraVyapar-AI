from uuid import UUID
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from app.models.market_source import MarketSource
from app.models.market_event import MarketEvent, MarketEventType
from app.models.merchant_market_relevance import MerchantMarketRelevance, MarketRelevanceStatus


class MarketIntelligenceRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_source_by_hash(self, provider_name: str, content_hash: str) -> Optional[MarketSource]:
        return self.db.query(MarketSource).filter(
            MarketSource.provider_name == provider_name,
            MarketSource.content_hash == content_hash
        ).first()

    def create_source(
        self,
        provider_name: str,
        source_name: str,
        source_url: str,
        title: str,
        published_at: datetime,
        content_hash: str,
        external_identifier: Optional[str] = None,
        raw_metadata: Optional[Dict[str, Any]] = None
    ) -> MarketSource:
        source = MarketSource(
            provider_name=provider_name,
            source_name=source_name,
            source_url=source_url,
            title=title,
            published_at=published_at,
            retrieved_at=datetime.now(timezone.utc),
            content_hash=content_hash,
            external_identifier=external_identifier,
            raw_metadata=raw_metadata or {}
        )
        self.db.add(source)
        self.db.commit()
        self.db.refresh(source)
        return source

    def create_event(
        self,
        source_id: UUID,
        event_type: MarketEventType,
        title: str,
        summary: str,
        occurred_at: datetime,
        geography: Optional[str] = "IN",
        sector: Optional[str] = None,
        affected_domains: Optional[List[str]] = None,
        reason_codes: Optional[List[str]] = None,
        metadata_info: Optional[Dict[str, Any]] = None
    ) -> MarketEvent:
        source = self.db.query(MarketSource).filter(MarketSource.id == source_id).first()
        event = MarketEvent(
            source_id=source_id,
            event_type=event_type,
            title=title,
            summary=summary,
            occurred_at=occurred_at,
            detected_at=datetime.now(timezone.utc),
            geography=geography,
            sector=sector,
            affected_domains=affected_domains or [],
            reason_codes=reason_codes or [],
            metadata_info=metadata_info or {}
        )
        if source:
            event.source = source

        self.db.add(event)
        self.db.commit()
        self.db.refresh(event)
        return event

    def list_market_events(self, skip: int = 0, limit: int = 50) -> List[MarketEvent]:
        events = self.db.query(MarketEvent).order_by(MarketEvent.occurred_at.desc()).offset(skip).limit(limit).all()
        for e in events:
            if not e.source:
                e.source = self.db.query(MarketSource).filter(MarketSource.id == e.source_id).first()
        return events

    def get_event_by_id(self, event_id: UUID) -> Optional[MarketEvent]:
        e = self.db.query(MarketEvent).filter(MarketEvent.id == event_id).first()
        if e and not e.source:
            e.source = self.db.query(MarketSource).filter(MarketSource.id == e.source_id).first()
        return e

    def get_relevance(self, merchant_id: UUID, market_event_id: UUID) -> Optional[MerchantMarketRelevance]:
        r = self.db.query(MerchantMarketRelevance).filter(
            MerchantMarketRelevance.merchant_id == merchant_id,
            MerchantMarketRelevance.market_event_id == market_event_id
        ).first()
        if r and not r.market_event:
            r.market_event = self.get_event_by_id(market_event_id)
        return r

    def create_or_update_relevance(
        self,
        merchant_id: UUID,
        market_event_id: UUID,
        relevance_status: MarketRelevanceStatus,
        reason_codes: List[str],
        context_snapshot: Dict[str, Any]
    ) -> MerchantMarketRelevance:
        existing = self.get_relevance(merchant_id, market_event_id)
        now = datetime.now(timezone.utc)
        if existing:
            existing.relevance_status = relevance_status
            existing.reason_codes = reason_codes
            existing.context_snapshot = context_snapshot
            existing.updated_at = now
            self.db.commit()
            self.db.refresh(existing)
            return existing

        event = self.get_event_by_id(market_event_id)
        relevance = MerchantMarketRelevance(
            merchant_id=merchant_id,
            market_event_id=market_event_id,
            relevance_status=relevance_status,
            reason_codes=reason_codes,
            context_snapshot=context_snapshot,
            detected_at=now,
            status="ACTIVE"
        )
        if event:
            relevance.market_event = event

        self.db.add(relevance)
        self.db.commit()
        self.db.refresh(relevance)
        return relevance

    def list_relevant_for_merchant(self, merchant_id: UUID, skip: int = 0, limit: int = 50) -> List[MerchantMarketRelevance]:
        records = self.db.query(MerchantMarketRelevance).filter(
            MerchantMarketRelevance.merchant_id == merchant_id,
            MerchantMarketRelevance.status == "ACTIVE"
        ).all()

        filtered = [
            r for r in records
            if r.relevance_status in (
                MarketRelevanceStatus.POTENTIALLY_RELEVANT,
                MarketRelevanceStatus.REQUIRES_MORE_CONTEXT
            )
        ]

        for r in filtered:
            if not r.market_event:
                r.market_event = self.get_event_by_id(r.market_event_id)

        filtered.sort(key=lambda x: x.detected_at, reverse=True)
        return filtered[skip:skip + limit]
