from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field

from app.db.session import get_db
from app.dependencies.auth import get_current_merchant
from app.models.merchant import Merchant
from app.models.communication_action import ActionStatus, CommunicationChannel
from app.repositories.communication_action_repository import CommunicationActionRepository
from app.features.actions.services.reminder_draft_service import ReminderDraftService
from app.features.actions.services.action_workflow_service import ActionWorkflowService
from app.features.actions.services.action_dispatch_service import ActionDispatchService
from app.schemas.communication_action import (
    CommunicationActionResponse,
    CommunicationActionDraftRequest,
    CommunicationActionUpdateRequest,
    CommunicationActionConfirmRequest,
    CommunicationAuditEventResponse
)

router = APIRouter(prefix="/actions", tags=["Communication Actions"])


@router.post("/draft-reminder", response_model=CommunicationActionResponse, status_code=status.HTTP_201_CREATED)
def draft_payment_reminder(
    payload: CommunicationActionDraftRequest,
    current_merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = ReminderDraftService(db)
    try:
        channel_enum = CommunicationChannel(payload.channel.upper())

        action, _ = service.draft_payment_reminder(
            merchant_id=str(current_merchant.id),
            promise_id=str(payload.promise_id),
            channel=channel_enum
        )
        return action
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("", response_model=List[CommunicationActionResponse])
def list_actions(
    status_filter: Optional[str] = Query(None, alias="status"),
    current_merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = CommunicationActionRepository(db)
    parsed_status = None
    if status_filter:
        try:
            parsed_status = ActionStatus(status_filter.lower())
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid status: {status_filter}")

    return repo.list_for_merchant(str(current_merchant.id), status_filter=parsed_status)


@router.get("/{action_id}", response_model=CommunicationActionResponse)
def get_action(
    action_id: str,
    current_merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = CommunicationActionRepository(db)
    action = repo.get_by_id(str(current_merchant.id), action_id)
    if not action:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Action not found")
    return action


@router.patch("/{action_id}", response_model=CommunicationActionResponse)
def update_action_draft(
    action_id: str,
    payload: CommunicationActionUpdateRequest,
    current_merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = ActionWorkflowService(db)
    try:
        return service.update_draft(
            merchant_id=str(current_merchant.id),
            action_id=action_id,
            final_content=payload.final_content,
            recipient_info=payload.recipient_info
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{action_id}/confirm", response_model=CommunicationActionResponse)
def confirm_action(
    action_id: str,
    current_merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = ActionWorkflowService(db)
    try:
        return service.confirm_action(
            merchant_id=str(current_merchant.id),
            action_id=action_id
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{action_id}/cancel", response_model=CommunicationActionResponse)
def cancel_action(
    action_id: str,
    current_merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = ActionWorkflowService(db)
    try:
        return service.cancel_action(
            merchant_id=str(current_merchant.id),
            action_id=action_id
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{action_id}/dispatch", response_model=CommunicationActionResponse)
def dispatch_action(
    action_id: str,
    current_merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    service = ActionDispatchService(db)
    try:
        return service.dispatch_action(
            merchant_id=str(current_merchant.id),
            action_id=action_id
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{action_id}/audit-trail", response_model=List[CommunicationAuditEventResponse])
def get_audit_trail(
    action_id: str,
    current_merchant: Merchant = Depends(get_current_merchant),
    db: Session = Depends(get_db)
):
    repo = CommunicationActionRepository(db)
    # verify action ownership first
    action = repo.get_by_id(str(current_merchant.id), action_id)
    if not action:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Action not found")

    return repo.list_audit_events(action_id)

