from uuid import UUID
from decimal import Decimal
from datetime import datetime
from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.canonical_transaction import CanonicalTransaction, ReconciliationStatus
from app.models.transaction_candidate_link import TransactionCandidateLink, LinkRelationshipType
from app.models.transaction_candidate import TransactionCandidate, TransactionType, PaymentMode


class CanonicalTransactionRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, canonical_id: UUID, merchant_id: UUID) -> Optional[CanonicalTransaction]:
        return self.db.query(CanonicalTransaction).filter(
            CanonicalTransaction.id == canonical_id,
            CanonicalTransaction.merchant_id == merchant_id
        ).first()

    def list_by_merchant(
        self,
        merchant_id: UUID,
        skip: int = 0,
        limit: int = 50
    ) -> List[CanonicalTransaction]:
        return self.db.query(CanonicalTransaction).filter(
            CanonicalTransaction.merchant_id == merchant_id
        ).order_by(CanonicalTransaction.created_at.desc()).offset(skip).limit(limit).all()

    def is_candidate_linked(self, candidate_id: UUID) -> bool:
        link = self.db.query(TransactionCandidateLink).filter(
            TransactionCandidateLink.transaction_candidate_id == candidate_id
        ).first()
        return link is not None

    def create(
        self,
        merchant_id: UUID,
        amount: Optional[Decimal],
        currency: str = "INR",
        transaction_type: TransactionType = TransactionType.UNKNOWN,
        payment_mode: PaymentMode = PaymentMode.UNKNOWN,
        counterparty_name: Optional[str] = None,
        transaction_reference: Optional[str] = None,
        occurred_at: Optional[datetime] = None,
        reconciliation_status: ReconciliationStatus = ReconciliationStatus.UNRESOLVED,
        source_type: Optional[str] = None,
        source_provider: Optional[str] = None,
        is_simulated: bool = False
    ) -> CanonicalTransaction:
        tx = CanonicalTransaction(
            merchant_id=merchant_id,
            amount=amount,
            currency=currency,
            transaction_type=transaction_type,
            payment_mode=payment_mode,
            counterparty_name=counterparty_name,
            transaction_reference=transaction_reference,
            occurred_at=occurred_at,
            reconciliation_status=reconciliation_status,
            source_type=source_type,
            source_provider=source_provider,
            is_simulated=is_simulated
        )
        if not hasattr(tx, "candidate_links") or tx.candidate_links is None:
            tx.candidate_links = []
        self.db.add(tx)
        self.db.commit()
        self.db.refresh(tx)
        return tx

    def link_candidate(
        self,
        merchant_id: UUID,
        canonical_transaction_id: UUID,
        transaction_candidate_id: UUID,
        relationship_type: LinkRelationshipType = LinkRelationshipType.PRIMARY,
        linked_by: str = "SYSTEM_RECONCILIATION"
    ) -> TransactionCandidateLink:
        cand_obj = self.db.query(TransactionCandidate).filter(
            TransactionCandidate.id == transaction_candidate_id
        ).first()

        link = TransactionCandidateLink(
            merchant_id=merchant_id,
            canonical_transaction_id=canonical_transaction_id,
            transaction_candidate_id=transaction_candidate_id,
            relationship_type=relationship_type,
            linked_by=linked_by
        )
        link.candidate = cand_obj

        self.db.add(link)

        # Attach link to canonical_transaction instance if in memory
        canonical_tx = self.db.query(CanonicalTransaction).filter(
            CanonicalTransaction.id == canonical_transaction_id
        ).first()
        if canonical_tx:
            if not hasattr(canonical_tx, "candidate_links") or canonical_tx.candidate_links is None:
                canonical_tx.candidate_links = []
            if link not in canonical_tx.candidate_links:
                canonical_tx.candidate_links.append(link)

        self.db.commit()
        self.db.refresh(link)
        return link

    def update_status(
        self,
        tx: CanonicalTransaction,
        status: ReconciliationStatus
    ) -> CanonicalTransaction:
        tx.reconciliation_status = status
        self.db.commit()
        self.db.refresh(tx)
        return tx
