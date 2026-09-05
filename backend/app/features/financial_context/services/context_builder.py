from uuid import UUID
from typing import Optional
from sqlalchemy.orm import Session
from app.repositories.financial_event_repository import FinancialEventRepository
from app.repositories.payment_promise_repository import PaymentPromiseRepository
from app.repositories.counterparty_repository import CounterpartyRepository
from app.features.financial_context.services.financial_facts_service import FinancialFactsService
from app.features.events.services.receivables_prioritization_service import ReceivablesPrioritizationService
from app.schemas.financial_context import FinancialContextPackage, InsightSourceReference
from app.models.financial_event import EventStatus


class FinancialContextBuilder:
    def __init__(self, db: Session):
        self.db = db
        self.event_repo = FinancialEventRepository(db)
        self.promise_repo = PaymentPromiseRepository(db)
        self.counterparty_repo = CounterpartyRepository(db)
        self.facts_service = FinancialFactsService(db)
        self.receivables_service = ReceivablesPrioritizationService(db)

    def build_event_explanation_context(self, merchant_id: UUID, event_id: UUID) -> Optional[FinancialContextPackage]:
        event = self.event_repo.get_by_id(event_id, merchant_id)
        if not event:
            return None

        provenance = [
            InsightSourceReference(
                entity_type="financial_event",
                entity_id=str(event.id),
                label=f"Event: {event.title}"
            )
        ]

        promises_data = []
        if event.source_entity_type == "payment_promise" and event.source_entity_id:
            promise = self.promise_repo.get_by_id(event.source_entity_id, merchant_id)
            if promise:
                promises_data.append({
                    "id": str(promise.id),
                    "description": promise.description,
                    "promised_amount": str(promise.promised_amount),
                    "currency": promise.currency,
                    "due_at": promise.due_at.isoformat() if promise.due_at else None,
                    "status": promise.status.value,
                    "source": promise.source.value
                })
                provenance.append(
                    InsightSourceReference(
                        entity_type="payment_promise",
                        entity_id=str(promise.id),
                        label=f"Promise: ₹{promise.promised_amount} due {promise.due_at.strftime('%d %b %Y') if promise.due_at else ''}"
                    )
                )

        facts = self.facts_service.compute_merchant_facts(merchant_id)

        return FinancialContextPackage(
            context_version="1.0",
            merchant_id=merchant_id,
            focus_type="EVENT",
            focus_entity_id=event_id,
            events=[{
                "id": str(event.id),
                "event_type": event.event_type.value,
                "severity": event.severity.value,
                "status": event.status.value,
                "title": event.title,
                "summary": event.summary,
                "occurred_at": event.occurred_at.isoformat() if event.occurred_at else None,
                "reason_code": event.metadata_info.get("reason_code", "SYSTEM_EVENT")
            }],
            payment_promises=promises_data,
            computed_metrics=facts,
            provenance_sources=provenance
        )

    def build_general_query_context(self, merchant_id: UUID, focus_entity_id: Optional[UUID] = None) -> FinancialContextPackage:
        events = self.event_repo.list_by_merchant(merchant_id, status=EventStatus.ACTIVE, skip=0, limit=10)
        receivables = self.receivables_service.get_prioritized_receivables(merchant_id)
        facts = self.facts_service.compute_merchant_facts(merchant_id)

        provenance = []
        events_data = []
        for e in events:
            events_data.append({
                "id": str(e.id),
                "event_type": e.event_type.value,
                "severity": e.severity.value,
                "title": e.title,
                "summary": e.summary
            })
            provenance.append(InsightSourceReference(entity_type="financial_event", entity_id=str(e.id), label=e.title))

        receivables_data = []
        for r in receivables[:5]:
            receivables_data.append(r.model_dump(mode="json"))
            provenance.append(InsightSourceReference(entity_type="payment_promise", entity_id=r.source_payment_promise_id, label=f"Receivable: ₹{r.amount} ({r.state})"))

        # Reference Archetype Context
        from app.features.reference_intelligence.services.merchant_archetype_service import MerchantArchetypeService
        arch_service = MerchantArchetypeService(self.db)
        arch_match = arch_service.match_merchant_archetype(merchant_id)

        ref_ctx = None
        if arch_match.status == "AVAILABLE" and arch_match.matched_archetype:
            ref_ctx = {
                "source_type": "SYNTHETIC_REFERENCE_PATTERN",
                "not_merchant_evidence": True,
                "merchant_archetype": arch_match.matched_archetype.model_dump(mode="json"),
                "reference_patterns": arch_match.reference_patterns
            }

        return FinancialContextPackage(
            context_version="2.0",
            merchant_id=merchant_id,
            focus_type="GENERAL",
            focus_entity_id=focus_entity_id,
            events=events_data,
            receivables=receivables_data,
            computed_metrics=facts,
            reference_context=ref_ctx,
            provenance_sources=provenance
        )
