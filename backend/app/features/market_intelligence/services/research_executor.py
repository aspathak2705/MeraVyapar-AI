import logging
import hashlib
from datetime import datetime, timezone
from typing import List, Optional, Tuple, Dict, Any
from uuid import UUID
from sqlalchemy.orm import Session

from app.models.market_source import MarketSource
from app.models.market_event import MarketEvent, MarketEventType
from app.models.merchant_market_relevance import MerchantMarketRelevance, MarketRelevanceStatus
from app.repositories.market_intelligence_repository import MarketIntelligenceRepository
from app.infrastructure.market_intelligence.serpapi_models import (
    SerpApiEngine,
    SerpApiResult,
    ExternalEvidenceItem,
    SerpApiError,
    SerpApiConfigError,
    SerpApiRateLimitError,
    SerpApiTimeoutError,
    SerpApiUnavailableError,
    SerpApiRequestValidationError,
)
from app.infrastructure.market_intelligence.serpapi_client import SerpApiClient
from app.features.market_intelligence.research_models import ResearchPlan
from app.features.market_intelligence.execution_models import (
    ResearchExecutionResult,
    ExecutionStatus,
    EngineExecutionDetail,
)

logger = logging.getLogger(__name__)


def map_engine_to_market_event_type(engine: SerpApiEngine, financial_event_type: str) -> MarketEventType:
    """
    Deterministically maps research engine and originating financial event type
    to neutral contextual MarketEventType domain values. Never asserts causality.
    """
    if engine == SerpApiEngine.SHOPPING:
        return MarketEventType.COMMODITY_PRICE_MOVEMENT
    elif engine == SerpApiEngine.NEWS:
        return MarketEventType.ECONOMIC_EVENT
    elif engine == SerpApiEngine.SEARCH:
        if "EXPENSE" in financial_event_type or "COST" in financial_event_type:
            return MarketEventType.COMMODITY_PRICE_MOVEMENT
        return MarketEventType.ECONOMIC_EVENT
    return MarketEventType.OTHER


