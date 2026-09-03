from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Optional
from app.models.financial_evidence import FinancialEvidence
from app.models.transaction_candidate import TransactionType, PaymentMode


@dataclass
class ParsedTransactionResult:
    amount: Optional[Decimal] = None
    currency: str = "INR"
    transaction_type: TransactionType = TransactionType.UNKNOWN
    counterparty_name: Optional[str] = None
    payment_mode: PaymentMode = PaymentMode.UNKNOWN
    transaction_timestamp: Optional[datetime] = None
    reference_number: Optional[str] = None
    description: Optional[str] = None
    parse_success: bool = False
    parse_status_message: str = "Unparsed"
    is_financial_event: bool = True


class TransactionParser(ABC):
    @abstractmethod
    def parse(self, evidence: FinancialEvidence) -> ParsedTransactionResult:
        """
        Parses given evidence entity.
        Must NOT fabricate values if extraction is ambiguous.
        """
        pass
