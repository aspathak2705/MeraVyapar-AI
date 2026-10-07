from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.repositories.evidence_repository import EvidenceRepository
from app.repositories.transaction_candidate_repository import TransactionCandidateRepository
from app.parsers.rule_based_transaction_parser import RuleBasedTransactionParser
from app.services.transaction_normalization_service import TransactionNormalizationService
from app.models.financial_evidence import FinancialEvidence, ProcessingStatus, EvidenceType, EvidenceSource
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

        # Step 1.1: Check if non-financial event (OTP, Cashback, Promo)
        if not parsed_result.is_financial_event:
            evidence.processing_status = ProcessingStatus.NOT_FINANCIAL_EVENT
            evidence.processed_at = datetime.now(timezone.utc)
            self.db.commit()
            self.db.refresh(evidence)
            return evidence

        # Step 1.2: Check if file evidence awaiting extraction
        if (
            evidence.evidence_type in (EvidenceType.PAYMENT_SCREENSHOT, EvidenceType.PAYMENT_RECEIPT) or
            evidence.evidence_source == EvidenceSource.USER_SHARED_FILE
        ):
            evidence.processing_status = ProcessingStatus.AWAITING_EXTRACTION
            evidence.processed_at = datetime.now(timezone.utc)
            self.db.commit()
            self.db.refresh(evidence)
            return evidence

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
            status = ProcessingStatus.REQUIRES_REVIEW

        evidence.processing_status = status
        evidence.processed_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(evidence)

        return evidence

    def process_extraction_submission(
        self,
        evidence: FinancialEvidence,
        extraction
    ) -> FinancialEvidence:
        from decimal import Decimal, InvalidOperation
        from app.parsers.base import ParsedTransactionResult
        from app.models.transaction_candidate import TransactionType

        # Verify integrity hash matches registered evidence metadata
        registered_sha256 = (evidence.metadata_info or {}).get("client_sha256")
        if registered_sha256 and extraction.client_sha256.lower() != registered_sha256.lower():
            from app.core.exceptions import ValidationError
            raise ValidationError("Integrity check failed: submission hash does not match registered evidence hash")

        self.evidence_repo.update_status(evidence, ProcessingStatus.PROCESSING)

        # Parse amount safely
        amount_val = None
        if extraction.amount:
            try:
                amount_val = Decimal(str(extraction.amount).replace(",", ""))
            except (InvalidOperation, ValueError):
                amount_val = None

        parsed_result = ParsedTransactionResult(
            amount=amount_val,
            currency=extraction.currency or "INR",
            transaction_type=extraction.transaction_type or TransactionType.UNKNOWN,
            counterparty_name=extraction.counterparty_name,
            payment_mode=extraction.payment_mode or PaymentMode.UNKNOWN,
            reference_number=extraction.reference_number,
            description=extraction.description or extraction.extracted_text,
            parse_success=True if amount_val is not None else False,
            parse_status_message=f"Extracted on-device via {extraction.extraction_engine}",
            is_financial_event=True
        )

        normalized_result = TransactionNormalizationService.normalize_parsed_result(parsed_result)

        existing_candidate = self.candidate_repo.get_by_evidence_id(evidence.id, evidence.merchant_id)
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
                description=normalized_result.description,
                normalization_status=NormalizationStatus.NORMALIZED if normalized_result.parse_success else NormalizationStatus.PENDING,
                review_status=ReviewStatus.NOT_REQUIRED if normalized_result.parse_success else ReviewStatus.REQUIRES_REVIEW
            )

        # Update metadata info with extraction details
        meta = dict(evidence.metadata_info or {})
        meta["extraction_details"] = {
            "engine": extraction.extraction_engine,
            "confidence": extraction.confidence,
            "extracted_text": extraction.extracted_text,
            "processed_at": datetime.now(timezone.utc).isoformat()
        }
        evidence.metadata_info = meta
        if extraction.extracted_text:
            evidence.raw_text = extraction.extracted_text

        status = ProcessingStatus.PARSED if normalized_result.parse_success else ProcessingStatus.REQUIRES_REVIEW
        evidence.processing_status = status
        evidence.processed_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(evidence)
        return evidence

