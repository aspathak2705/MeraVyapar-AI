from uuid import UUID
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_user_id, get_current_merchant
from app.services.merchant_service import MerchantService
from app.schemas.merchant import MerchantResponse, MerchantCreate
from app.schemas.common import APIResponse
from app.models.merchant import Merchant

router = APIRouter()


@router.post("/merchants/initialize", response_model=APIResponse, status_code=status.HTTP_200_OK)
def initialize_merchant(
    payload: MerchantCreate = MerchantCreate(),
    auth_user_id: UUID = Depends(get_current_user_id),
    db: Session = Depends(get_db)
):
    """
    Idempotent initialization of merchant record for authenticated user.
    """
    service = MerchantService(db)
    merchant = service.initialize_merchant(auth_user_id, payload.display_name)
    merchant_data = MerchantResponse.model_validate(merchant).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Merchant initialized successfully",
        data=merchant_data
    )


@router.get("/merchants/me", response_model=APIResponse)
def get_current_merchant_endpoint(
    merchant: Merchant = Depends(get_current_merchant)
):
    """
    Strictly read-only endpoint returning current authenticated merchant context.
    """
    merchant_data = MerchantResponse.model_validate(merchant).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Merchant retrieved successfully",
        data=merchant_data
    )
