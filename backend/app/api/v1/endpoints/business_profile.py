from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.services.merchant_service import MerchantService
from app.schemas.business_profile import (
    BusinessProfileResponse,
    BusinessProfileCreate,
    BusinessProfileUpdate
)
from app.schemas.common import APIResponse
from app.models.merchant import Merchant

router = APIRouter()


@router.get("/business-profile/me", response_model=APIResponse)
def get_my_business_profile(
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = MerchantService(db)
    profile = service.get_business_profile(merchant.id)
    profile_data = BusinessProfileResponse.model_validate(profile).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Business profile retrieved successfully",
        data=profile_data
    )


@router.put("/business-profile/me", response_model=APIResponse)
def update_my_business_profile(
    profile_in: BusinessProfileCreate,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = MerchantService(db)
    profile = service.create_or_update_business_profile(merchant, profile_in)
    profile_data = BusinessProfileResponse.model_validate(profile).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Business profile updated successfully",
        data=profile_data
    )
