from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.repositories.financial_event_repository import FinancialEventRepository
from app.features.events.services.financial_event_evaluation_service import FinancialEventEvaluationService
from app.features.financial_context.services.insight_staleness_service import InsightStalenessService
from app.schemas.financial_event import FinancialEventResponse, FinancialEventEvaluationResponse
from app.schemas.common import APIResponse
from app.models.merchant import Merchant
from app.models.financial_event import EventStatus, EventType
from app.core.exceptions import NotFoundError

router = APIRouter()


@router.post("/events/evaluate", response_model=APIResponse)
def evaluate_financial_events(
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = FinancialEventEvaluationService(db)
    result = service.evaluate_merchant_events(merchant.id)
    return APIResponse(
        success=True,
        message="Financial event evaluation pass completed",
        data=result.model_dump(mode="json")
    )


@router.get("/events", response_model=APIResponse)
def list_financial_events(
    status: Optional[EventStatus] = None,
    event_type: Optional[EventType] = None,
    skip: int = 0,
    limit: int = 50,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = FinancialEventRepository(db)
    events = repo.list_by_merchant(merchant.id, status=status, event_type=event_type, skip=skip, limit=limit)
    events_data = [FinancialEventResponse.model_validate(e).model_dump(mode="json") for e in events]
    return APIResponse(
        success=True,
        message="Financial events retrieved",
        data=events_data
    )


@router.get("/events/{id}", response_model=APIResponse)
def get_financial_event_detail(
    id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = FinancialEventRepository(db)
    event = repo.get_by_id(id, merchant.id)
    if not event:
        raise NotFoundError("Financial event not found")

    event_data = FinancialEventResponse.model_validate(event).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Financial event detail retrieved",
        data=event_data
    )


@router.post("/events/{id}/acknowledge", response_model=APIResponse)
def acknowledge_event(
    id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = FinancialEventRepository(db)
    event = repo.get_by_id(id, merchant.id)
    if not event:
        raise NotFoundError("Financial event not found")

    event.status = EventStatus.ACKNOWLEDGED
    db.commit()
    db.refresh(event)

    staleness_service = InsightStalenessService(db)
    staleness_service.on_event_changed(merchant.id, id)

    event_data = FinancialEventResponse.model_validate(event).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Event acknowledged",
        data=event_data
    )


@router.post("/events/{id}/dismiss", response_model=APIResponse)
def dismiss_event(
    id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = FinancialEventRepository(db)
    event = repo.get_by_id(id, merchant.id)
    if not event:
        raise NotFoundError("Financial event not found")

    event.status = EventStatus.DISMISSED
    db.commit()
    db.refresh(event)

    staleness_service = InsightStalenessService(db)
    staleness_service.on_event_changed(merchant.id, id)

    event_data = FinancialEventResponse.model_validate(event).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Event dismissed",
        data=event_data
    )


@router.post("/events/{id}/resolve", response_model=APIResponse)
def resolve_event(
    id: UUID,
    merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = FinancialEventRepository(db)
    event = repo.get_by_id(id, merchant.id)
    if not event:
        raise NotFoundError("Financial event not found")

    event.status = EventStatus.RESOLVED
    db.commit()
    db.refresh(event)

    staleness_service = InsightStalenessService(db)
    staleness_service.on_event_changed(merchant.id, id)

    event_data = FinancialEventResponse.model_validate(event).model_dump(mode="json")
    return APIResponse(
        success=True,
        message="Event resolved",
        data=event_data
    )
