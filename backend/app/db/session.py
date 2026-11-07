from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator, Optional
from app.core.config import settings

# Safe lazy engine creation: prevents startup crash if DATABASE_URL is not set
_engine = None
_SessionLocal = None

def get_engine():
    global _engine, _SessionLocal
    if _engine is None:
        db_url = settings.DATABASE_URL or "postgresql://postgres:postgrespassword@localhost:5432/meravyapar_db"
        _engine = create_engine(db_url, pool_pre_ping=True, echo=False)
        _SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_engine)
    return _engine

def get_sessionmaker():
    if _SessionLocal is None:
        get_engine()
    return _SessionLocal

def get_db() -> Generator[Session, None, None]:
    session_factory = get_sessionmaker()
    db = session_factory()
    try:
        yield db
    finally:
        db.close()
