from uuid import UUID
from typing import Optional
from sqlalchemy.orm import Session
from app.repositories.merchant_repository import MerchantRepository
from app.repositories.business_profile_repository import BusinessProfileRepository
from app.schemas.business_profile import BusinessProfileCreate, BusinessProfileUpdate
from app.models.merchant import Merchant
from app.models.business_profile import BusinessProfile
from app.core.exceptions import NotFoundError, ConflictError


class MerchantService:
    def __init__(self, db: Session):
        self.db = db
        self.merchant_repo = MerchantRepository(db)
        self.profile_repo = BusinessProfileRepository(db)

    def initialize_merchant(self, auth_user_id: UUID, display_name: Optional[str] = None) -> Merchant:
        """
        Idempotently initializes merchant profile for authenticated user.
        If merchant exists, returns existing record.
        """
        existing = self.merchant_repo.get_by_auth_user_id(auth_user_id)
        if existing:
            return existing
        return self.merchant_repo.create_merchant(auth_user_id, display_name)

    def get_merchant_by_auth_user_id(self, auth_user_id: UUID) -> Merchant:
        """
        Read-only fetch of merchant record.
        """
        merchant = self.merchant_repo.get_by_auth_user_id(auth_user_id)
        if not merchant:
            raise NotFoundError("Merchant profile not found for this authenticated user")
        return merchant

    def get_business_profile(self, merchant_id: UUID) -> BusinessProfile:
        profile = self.profile_repo.get_by_merchant_id(merchant_id)
        if not profile:
            raise NotFoundError("Business profile not found for this merchant")
        return profile

    def create_or_update_business_profile(
        self,
        merchant: Merchant,
        profile_in: BusinessProfileCreate
    ) -> BusinessProfile:
        existing_profile = self.profile_repo.get_by_merchant_id(merchant.id)
        if existing_profile:
            # Update existing
            update_data = BusinessProfileUpdate(
                business_name=profile_in.business_name,
                business_type=profile_in.business_type,
                phone_number=profile_in.phone_number,
                city=profile_in.city,
                state=profile_in.state,
                onboarding_completed=True
            )
            profile = self.profile_repo.update(existing_profile, update_data)
        else:
            profile = self.profile_repo.create(merchant.id, profile_in)

        # Update merchant status to ACTIVE if onboarding complete
        if merchant.status != "ACTIVE":
            self.merchant_repo.update_status(merchant, "ACTIVE")

        return profile

    def update_business_profile(
        self,
        merchant_id: UUID,
        profile_in: BusinessProfileUpdate
    ) -> BusinessProfile:
        profile = self.get_business_profile(merchant_id)
        return self.profile_repo.update(profile, profile_in)
