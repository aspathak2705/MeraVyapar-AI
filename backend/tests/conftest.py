import pytest
import uuid
from typing import Generator
from unittest.mock import MagicMock
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.main import app
from app.db.session import get_db
from app.dependencies.auth import get_current_user_id, get_current_merchant
from app.models.merchant import Merchant
from app.models.business_profile import BusinessProfile


class MockDBQuery:
    def __init__(self, data_store, model_cls):
        self.data_store = data_store
        self.model_cls = model_cls
        self.filters = []

    def filter(self, *criterion):
        self.filters.extend(criterion)
        return self

    def first(self):
        items = self.data_store.get(self.model_cls, [])
        for item in items:
            match = True
            for crit in self.filters:
                left = getattr(crit, "left", None)
                right = getattr(crit, "right", None)
                if left is not None and right is not None:
                    attr_name = left.name
                    val = getattr(right, "value", right)
                    if getattr(item, attr_name, None) != val:
                        match = False
                        break
            if match:
                return item
        return None


class MockDBSession:
    def __init__(self):
        self.store = {
            Merchant: [],
            BusinessProfile: []
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
