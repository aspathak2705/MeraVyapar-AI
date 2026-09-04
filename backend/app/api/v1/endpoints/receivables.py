from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.features.events.services.receivables_prioritization_service import ReceivablesPrioritizationService
from app.schemas.receivable import PrioritizedReceivableResponse
from app.schemas.common import APIResponse
from app.models.merchant import Merchant

router = APIRouter()


@router.get("/receivables/prioritized", response_model=APIResponse)
def get_prioritized_receivables(
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = ReceivablesPrioritizationService(db)
    receivables = service.get_prioritized_receivables(merchant.id)
    receivables_data = [r.model_dump(mode="json") for r in receivables]
    return APIResponse(
        success=True,
        message="Prioritized receivables retrieved",
        data=receivables_data
    )
