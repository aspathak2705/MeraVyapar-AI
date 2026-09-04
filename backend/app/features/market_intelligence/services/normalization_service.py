import hashlib
from datetime import datetime, timezone
from typing import Optional, Dict, Any, Tuple
from sqlalchemy.orm import Session
from app.repositories.market_intelligence_repository import MarketIntelligenceRepository
from app.models.market_source import MarketSource
from app.models.market_event import MarketEvent, MarketEventType
from app.schemas.market_intelligence import MarketIngestRequest


class MarketEventNormalizationService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = MarketIntelligenceRepository(db)

    def compute_content_hash(self, provider_name: str, source_url: str, title: str) -> str:
        raw_str = f"{provider_name.strip().lower()}|{source_url.strip().lower()}|{title.strip().lower()}"
        return hashlib.sha256(raw_str.encode("utf-8")).hexdigest()

    def ingest_market_event(self, req: MarketIngestRequest) -> Tuple[MarketEvent, bool]:
        content_hash = self.compute_content_hash(req.provider_name, req.source_url, req.title)
        existing_source = self.repo.get_source_by_hash(req.provider_name, content_hash)

        if existing_source:
            # Source already exists; retrieve associated event
            event = self.db.query(MarketEvent).filter(MarketEvent.source_id == existing_source.id).first()
            if event:
                return event, False

        # Create new source & event
        pub_at = req.published_at
        if pub_at and pub_at.tzinfo is None:
            pub_at = pub_at.replace(tzinfo=timezone.utc)

        source = self.repo.create_source(
            provider_name=req.provider_name,
            source_name=req.source_name,
            source_url=req.source_url,
            title=req.title,
            published_at=pub_at,
            content_hash=content_hash,
            raw_metadata=req.metadata_info
        )

        event = self.repo.create_event(
            source_id=source.id,
            event_type=req.event_type or MarketEventType.OTHER,
            title=req.title,
            summary=req.summary,
            occurred_at=pub_at,
            geography=req.geography or "IN",
            sector=req.sector,
            affected_domains=req.affected_domains or [],
            metadata_info=req.metadata_info
        )

        return event, True
