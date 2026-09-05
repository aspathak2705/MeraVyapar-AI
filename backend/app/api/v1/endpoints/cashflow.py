from uuid import UUID
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.models.merchant import Merchant
from app.features.cashflow_intelligence.services.cashflow_forecast_service import CashFlowForecastService
from app.features.cashflow_intelligence.domain.cashflow_forecast import CashFlowForecastResponse
from app.schemas.common import APIResponse

router = APIRouter()


@router.get("/cashflow/forecast", response_model=APIResponse)
def get_cashflow_forecast(
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = CashFlowForecastService(db)
    forecast_res = service.generate_forecast(merchant.id)
    return APIResponse(
        success=True,
        message="Cash flow forecast retrieved",
        data=forecast_res.model_dump(mode="json")
    )


@router.get("/cashflow/scenarios", response_model=APIResponse)
def get_cashflow_scenarios(
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = CashFlowForecastService(db)
    forecast_res = service.generate_forecast(merchant.id)
    return APIResponse(
        success=True,
        message="Cash flow scenarios retrieved",
        data={
            "status": forecast_res.status,
            "scenarios": [s.model_dump(mode="json") for s in forecast_res.scenarios]
        }
    )