class ResearchExecutor:
    """
    Controlled application service executing approved ResearchPlan instances.
    Guarantees:
    - Enforces maximum tool fan-out <= 2.
    - Executes only planned engines without expanding plan.
    - Captures engine timeouts/rate-limits cleanly (partial failure support).
    - Validates normalized external evidence items.
    - Deduplicates items via content hashing (deterministic append-only).
    - Preserves provenance (query, engine, url, timestamps, merchant, event_id).
    - Stores compact metadata only (no raw payload bloat).
    - Reuses existing MarketSource, MarketEvent, and MerchantMarketRelevance models.
    - HARD INVARIANT: Never touches CanonicalTransaction, balances, or payment promises.
    """

    def __init__(self, db: Session, client: Optional[SerpApiClient] = None):
        self.db = db
        self.client = client or SerpApiClient()
        self.repo = MarketIntelligenceRepository(db)

    def validate_plan(self, plan: ResearchPlan) -> None:
        if not plan.selected_engines:
            raise ValueError("ResearchPlan specifies no engines to execute.")
        if len(plan.selected_engines) > 2:
            raise ValueError(f"ResearchPlan exceeds maximum 2 allowed engines: {len(plan.selected_engines)}")
        for eng in plan.selected_engines:
            if not isinstance(eng, SerpApiEngine) and eng not in list(SerpApiEngine):
                raise ValueError(f"Unauthorized or invalid SerpApi engine: {eng}")

    def validate_evidence_item(self, item: ExternalEvidenceItem, engine: SerpApiEngine) -> bool:
        """
        Validates normalized evidence item. Ensures meaningful title and supported engine.
        Rejects items with blank titles or corrupt data.
        """
        if not item.title or not item.title.strip():
            return False
        # If url present, ensure it has basic structure
        if item.url and not (item.url.startswith("http://") or item.url.startswith("https://")):
            return False
        return True

    def _execute_single_engine(
        self,
        engine: SerpApiEngine,
        query: str,
        geographic_context: Optional[str]
    ) -> Tuple[Optional[SerpApiResult], Optional[str], Optional[str]]:
        """
        Calls SerpApiClient for one planned engine.
        Returns (result, status_str, error_message).
        """
        try:
            if engine == SerpApiEngine.SEARCH:
                res = self.client.search(query=query, location=geographic_context)
            elif engine == SerpApiEngine.SHOPPING:
                res = self.client.shopping(query=query, location=geographic_context)
            elif engine == SerpApiEngine.NEWS:
                res = self.client.news(query=query, gl="in")
            else:
                return None, "ERROR", f"Unsupported engine: {engine.value if hasattr(engine, 'value') else engine}"

            return res, "SUCCESS", None

        except SerpApiTimeoutError as exc:
            logger.warning("SerpApi engine %s timed out: %s", engine.value, str(exc))
            return None, "TIMEOUT", str(exc)
        except SerpApiRateLimitError as exc:
            logger.warning("SerpApi engine %s rate limited: %s", engine.value, str(exc))
            return None, "RATE_LIMITED", str(exc)
        except (SerpApiUnavailableError, SerpApiConfigError, SerpApiRequestValidationError) as exc:
            logger.error("SerpApi engine %s error: %s", engine.value, str(exc))
            return None, "ERROR", str(exc)
        except Exception as exc:
            logger.error("Unexpected error querying engine %s: %s", engine.value, str(exc))
            return None, "ERROR", str(exc)

    def execute_plan(self, plan: ResearchPlan) -> ResearchExecutionResult:
        self.validate_plan(plan)

        attempted: List[str] = []
        succeeded: List[str] = []
        failed: List[str] = []
        engine_details: List[EngineExecutionDetail] = []
        collected_evidence: List[Tuple[SerpApiEngine, str, SerpApiResult, ExternalEvidenceItem]] = []

        now = datetime.now(timezone.utc)

        # 1. Execute planned engines (max 2)
        for engine in plan.selected_engines:
            eng_val = engine.value
            attempted.append(eng_val)
            query = plan.queries.get(eng_val)

            if not query or not query.strip():
                failed.append(eng_val)
                engine_details.append(EngineExecutionDetail(
                    engine=eng_val,
                    query="",
                    status="ERROR",
                    error_message="Missing planned query for engine"
                ))
                continue

            result, status_code, err_msg = self._execute_single_engine(
                engine=engine,
                query=query,
                geographic_context=plan.geographic_context
            )

            if status_code == "SUCCESS" and result is not None:
                succeeded.append(eng_val)
                # Filter and validate items
                valid_items = [it for it in result.normalized_items if self.validate_evidence_item(it, engine)]
                for item in valid_items:
                    collected_evidence.append((engine, query, result, item))

                engine_details.append(EngineExecutionDetail(
                    engine=eng_val,
                    query=query,
                    status="SUCCESS" if valid_items else "NO_EVIDENCE",
                    evidence_count=len(valid_items),
                    cached=result.cached,
                    error_message=None
                ))
            else:
                failed.append(eng_val)
                engine_details.append(EngineExecutionDetail(
                    engine=eng_val,
                    query=query,
                    status=status_code or "ERROR",
                    evidence_count=0,
                    cached=False,
                    error_message=err_msg
                ))

        # 2. Persist Evidence into Market Intelligence Domain
        persisted_sources = 0
        persisted_events = 0
        persisted_relevances = 0

        for engine, query, res, item in collected_evidence:
            source_url = item.url or f"https://serpapi.com/engine/{engine.value}?q={query}"
            source_name = item.source_name or f"SerpApi {engine.value}"
            title = item.title[:255]
            summary = (item.snippet or item.title)[:500]

            # Content hash for deterministic deduplication
            content_hash = hashlib.sha256(
                f"serpapi|{engine.value}|{source_url.strip().lower()}|{title.strip().lower()}".encode("utf-8")
            ).hexdigest()

            # Compact provenance metadata only (strictly no raw payload dumps or credentials)
            raw_meta = {
                "engine": engine.value,
                "query": query,
                "cached": res.cached,
                "price": item.price,
                "rating": item.rating,
                "reviews": item.reviews,
                "location": item.location,
                "metrics": item.metrics,
                "event_id": str(plan.event_id),
                "merchant_id": str(plan.merchant_id),
                "retrieved_at": res.retrieved_at.isoformat() if res.retrieved_at else now.isoformat(),
                "time_window": plan.time_context,
            }

            # Persist MarketSource (idempotent / deduplicated by hash)
            existing_source = self.repo.get_source_by_hash("SerpApi", content_hash)
            if existing_source:
                source = existing_source
            else:
                source = self.repo.create_source(
                    provider_name="SerpApi",
                    source_name=source_name[:100],
                    source_url=source_url[:500],
                    title=title,
                    published_at=now,
                    content_hash=content_hash,
                    raw_metadata=raw_meta
                )
                persisted_sources += 1

            # Associate / Create MarketEvent
            mkt_ev_type = map_engine_to_market_event_type(engine, plan.intent.event_type)
            market_event = self.db.query(MarketEvent).filter(MarketEvent.source_id == source.id).first()
            if not market_event:
                market_event = self.repo.create_event(
                    source_id=source.id,
                    event_type=mkt_ev_type,
                    title=title,
                    summary=summary,
                    occurred_at=now,
                    geography=plan.geographic_context[:100] if plan.geographic_context else "IN",
                    sector=plan.intent.business_type[:100] if plan.intent.business_type else None,
                    affected_domains=["market_research", "financial_event_evidence"],
                    metadata_info=raw_meta
                )
                persisted_events += 1

            # Associate MerchantMarketRelevance (Merchant-Isolated)
            rel_snapshot = {
                "originating_event_id": str(plan.event_id),
                "financial_event_type": plan.intent.event_type,
                "engine": engine.value,
                "query": query,
                "subject": plan.intent.subject,
                "rationale": plan.rationale,
            }
            relevance = self.repo.create_or_update_relevance(
                merchant_id=plan.merchant_id,
                market_event_id=market_event.id,
                relevance_status=MarketRelevanceStatus.POTENTIALLY_RELEVANT,
                reason_codes=["DETERMINISTIC_RESEARCH_RESULT", f"ENGINE_{engine.name}"],
                context_snapshot=rel_snapshot
            )
            if relevance:
                persisted_relevances += 1

        # 3. Determine Overall ExecutionStatus
        if len(succeeded) == len(attempted) and len(succeeded) > 0:
            if len(collected_evidence) == 0:
                final_status = ExecutionStatus.NO_EVIDENCE
            else:
                final_status = ExecutionStatus.SUCCESS
        elif len(succeeded) > 0 and len(failed) > 0:
            final_status = ExecutionStatus.PARTIAL_SUCCESS
        elif len(attempted) > 0 and len(succeeded) == 0:
            final_status = ExecutionStatus.FAILED
        else:
            final_status = ExecutionStatus.NO_EVIDENCE

        failure_summary = None
        if failed:
            failure_summary = f"Failed engines: {', '.join(failed)}"

        return ResearchExecutionResult(
            plan_id=None,
            event_id=plan.event_id,
            merchant_id=plan.merchant_id,
            status=final_status,
            engines_attempted=attempted,
            engines_succeeded=succeeded,
            engines_failed=failed,
            evidence_count=len(collected_evidence),
            persisted_sources_count=persisted_sources,
            persisted_events_count=persisted_events,
            persisted_relevances_count=persisted_relevances,
            engine_details=engine_details,
            failure_summary=failure_summary,
            executed_at=now
        )
