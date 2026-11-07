import re
from typing import Optional, List, Dict
from app.infrastructure.market_intelligence.serpapi_models import SerpApiEngine
from app.features.market_intelligence.research_models import ResearchIntent, ResearchPlan

# Regex patterns for sensitive data filtering
ACCOUNT_REGEX = re.compile(r"\b\d{9,18}\b")  # Bank account numbers
PHONE_REGEX = re.compile(r"\b(\+?91[\-\s]?)?[6789]\d{9}\b")  # Indian phone numbers
UPI_REGEX = re.compile(r"\b[\w\.\-]+@[\w\-]+\b")  # UPI IDs
UUID_HEX_REGEX = re.compile(r"\b[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}\b")
CURRENCY_AMOUNT_REGEX = re.compile(r"[₹$€£]\s*[\d,]+(\.\d{1,2})?")  # Specific amounts like ₹12,500


def sanitize_research_term(term: Optional[str]) -> str:
    """
    Strips private financial markers, customer PII, account numbers, and token patterns
    from candidate query search terms.
    """
    if not term:
        return ""
    cleaned = term
    cleaned = ACCOUNT_REGEX.sub("", cleaned)
    cleaned = PHONE_REGEX.sub("", cleaned)
    cleaned = UPI_REGEX.sub("", cleaned)
    cleaned = UUID_HEX_REGEX.sub("", cleaned)
    cleaned = CURRENCY_AMOUNT_REGEX.sub("", cleaned)
    # Strip excess whitespace
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned


class DeterministicResearchPlanner:
    """
    Deterministic rule engine mapping financial events and merchant context
    to at most 2 locked SerpApi engines with safe, targeted query generation.
    """

    MAX_TOOL_FAN_OUT = 2

    @classmethod
    def plan(cls, intent: ResearchIntent) -> Optional[ResearchPlan]:
        event_type = intent.event_type.upper()
        subject = sanitize_research_term(intent.category or intent.subject)
        business_type = sanitize_research_term(intent.business_type or "")
        city = sanitize_research_term(intent.operating_city or "")
        state = sanitize_research_term(intent.operating_state or "")

        loc_parts = [p for p in (city, state) if p]
        geo_str = ", ".join(loc_parts) if loc_parts else "India"

        # 1. EXPENSE_SPIKE or CATEGORY_COST_PRESSURE -> Google Search + Google Shopping
        if event_type in ("EXPENSE_SPIKE", "CATEGORY_COST_PRESSURE"):
            selected_engines = [SerpApiEngine.SEARCH, SerpApiEngine.SHOPPING]

            # Construct safe, targeted queries
            search_query_parts = []
            if subject:
                search_query_parts.append(subject)
            elif business_type:
                search_query_parts.append(business_type)
            else:
                search_query_parts.append("wholesale supplies")
            search_query_parts.append("prices commercial wholesale")
            if loc_parts:
                search_query_parts.append(geo_str)

            search_query = " ".join(search_query_parts)

            shopping_query_parts = []
            if subject:
                shopping_query_parts.append(subject)
            elif business_type:
                shopping_query_parts.append(business_type)
            else:
                shopping_query_parts.append("commercial supplies")
            shopping_query_parts.append("wholesale pack bulk")
            shopping_query = " ".join(shopping_query_parts)

            queries = {
                SerpApiEngine.SEARCH.value: search_query,
                SerpApiEngine.SHOPPING.value: shopping_query,
            }
            rationale = (
                f"Expense cost pressure detected for '{subject or 'general operations'}'; "
                f"evaluating external market wholesale prices and commercial shopping baselines."
            )

        # 2. REVENUE_DROP -> Google News + Google Search
        elif event_type == "REVENUE_DROP":
            selected_engines = [SerpApiEngine.NEWS, SerpApiEngine.SEARCH]

            topic = subject or business_type or "retail sales demand"
            news_query_parts = [topic, "market demand economic trends"]
            if loc_parts:
                news_query_parts.append(geo_str)
            news_query = " ".join(news_query_parts)

            search_query_parts = [topic, "industry slowdown sales trends"]
            if loc_parts:
                search_query_parts.append(geo_str)
            search_query = " ".join(search_query_parts)

            queries = {
                SerpApiEngine.NEWS.value: news_query,
                SerpApiEngine.SEARCH.value: search_query,
            }
            rationale = (
                f"Revenue contraction detected for '{business_type or 'merchant'}'; "
                f"inspecting external industry news developments and regional market trends."
            )

        # 3. LOCAL_SUPPLIER_RISK or SUPPLIER_DEPENDENCY -> Google Search (retained engine)
        elif event_type in ("LOCAL_SUPPLIER_RISK", "SUPPLIER_DEPENDENCY"):
            selected_engines = [SerpApiEngine.SEARCH]
            target_entity = sanitize_research_term(intent.counterparty_name) or subject or business_type or "wholesale supplier"
            search_query = f"{target_entity} suppliers wholesale in {geo_str}"
            queries = {
                SerpApiEngine.SEARCH.value: search_query,
            }
            rationale = (
                f"Local supplier concentration or counterparty exposure detected; "
                f"surveying supplier presence and alternative wholesale entities in {geo_str} via web search."
            )

        # 4. MACRO_INFLATION or COMMODITY_PRICE_MOVEMENT -> Google News + Google Search
        elif event_type in ("MACRO_INFLATION", "COMMODITY_PRICE_MOVEMENT"):
            selected_engines = [SerpApiEngine.NEWS, SerpApiEngine.SEARCH]
            target = subject or "commodity inflation"
            queries = {
                SerpApiEngine.NEWS.value: f"{target} price inflation index India",
                SerpApiEngine.SEARCH.value: f"{target} commercial wholesale price trend India",
            }
            rationale = (
                f"Broad economic or commodity price pressure detected; checking news reports and commercial market trends."
            )

        else:
            # Unrecognized or irrelevant financial event type: Do NOT formulate research plan
            return None

        # Hard constraint: Enforce maximum tool fan-out <= 2
        if len(selected_engines) > cls.MAX_TOOL_FAN_OUT:
            selected_engines = selected_engines[:cls.MAX_TOOL_FAN_OUT]
            queries = {eng.value: queries[eng.value] for eng in selected_engines if eng.value in queries}

        return ResearchPlan(
            event_id=intent.event_id,
            merchant_id=intent.merchant_id,
            intent=intent,
            selected_engines=selected_engines,
            queries=queries,
            geographic_context=geo_str,
            time_context=intent.time_window,
            rationale=rationale,
            max_results_per_engine=10,
        )
