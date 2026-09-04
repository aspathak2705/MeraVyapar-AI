import pytest
import uuid
from typing import Generator
from unittest.mock import MagicMock
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.main import app
from app.db.session import get_db
from app.models.merchant import Merchant
from app.models.business_profile import BusinessProfile
from app.models.financial_evidence import FinancialEvidence
from app.models.transaction_candidate import TransactionCandidate
from app.models.idempotency_record import IdempotencyRecord
from app.models.canonical_transaction import CanonicalTransaction
from app.models.transaction_candidate_link import TransactionCandidateLink
from app.models.reconciliation_attempt import ReconciliationAttempt
from app.models.capture_source_setting import CaptureSourceSetting
from app.models.financial_counterparty import (
    FinancialCounterparty,
    CounterpartyAlias,
    MerchantCounterpartyRelationship,
    TransactionCounterpartyLink as MemoryTransactionCounterpartyLink,
    FinancialRelationshipEvent
)
from app.models.payment_promise import PaymentPromise, PaymentPromiseEvent
from app.models.financial_event import FinancialEvent
from app.models.generated_insight import GeneratedInsight
from app.models.market_source import MarketSource
from app.models.market_event import MarketEvent
from app.models.merchant_market_relevance import MerchantMarketRelevance
from app.models.communication_action import CommunicationAction
from app.models.communication_action_event import CommunicationAuditEvent


class MockDBQuery:
    def __init__(self, data_store, model_cls):
        self.data_store = data_store
        self.model_cls = model_cls
        self.filters = []

    def filter(self, *criterion):
        self.filters.extend(criterion)
        return self

    def order_by(self, *args):
        return self

    def offset(self, skip: int):
        return self

    def limit(self, limit: int):
        return self

    def all(self):
        items = self.data_store.get(self.model_cls, [])
        result = []
        for item in items:
            match = True
            for crit in self.filters:
                left = getattr(crit, "left", None)
                right = getattr(crit, "right", None)
                if left is not None and right is not None:
                    attr_name = getattr(left, "name", None)
                    val = getattr(right, "value", right)
                    if attr_name:
                        item_val = getattr(item, attr_name, None)
                        if isinstance(item_val, uuid.UUID) or isinstance(val, uuid.UUID):
                            if str(item_val) != str(val):
                                match = False
                                break
                        elif item_val != val:
                            match = False
                            break
            if match:
                result.append(item)
        return result

    def first(self):
        matches = self.all()
        return matches[0] if matches else None


class MockDBSession:
    def __init__(self):
        self.store = {
            Merchant: [],
            BusinessProfile: [],
            FinancialEvidence: [],
            TransactionCandidate: [],
            IdempotencyRecord: [],
            CanonicalTransaction: [],
            TransactionCandidateLink: [],
            ReconciliationAttempt: [],
            CaptureSourceSetting: [],
            FinancialCounterparty: [],
            CounterpartyAlias: [],
            MerchantCounterpartyRelationship: [],
            MemoryTransactionCounterpartyLink: [],
            FinancialRelationshipEvent: [],
            PaymentPromise: [],
            PaymentPromiseEvent: [],
            FinancialEvent: [],
            GeneratedInsight: [],
            MarketSource: [],
            MarketEvent: [],
            MerchantMarketRelevance: [],
            CommunicationAction: [],
            CommunicationAuditEvent: []
        }

    def query(self, model_cls):
        return MockDBQuery(self.store, model_cls)

    def add(self, instance):
        if not hasattr(instance, "id") or instance.id is None:
            instance.id = uuid.uuid4()
        cls = type(instance)
        if cls not in self.store:
            self.store[cls] = []
        self.store[cls].append(instance)

    def commit(self):
        pass

    def refresh(self, instance):
        pass

    def execute(self, statement):
        return MagicMock()

    def close(self):
        pass


@pytest.fixture
def db_session() -> Generator[Session, None, None]:
    mock_db = MockDBSession()
    yield mock_db


@pytest.fixture
def client(db_session: Session) -> Generator[TestClient, None, None]:
    def _get_test_db():
        yield db_session

    app.dependency_overrides[get_db] = _get_test_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
