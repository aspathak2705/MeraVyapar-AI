from uuid import UUID
from typing import List
from sqlalchemy.orm import Session
from app.repositories.transaction_candidate_repository import TransactionCandidateRepository
from app.repositories.canonical_transaction_repository import CanonicalTransactionRepository
from app.repositories.reconciliation_repository import ReconciliationRepository
from app.features.reconciliation.services.reconciliation_rule_engine import ReconciliationRuleEngine
from app.features.memory.services.financial_memory_service import FinancialMemoryService
from app.models.canonical_transaction import CanonicalTransaction, ReconciliationStatus
from app.models.transaction_candidate_link import LinkRelationshipType
from app.models.reconciliation_attempt import ReconciliationDecision
from app.models.financial_evidence import FinancialEvidence, EvidenceStrength
from app.models.transaction_candidate import TransactionType
from app.schemas.reconciliation import ReconciliationRunResponse


class ReconciliationService:
    def __init__(self, db: Session):
        self.db = db
        self.cand_repo = TransactionCandidateRepository(db)
        self.canonical_repo = CanonicalTransactionRepository(db)
        self.audit_repo = ReconciliationRepository(db)
        self.memory_service = FinancialMemoryService(db)

    def run_reconciliation(self, merchant_id: UUID) -> ReconciliationRunResponse:
        all_candidates = self.cand_repo.list_by_merchant(merchant_id, skip=0, limit=200)

        unlinked_candidates = [
            c for c in all_candidates
            if not self.canonical_repo.is_candidate_linked(c.id)
        ]

        candidates_examined = len(unlinked_candidates)
        canonical_created = 0
        reconciled_count = 0
        review_count = 0
        unresolved_count = 0

        processed_ids = set()

        for i in range(len(unlinked_candidates)):
            cand_a = unlinked_candidates[i]
            if cand_a.id in processed_ids:
                continue

            matched_b = None
            review_b = None

            for j in range(i + 1, len(unlinked_candidates)):
                cand_b = unlinked_candidates[j]
                if cand_b.id in processed_ids:
                    continue

                decision, reasons, snapshot = ReconciliationRuleEngine.evaluate_pair(cand_a, cand_b)

                if decision == ReconciliationDecision.MATCHED:
                    matched_b = (cand_b, reasons, snapshot)
                    break
                elif decision == ReconciliationDecision.REQUIRES_REVIEW and review_b is None:
                    review_b = (cand_b, reasons, snapshot)

            if matched_b:
                # 1. Strong Match -> Create Canonical Transaction (RECONCILED)
                cand_b, reasons, snapshot = matched_b
                canonical_tx = self.canonical_repo.create(
                    merchant_id=merchant_id,
                    amount=cand_a.amount or cand_b.amount,
                    currency=cand_a.currency or cand_b.currency,
                    transaction_type=cand_a.transaction_type if cand_a.transaction_type != TransactionType.UNKNOWN else cand_b.transaction_type,
                    payment_mode=cand_a.payment_mode if cand_a.payment_mode != "UNKNOWN" else cand_b.payment_mode,
                    counterparty_name=cand_a.counterparty_name or cand_b.counterparty_name,
                    transaction_reference=cand_a.reference_number or cand_b.reference_number,
                    occurred_at=cand_a.transaction_timestamp or cand_b.transaction_timestamp,
                    reconciliation_status=ReconciliationStatus.RECONCILED
                )

                self.canonical_repo.link_candidate(
                    merchant_id, canonical_tx.id, cand_a.id, LinkRelationshipType.PRIMARY
                )
                self.canonical_repo.link_candidate(
                    merchant_id, canonical_tx.id, cand_b.id, LinkRelationshipType.SUPPORTING
                )

                self.audit_repo.record_attempt(
                    merchant_id=merchant_id,
                    transaction_candidate_id=cand_a.id,
                    compared_candidate_id=cand_b.id,
                    canonical_transaction_id=canonical_tx.id,
                    decision=ReconciliationDecision.MATCHED,
                    reason_codes=reasons,
                    comparison_snapshot=snapshot
                )

                # Process Financial Memory Graph
                self.memory_service.process_canonical_transaction(canonical_tx)

                processed_ids.add(cand_a.id)
                processed_ids.add(cand_b.id)
                canonical_created += 1
                reconciled_count += 2

            elif review_b:
                # 2. Ambiguous / Conflicting Candidates -> Log Reconciliation Attempt (REQUIRES_REVIEW), NO Canonical Transaction created
                cand_b, reasons, snapshot = review_b

                self.audit_repo.record_attempt(
                    merchant_id=merchant_id,
                    transaction_candidate_id=cand_a.id,
                    compared_candidate_id=cand_b.id,
                    canonical_transaction_id=None,
                    decision=ReconciliationDecision.REQUIRES_REVIEW,
                    reason_codes=reasons,
                    comparison_snapshot=snapshot
                )

                processed_ids.add(cand_a.id)
                processed_ids.add(cand_b.id)
                review_count += 2

            else:
                # 3. Single candidate evaluation:
                evidence = cand_a.primary_evidence or self.db.query(FinancialEvidence).filter(
                    FinancialEvidence.id == cand_a.primary_evidence_id
                ).first()
                evidence_strength = evidence.evidence_strength if evidence else None

                is_strong_standalone = (
                    cand_a.amount is not None and
                    cand_a.transaction_type != TransactionType.UNKNOWN and
                    evidence_strength in (
                        EvidenceStrength.VERIFIED,
                        EvidenceStrength.STRONG,
                        EvidenceStrength.MERCHANT_DECLARED
                    )
                )

                if is_strong_standalone:
                    canonical_tx = self.canonical_repo.create(
                        merchant_id=merchant_id,
                        amount=cand_a.amount,
                        currency=cand_a.currency,
                        transaction_type=cand_a.transaction_type,
                        payment_mode=cand_a.payment_mode,
                        counterparty_name=cand_a.counterparty_name,
                        transaction_reference=cand_a.reference_number,
                        occurred_at=cand_a.transaction_timestamp,
                        reconciliation_status=ReconciliationStatus.UNRESOLVED
                    )
                    self.canonical_repo.link_candidate(
                        merchant_id, canonical_tx.id, cand_a.id, LinkRelationshipType.PRIMARY
                    )

                    self.audit_repo.record_attempt(
                        merchant_id=merchant_id,
                        transaction_candidate_id=cand_a.id,
                        canonical_transaction_id=canonical_tx.id,
                        decision=ReconciliationDecision.SKIPPED,
                        reason_codes=["STRONG_STANDALONE_CANDIDATE"]
                    )

                    # Process Financial Memory Graph
                    self.memory_service.process_canonical_transaction(canonical_tx)

                    canonical_created += 1
                    unresolved_count += 1
                else:
                    self.audit_repo.record_attempt(
                        merchant_id=merchant_id,
                        transaction_candidate_id=cand_a.id,
                        canonical_transaction_id=None,
                        decision=ReconciliationDecision.SKIPPED,
                        reason_codes=["WEAK_CANDIDATE_INELIGIBLE"]
                    )

                processed_ids.add(cand_a.id)

        return ReconciliationRunResponse(
            candidates_examined=candidates_examined,
            canonical_transactions_created=canonical_created,
            candidates_reconciled=reconciled_count,
            candidates_requiring_review=review_count,
            candidates_unresolved=unresolved_count
        )
