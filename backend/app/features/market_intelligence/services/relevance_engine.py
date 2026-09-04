from typing import Tuple, List
from app.models.market_event import MarketEvent, MarketEventType
from app.models.merchant_market_relevance import MarketRelevanceStatus
from app.features.market_intelligence.services.context_builder import MerchantMarketContextPackage


class MarketRelevanceRuleEngine:
    @classmethod
    def evaluate_relevance(
        cls,
        event: MarketEvent,
        context: MerchantMarketContextPackage
    ) -> Tuple[MarketRelevanceStatus, List[str], str]:
        reason_codes = []

        # 1. CURRENCY_MOVEMENT + declared import exposure -> POTENTIALLY_RELEVANT
        if event.event_type == MarketEventType.CURRENCY_MOVEMENT:
            if "DECLARED_IMPORT_EXPOSURE" in context.declared_exposures or "IMPORT" in (context.business_type or "").upper():
                reason_codes.append("DECLARED_IMPORT_EXPOSURE")
                return (
                    MarketRelevanceStatus.POTENTIALLY_RELEVANT,
                    reason_codes,
                    "Your business profile indicates declared import exposure, so significant currency movements may affect future procurement costs."
                )
            else:
                return (
                    MarketRelevanceStatus.REQUIRES_MORE_CONTEXT,
                    ["UNKNOWN_IMPORT_EXPOSURE"],
                    "Currency movements may matter if your business relies on imported raw materials or foreign suppliers."
                )

        # 2. COMMODITY_PRICE_MOVEMENT + matching sector / tags -> POTENTIALLY_RELEVANT
        if event.event_type == MarketEventType.COMMODITY_PRICE_MOVEMENT:
            if event.sector and any(tag in event.sector.upper() for tag in context.known_business_tags):
                reason_codes.append("RELATED_EXPENSE_CATEGORY")
                return (
                    MarketRelevanceStatus.POTENTIALLY_RELEVANT,
                    reason_codes,
                    f"Commodity price movements in {event.sector} match your business operating sector."
                )
            elif context.known_business_tags:
                reason_codes.append("SECTOR_COMMODITY_EXPOSURE")
                return (
                    MarketRelevanceStatus.POTENTIALLY_RELEVANT,
                    reason_codes,
                    "Commodity price fluctuations may influence local raw material costs."
                )

        # 3. BANKING_CHANGE or PAYMENT_INDUSTRY_CHANGE -> POTENTIALLY_RELEVANT
        if event.event_type in (MarketEventType.BANKING_CHANGE, MarketEventType.PAYMENT_INDUSTRY_CHANGE):
            reason_codes.append("KNOWN_PAYMENT_PROVIDER")
            return (
                MarketRelevanceStatus.POTENTIALLY_RELEVANT,
                reason_codes,
                "Changes in banking or payment industry regulations may affect digital payment settlement times."
            )

        # 4. GOVERNMENT_POLICY + matching sector -> POTENTIALLY_RELEVANT
        if event.event_type == MarketEventType.GOVERNMENT_POLICY:
            if event.sector and any(tag in event.sector.upper() for tag in context.known_business_tags):
                reason_codes.append("GOVERNMENT_POLICY_SECTOR_MATCH")
                return (
                    MarketRelevanceStatus.POTENTIALLY_RELEVANT,
                    reason_codes,
                    f"Government policy update directly targets the {event.sector} sector."
                )

        # 5. INTEREST_RATE_CHANGE -> REQUIRES_MORE_CONTEXT
        if event.event_type == MarketEventType.INTEREST_RATE_CHANGE:
            return (
                MarketRelevanceStatus.REQUIRES_MORE_CONTEXT,
                ["UNKNOWN_LOAN_OBLIGATION"],
                "Interest rate changes may affect commercial credit rates if your business holds floating-rate obligations."
            )

        # 6. Generic foreign or unmatched event -> NOT_RELEVANT
        if event.geography and event.geography != "IN" and event.geography != context.operating_geography:
            return (
                MarketRelevanceStatus.NOT_RELEVANT,
                ["GEOGRAPHY_MISMATCH"],
                "Event occurred outside your primary operating geography with no declared global exposure."
            )

        return (
            MarketRelevanceStatus.NOT_RELEVANT,
            ["NO_CONTEXT_MATCH"],
            "No direct match found between event domain and current business profile."
        )
