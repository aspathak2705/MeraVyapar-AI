import hashlib
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
from app.infrastructure.market_intelligence.serpapi_models import (
    SerpApiEngine,
    ExternalEvidenceItem,
    ExternalEvidenceSource,
)


def compute_evidence_hash(provider_name: str, engine: str, url: Optional[str], title: str) -> str:
    raw = f"{provider_name.strip().lower()}|{engine.strip().lower()}|{(url or '').strip().lower()}|{title.strip().lower()}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


class SerpApiNormalizer:
    """
    Normalizes diverse SerpApi engine responses into uniform ExternalEvidenceItem
    and ExternalEvidenceSource structures preserving provenance, metadata, and timestamps.
    """

    @staticmethod
    def normalize(engine: SerpApiEngine, raw_response: Dict[str, Any], query: str) -> List[ExternalEvidenceItem]:
        # Handle string engine values for backwards compatibility with historical records
        eng_val = engine.value if isinstance(engine, SerpApiEngine) else str(engine)
        if eng_val == "google" or engine == SerpApiEngine.SEARCH:
            return SerpApiNormalizer._normalize_search(raw_response)
        elif eng_val == "google_shopping" or engine == SerpApiEngine.SHOPPING:
            return SerpApiNormalizer._normalize_shopping(raw_response)
        elif eng_val == "google_news" or engine == SerpApiEngine.NEWS:
            return SerpApiNormalizer._normalize_news(raw_response)
        elif eng_val == "google_trends":
            return SerpApiNormalizer._normalize_trends(raw_response)
        elif eng_val == "google_maps":
            return SerpApiNormalizer._normalize_local(raw_response)
        elif eng_val == "google_finance":
            return SerpApiNormalizer._normalize_finance(raw_response)
        return []

    @staticmethod
    def _normalize_search(raw: Dict[str, Any]) -> List[ExternalEvidenceItem]:
        items: List[ExternalEvidenceItem] = []
        # Answer box / snippet if present
        if "answer_box" in raw and isinstance(raw["answer_box"], dict):
            ab = raw["answer_box"]
            title = ab.get("title") or ab.get("snippet") or "Search Answer Box"
            items.append(ExternalEvidenceItem(
                title=str(title)[:255],
                snippet=ab.get("snippet") or ab.get("answer"),
                url=ab.get("link"),
                source_name=ab.get("source"),
                raw_payload=ab
            ))

        # Organic results
        organic = raw.get("organic_results", [])
        if isinstance(organic, list):
            for res in organic:
                if not isinstance(res, dict):
                    continue
                title = res.get("title") or "Untitled Result"
                items.append(ExternalEvidenceItem(
                    title=str(title)[:255],
                    snippet=res.get("snippet"),
                    url=res.get("link"),
                    source_name=res.get("displayed_link") or res.get("source"),
                    published_date=res.get("date"),
                    raw_payload=res
                ))
        return items

    @staticmethod
    def _normalize_trends(raw: Dict[str, Any]) -> List[ExternalEvidenceItem]:
        items: List[ExternalEvidenceItem] = []
        interest_over_time = raw.get("interest_over_time", {})
        timeline_data = interest_over_time.get("timeline_data", []) if isinstance(interest_over_time, dict) else []

        if isinstance(timeline_data, list) and timeline_data:
            latest_point = timeline_data[-1] if timeline_data else {}
            title = f"Trend Timeline (Latest Value: {latest_point.get('values', [{}])[0].get('extracted_value', 'N/A')})"
            items.append(ExternalEvidenceItem(
                title=title[:255],
                snippet=f"Timeline spanning {len(timeline_data)} points",
                metrics={"timeline_data_points": len(timeline_data), "latest_point": latest_point},
                raw_payload=interest_over_time if isinstance(interest_over_time, dict) else {}
            ))

        # Related queries / queries breakdown
        related_queries = raw.get("related_queries", {})
        if isinstance(related_queries, dict):
            for bucket in ("rising", "top"):
                queries_list = related_queries.get(bucket, [])
                if isinstance(queries_list, list):
                    for q_item in queries_list:
                        if not isinstance(q_item, dict):
                            continue
                        q_text = q_item.get("query", "Unknown Query")
                        value = q_item.get("value")
                        items.append(ExternalEvidenceItem(
                            title=f"Trend Related Query ({bucket.upper()}): {q_text}"[:255],
                            snippet=f"Growth metric/value: {value}",
                            metrics={"bucket": bucket, "value": value},
                            raw_payload=q_item
                        ))
        return items

    @staticmethod
    def _normalize_shopping(raw: Dict[str, Any]) -> List[ExternalEvidenceItem]:
        items: List[ExternalEvidenceItem] = []
        shopping_results = raw.get("shopping_results", [])
        if isinstance(shopping_results, list):
            for res in shopping_results:
                if not isinstance(res, dict):
                    continue
                title = res.get("title") or "Shopping Item"
                price = res.get("price") or res.get("extracted_price")
                items.append(ExternalEvidenceItem(
                    title=str(title)[:255],
                    snippet=res.get("snippet"),
                    url=res.get("link"),
                    source_name=res.get("source"),
                    price=str(price) if price else None,
                    rating=float(res.get("rating")) if res.get("rating") is not None else None,
                    reviews=int(res.get("reviews")) if res.get("reviews") is not None else None,
                    raw_payload=res
                ))
        return items

    @staticmethod
    def _normalize_news(raw: Dict[str, Any]) -> List[ExternalEvidenceItem]:
        items: List[ExternalEvidenceItem] = []
        news_results = raw.get("news_results", [])
        if isinstance(news_results, list):
            for res in news_results:
                if not isinstance(res, dict):
                    continue
                title = res.get("title") or "News Story"
                source_obj = res.get("source")
                source_name = source_obj.get("name") if isinstance(source_obj, dict) else str(source_obj) if source_obj else None
                items.append(ExternalEvidenceItem(
                    title=str(title)[:255],
                    snippet=res.get("snippet"),
                    url=res.get("link"),
                    source_name=source_name,
                    published_date=res.get("date"),
                    raw_payload=res
                ))
        return items

    @staticmethod
    def _normalize_local(raw: Dict[str, Any]) -> List[ExternalEvidenceItem]:
        items: List[ExternalEvidenceItem] = []
        local_results = raw.get("local_results", [])
        if isinstance(local_results, list):
            for res in local_results:
                if not isinstance(res, dict):
                    continue
                title = res.get("title") or "Local Business / POI"
                items.append(ExternalEvidenceItem(
                    title=str(title)[:255],
                    snippet=res.get("description") or res.get("type"),
                    url=res.get("website") or res.get("link"),
                    source_name=res.get("type"),
                    rating=float(res.get("rating")) if res.get("rating") is not None else None,
                    reviews=int(res.get("reviews")) if res.get("reviews") is not None else None,
                    location=res.get("address"),
                    metrics={"gps_coordinates": res.get("gps_coordinates"), "phone": res.get("phone")},
                    raw_payload=res
                ))
        return items

    @staticmethod
    def _normalize_finance(raw: Dict[str, Any]) -> List[ExternalEvidenceItem]:
        items: List[ExternalEvidenceItem] = []
        summary = raw.get("summary", {})
        if isinstance(summary, dict) and summary:
            title = summary.get("title") or "Financial Market Asset"
            price = summary.get("price") or summary.get("extracted_price")
            items.append(ExternalEvidenceItem(
                title=str(title)[:255],
                snippet=f"Currency: {summary.get('currency')}, Exchange: {summary.get('exchange')}",
                price=str(price) if price else None,
                metrics={
                    "change": summary.get("price_change"),
                    "percentage": summary.get("price_change_percentage"),
                    "exchange": summary.get("exchange")
                },
                raw_payload=summary
            ))

        # Financial news / knowledge
        news = raw.get("financial_news", [])
        if isinstance(news, list):
            for res in news:
                if not isinstance(res, dict):
                    continue
                title = res.get("title") or "Market News"
                items.append(ExternalEvidenceItem(
                    title=str(title)[:255],
                    snippet=res.get("snippet"),
                    url=res.get("link"),
                    source_name=res.get("source"),
                    published_date=res.get("date"),
                    raw_payload=res
                ))
        return items
