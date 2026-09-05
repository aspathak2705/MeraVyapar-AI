from uuid import UUID
from typing import Optional, Dict, Any, List
from sqlalchemy.orm import Session
from app.repositories.merchant_repository import MerchantRepository
from app.infrastructure.datasets.dataset_registry import dataset_registry
from app.features.reference_intelligence.domain.merchant_archetype import MerchantArchetype, ArchetypeMatchResult


class MerchantArchetypeService:
    def __init__(self, db: Session):
        self.db = db
        self.merchant_repo = MerchantRepository(db)

    def match_merchant_archetype(self, merchant_id: UUID) -> ArchetypeMatchResult:
        merchant = self.merchant_repo.get_by_id(merchant_id)
        if not merchant:
            return ArchetypeMatchResult(status="MERCHANT_NOT_FOUND")

        ds0 = dataset_registry.get_dataset("dataset_0")
        if not ds0:
            return ArchetypeMatchResult(status="REFERENCE_DATASET_UNAVAILABLE")

        # Explicitly declared profile attributes
        from app.models.business_profile import BusinessProfile
        bp = self.db.query(BusinessProfile).filter(BusinessProfile.merchant_id == merchant_id).first()
        declared_type = bp.business_type.lower().replace(" ", "_") if (bp and bp.business_type) else "retail"
        declared_size = "small"

        matched_record = None
        matched_attrs = []
        unmatched_attrs = []

        # Find best match from Dataset 0 archetypes
        for record in ds0:
            if record.get("business_type", "").lower() == declared_type and record.get("business_size", "").lower() == declared_size:
                matched_record = record
                matched_attrs = ["business_type", "business_size"]
                break

        if not matched_record:
            # Fallback match on business_type only
            for record in ds0:
                if record.get("business_type", "").lower() == declared_type:
                    matched_record = record
                    matched_attrs = ["business_type"]
                    unmatched_attrs = ["business_size"]
                    break

        if not matched_record:
            matched_record = ds0[0]
            unmatched_attrs = ["business_type", "business_size"]

        unmatched_attrs.extend(["seasonality_pattern", "cash_flow_volatility"])

        archetype = MerchantArchetype(
            business_type=matched_record.get("business_type", "retail"),
            business_size=matched_record.get("business_size", "small"),
            seasonality_pattern=matched_record.get("seasonality_pattern", "stable"),
            cash_flow_volatility=matched_record.get("cash_flow_volatility", "stable"),
            receivable_behavior_profile=matched_record.get("receivable_behavior_profile", "immediate"),
            supplier_payment_behavior=matched_record.get("supplier_payment_behavior", "weekly")
        )

        patterns = [
            f"Businesses classified as {archetype.business_type} typically observe {archetype.seasonality_pattern} seasonality.",
            f"Supplier payment schedules for this archetype commonly follow a {archetype.supplier_payment_behavior} rhythm."
        ]

        return ArchetypeMatchResult(
            matched_archetype=archetype,
            matched_attributes=matched_attrs,
            unmatched_attributes=unmatched_attrs,
            reference_patterns=patterns,
            status="AVAILABLE"
        )
