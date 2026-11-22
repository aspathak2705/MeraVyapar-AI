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
    def normalize(engine: Any, raw_response: Dict[str, Any], query: str) -> List[ExternalEvidenceItem]:
        if not isinstance(raw_response, dict):
            return []
        eng_val = engine.value if isinstance(engine, SerpApiEngine) else str(engine).lower().strip()
        if eng_val in ("google", SerpApiEngine.SEARCH.value):
            return SerpApiNormalizer._normalize_search(raw_response)
        elif eng_val in ("google_shopping", SerpApiEngine.SHOPPING.value):
            return SerpApiNormalizer._normalize_shopping(raw_response)
        elif eng_val in ("google_news", SerpApiEngine.NEWS.value):
            return SerpApiNormalizer._normalize_news(raw_response)
        elif eng_val in ("google_trends", SerpApiEngine.TRENDS.value):
            return SerpApiNormalizer._normalize_trends(raw_response)
        elif eng_val in ("google_maps", SerpApiEngine.MAPS.value, "google_local"):
            return SerpApiNormalizer._normalize_local(raw_response)
        elif eng_val in ("google_finance", SerpApiEngine.FINANCE.value):
            return SerpApiNormalizer._normalize_finance(raw_response)
        return []

    @staticmethod
    def _safe_float(val: Any) -> Optional[float]:
        if val is None:
            return None
        try:
            return float(val)
        except (ValueError, TypeError):
            return None

    @staticmethod
    def _safe_int(val: Any) -> Optional[int]:
        if val is None:
            return None
        try:
            return int(val)
        except (ValueError, TypeError):
            return None

    @staticmethod
    def _normalize_search(raw: Dict[str, Any]) -> List[ExternalEvidenceItem]:
        items: List[ExternalEvidenceItem] = []
        if not isinstance(raw, dict):
            return items

        # Answer box / snippet if present
        ab = raw.get("answer_box")
        if isinstance(ab, dict):
            title = ab.get("title") or ab.get("snippet") or "Search Answer Box"
            items.append(ExternalEvidenceItem(
                title=str(title)[:255],
                snippet=str(ab.get("snippet") or ab.get("answer") or "") if (ab.get("snippet") or ab.get("answer")) else None,
                url=str(ab.get("link")) if ab.get("link") else None,
                source_name=str(ab.get("source")) if ab.get("source") else None,
                published_date=str(ab.get("date")) if ab.get("date") else None,
                raw_payload=ab
            ))

        # Organic results
        organic = raw.get("organic_results")
        if isinstance(organic, list):
            for res in organic:
                if not isinstance(res, dict):
                    continue
                title = res.get("title") or res.get("snippet") or "Untitled Result"
                items.append(ExternalEvidenceItem(
                    title=str(title)[:255],
                    snippet=str(res.get("snippet")) if res.get("snippet") is not None else None,
                    url=str(res.get("link")) if res.get("link") else None,
                    source_name=str(res.get("displayed_link") or res.get("source") or "") if (res.get("displayed_link") or res.get("source")) else None,
                    published_date=str(res.get("date")) if res.get("date") else None,
                    raw_payload=res
                ))
        return items

    @staticmethod
    def _normalize_trends(raw: Dict[str, Any]) -> List[ExternalEvidenceItem]:
        items: List[ExternalEvidenceItem] = []
        if not isinstance(raw, dict):
            return items

        interest_over_time = raw.get("interest_over_time")
        if isinstance(interest_over_time, dict):
            timeline_data = interest_over_time.get("timeline_data")
            if isinstance(timeline_data, list) and timeline_data:
                latest_point = timeline_data[-1] if isinstance(timeline_data[-1], dict) else {}
                val_list = latest_point.get("values") if isinstance(latest_point, dict) else None
                extracted_val = "N/A"
                if isinstance(val_list, list) and val_list and isinstance(val_list[0], dict):
                    extracted_val = str(val_list[0].get("extracted_value", "N/A"))
                title = f"Trend Timeline (Latest Value: {extracted_val})"
                items.append(ExternalEvidenceItem(
                    title=title[:255],
                    snippet=f"Timeline spanning {len(timeline_data)} points",
                    metrics={"timeline_data_points": len(timeline_data), "latest_point": latest_point},
                    raw_payload=interest_over_time
                ))

        # Related queries / queries breakdown
        related_queries = raw.get("related_queries")
        if isinstance(related_queries, dict):
            for bucket in ("rising", "top"):
                queries_list = related_queries.get(bucket)
                if isinstance(queries_list, list):
                    for q_item in queries_list:
                        if not isinstance(q_item, dict):
                            continue
                        q_text = str(q_item.get("query") or "Unknown Query")
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
        if not isinstance(raw, dict):
            return items

        shopping_results = raw.get("shopping_results")
        if isinstance(shopping_results, list):
            for res in shopping_results:
                if not isinstance(res, dict):
                    continue
                title = res.get("title") or "Shopping Item"
                price = res.get("price") or res.get("extracted_price")
                items.append(ExternalEvidenceItem(
                    title=str(title)[:255],
                    snippet=str(res.get("snippet")) if res.get("snippet") is not None else None,
                    url=str(res.get("link")) if res.get("link") else None,
                    source_name=str(res.get("source")) if res.get("source") else None,
                    published_date=str(res.get("date")) if res.get("date") else None,
                    price=str(price) if price is not None else None,
                    rating=SerpApiNormalizer._safe_float(res.get("rating")),
                    reviews=SerpApiNormalizer._safe_int(res.get("reviews")),
                    raw_payload=res
                ))
        return items

    @staticmethod
    def _normalize_news(raw: Dict[str, Any]) -> List[ExternalEvidenceItem]:
        items: List[ExternalEvidenceItem] = []
        if not isinstance(raw, dict):
            return items

        news_results = raw.get("news_results")
        if isinstance(news_results, list):
            for res in news_results:
                if not isinstance(res, dict):
                    continue
                title = res.get("title") or res.get("snippet") or "News Story"
                source_obj = res.get("source")
                source_name = source_obj.get("name") if isinstance(source_obj, dict) else str(source_obj) if source_obj else None
                items.append(ExternalEvidenceItem(
                    title=str(title)[:255],
                    snippet=str(res.get("snippet")) if res.get("snippet") is not None else None,
                    url=str(res.get("link")) if res.get("link") else None,
                    source_name=str(source_name) if source_name else None,
                    published_date=str(res.get("date")) if res.get("date") else None,
                    raw_payload=res
                ))
        return items

    @staticmethod
    def _normalize_local(raw: Dict[str, Any]) -> List[ExternalEvidenceItem]:
        items: List[ExternalEvidenceItem] = []
        if not isinstance(raw, dict):
            return items

        local_results = raw.get("local_results")
        if not local_results and isinstance(raw.get("place_results"), dict):
            local_results = [raw["place_results"]]
        elif not local_results and isinstance(raw.get("place_results"), list):
            local_results = raw.get("place_results")

        if isinstance(local_results, list):
            for res in local_results:
                if not isinstance(res, dict):
                    continue
                title = res.get("title") or "Local Business / POI"
                items.append(ExternalEvidenceItem(
                    title=str(title)[:255],
                    snippet=str(res.get("description") or res.get("type") or "") if (res.get("description") or res.get("type")) else None,
                    url=str(res.get("website") or res.get("link") or "") if (res.get("website") or res.get("link")) else None,
                    source_name=str(res.get("type")) if res.get("type") else None,
                    published_date=str(res.get("date")) if res.get("date") else None,
                    rating=SerpApiNormalizer._safe_float(res.get("rating")),
                    reviews=SerpApiNormalizer._safe_int(res.get("reviews")),
                    location=str(res.get("address")) if res.get("address") else None,
                    metrics={
                        "gps_coordinates": res.get("gps_coordinates"),
                        "phone": res.get("phone"),
                        "website": res.get("website"),
                    },
                    raw_payload=res
                ))
        return items

    @staticmethod
    def _normalize_finance(raw: Dict[str, Any]) -> List[ExternalEvidenceItem]:
        items: List[ExternalEvidenceItem] = []
        if not isinstance(raw, dict):
            return items

        summary = raw.get("summary")
        if isinstance(summary, dict) and summary:
            title = summary.get("title") or "Financial Market Asset"
            price = summary.get("price") or summary.get("extracted_price")
            items.append(ExternalEvidenceItem(
                title=str(title)[:255],
                snippet=f"Currency: {summary.get('currency')}, Exchange: {summary.get('exchange')}",
                price=str(price) if price is not None else None,
                metrics={
                    "change": summary.get("price_change"),
                    "percentage": summary.get("price_change_percentage"),
                    "exchange": summary.get("exchange")
                },
                raw_payload=summary
            ))

        # Financial news / knowledge
        news = raw.get("financial_news")
        if isinstance(news, list):
            for res in news:
                if not isinstance(res, dict):
                    continue
                title = res.get("title") or res.get("snippet") or "Market News"
                items.append(ExternalEvidenceItem(
                    title=str(title)[:255],
                    snippet=str(res.get("snippet")) if res.get("snippet") is not None else None,
                    url=str(res.get("link")) if res.get("link") else None,
                    source_name=str(res.get("source")) if res.get("source") else None,
                    published_date=str(res.get("date")) if res.get("date") else None,
                    raw_payload=res
                ))
        return items
