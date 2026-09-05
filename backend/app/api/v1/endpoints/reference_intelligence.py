from uuid import UUID
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.models.merchant import Merchant
from app.features.reference_intelligence.services.merchant_archetype_service import MerchantArchetypeService
from app.schemas.common import APIResponse

router = APIRouter()


@router.get("/reference-intelligence/archetype", response_model=APIResponse)
def get_merchant_archetype(
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = MerchantArchetypeService(db)
    result = service.match_merchant_archetype(merchant.id)
    return APIResponse(
        success=True,
        message="Merchant archetype reference retrieved",
        data=result.model_dump(mode="json")
    )
