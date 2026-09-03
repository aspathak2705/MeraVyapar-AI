from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.features.reconciliation.services.reconciliation_service import ReconciliationService
from app.schemas.reconciliation import ReconciliationRunResponse
from app.schemas.common import APIResponse
from app.models.merchant import Merchant

router = APIRouter()


@router.post("/reconciliation/run", response_model=APIResponse)
def run_merchant_reconciliation(
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = ReconciliationService(db)
    result: ReconciliationRunResponse = service.run_reconciliation(merchant.id)
    return APIResponse(
        success=True,
        message="Reconciliation run executed successfully",
        data=result.model_dump(mode="json")
    )
