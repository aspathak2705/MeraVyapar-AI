from uuid import UUID
from typing import Optional, List, Dict, Any
from sqlalchemy.orm import Session
from app.models.business_profile import BusinessProfile
from app.repositories.counterparty_repository import CounterpartyRepository


class MerchantMarketContextPackage:
    def __init__(
        self,
        merchant_id: UUID,
        business_name: str,
        business_type: Optional[str],
        operating_geography: str,
        known_business_tags: List[str],
        declared_exposures: List[str],
        known_counterparties: List[str]
    ):
        self.merchant_id = merchant_id
        self.business_name = business_name
        self.business_type = business_type
        self.operating_geography = operating_geography
        self.known_business_tags = known_business_tags
        self.declared_exposures = declared_exposures
        self.known_counterparties = known_counterparties

    def to_dict(self) -> Dict[str, Any]:
        return {
            "merchant_id": str(self.merchant_id),
            "business_name": self.business_name,
            "business_type": self.business_type,
            "operating_geography": self.operating_geography,
            "known_business_tags": self.known_business_tags,
            "declared_exposures": self.declared_exposures,
            "known_counterparties": self.known_counterparties,
        }


class MerchantMarketContextBuilder:
    def __init__(self, db: Session):
        self.db = db
        self.cp_repo = CounterpartyRepository(db)

    def build_merchant_market_context(self, merchant_id: UUID) -> MerchantMarketContextPackage:
        profile = self.db.query(BusinessProfile).filter(BusinessProfile.merchant_id == merchant_id).first()

        business_name = profile.business_name if profile else "Merchant Store"
        business_type = profile.business_type if profile else "GENERAL"
        state = profile.state if profile else "IN"

        tags = []
        exposures = []
        if business_type:
            bt_upper = business_type.upper()
            tags.append(bt_upper)
            if "IMPORT" in bt_upper or "GLOBAL" in bt_upper:
                exposures.append("DECLARED_IMPORT_EXPOSURE")
            if "RETAIL" in bt_upper:
                tags.append("RETAIL")
            if "TEXTILE" in bt_upper:
                tags.append("TEXTILE")
            if "ELECTRONICS" in bt_upper:
                tags.append("ELECTRONICS")

        counterparties = self.cp_repo.list_by_merchant(merchant_id, skip=0, limit=50)
        cp_names = [cp.display_name for cp in counterparties]

        return MerchantMarketContextPackage(
            merchant_id=merchant_id,
            business_name=business_name,
            business_type=business_type,
            operating_geography=state or "IN",
            known_business_tags=tags,
            declared_exposures=exposures,
            known_counterparties=cp_names
        )
