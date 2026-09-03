from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.repositories.evidence_repository import EvidenceRepository
from app.repositories.transaction_candidate_repository import TransactionCandidateRepository
from app.parsers.rule_based_transaction_parser import RuleBasedTransactionParser
from app.services.transaction_normalization_service import TransactionNormalizationService
from app.models.financial_evidence import FinancialEvidence, ProcessingStatus
from app.models.transaction_candidate import (
    TransactionCandidate,
    NormalizationStatus,
    ReviewStatus
)


class EvidenceProcessingService:
    def __init__(self, db: Session):
        self.db = db
        self.evidence_repo = EvidenceRepository(db)
        self.candidate_repo = TransactionCandidateRepository(db)
        self.parser = RuleBasedTransactionParser()

    def process_evidence(self, evidence: FinancialEvidence) -> FinancialEvidence:
        self.evidence_repo.update_status(evidence, ProcessingStatus.PROCESSING)

        # Step 1: Parse evidence using selected parser
        parsed_result = self.parser.parse(evidence)

        # Step 2: Normalize parsed result
        normalized_result = TransactionNormalizationService.normalize_parsed_result(parsed_result)

        # Step 3: Check if candidate already exists for this primary evidence
        existing_candidate = self.candidate_repo.get_by_evidence_id(evidence.id, evidence.merchant_id)

        # Step 4: Create or update candidate if parsing was successful or partial
        if normalized_result.parse_success or normalized_result.amount is not None or normalized_result.counterparty_name:
            if not existing_candidate:
                self.candidate_repo.create(
                    merchant_id=evidence.merchant_id,
                    primary_evidence_id=evidence.id,
                    transaction_type=normalized_result.transaction_type,
                    amount=normalized_result.amount,
                    currency=normalized_result.currency,
                    transaction_timestamp=normalized_result.transaction_timestamp or evidence.received_at,
                    counterparty_name=normalized_result.counterparty_name,
                    payment_mode=normalized_result.payment_mode,
                    reference_number=normalized_result.reference_number,
                    description=normalized_result.description or evidence.raw_text,
                    normalization_status=NormalizationStatus.NORMALIZED if normalized_result.parse_success else NormalizationStatus.PENDING,
                    review_status=ReviewStatus.NOT_REQUIRED if normalized_result.parse_success else ReviewStatus.REQUIRES_REVIEW
                )
            status = ProcessingStatus.PARSED if normalized_result.parse_success else ProcessingStatus.REQUIRES_REVIEW
        else:
            # File evidence or ambiguous text requiring future extraction/review
            status = ProcessingStatus.REQUIRES_REVIEW

        evidence.processing_status = status
        evidence.processed_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(evidence)

        return evidence
