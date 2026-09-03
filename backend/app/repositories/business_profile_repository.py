from uuid import UUID
from typing import Optional
from sqlalchemy.orm import Session
from app.models.business_profile import BusinessProfile
from app.schemas.business_profile import BusinessProfileCreate, BusinessProfileUpdate


class BusinessProfileRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_merchant_id(self, merchant_id: UUID) -> Optional[BusinessProfile]:
        return self.db.query(BusinessProfile).filter(BusinessProfile.merchant_id == merchant_id).first()

    def create(self, merchant_id: UUID, profile_in: BusinessProfileCreate) -> BusinessProfile:
        profile = BusinessProfile(
            merchant_id=merchant_id,
            business_name=profile_in.business_name,
            business_type=profile_in.business_type,
            phone_number=profile_in.phone_number,
            city=profile_in.city,
            state=profile_in.state,
            onboarding_completed=True
        )
        self.db.add(profile)
        self.db.commit()
        self.db.refresh(profile)
        return profile

    def update(self, profile: BusinessProfile, profile_in: BusinessProfileUpdate) -> BusinessProfile:
        update_data = profile_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(profile, field, value)

        self.db.commit()
        self.db.refresh(profile)
        return profile
