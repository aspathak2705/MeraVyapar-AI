from fastapi import APIRouter
from app.api.v1.endpoints import (
    health,
    merchants,
    business_profile,
    evidence,
    transaction_candidates,
    canonical_transactions,
    reconciliation,
    capture,
    counterparties,
    payment_promises,
    events,
    receivables,
    financial_intelligence,
    market_intelligence
)

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(merchants.router, tags=["merchants"])
api_router.include_router(business_profile.router, tags=["business-profile"])
api_router.include_router(evidence.router, tags=["evidence"])
api_router.include_router(transaction_candidates.router, tags=["transaction-candidates"])
api_router.include_router(canonical_transactions.router, tags=["canonical-transactions"])
api_router.include_router(reconciliation.router, tags=["reconciliation"])
api_router.include_router(capture.router, tags=["capture"])
api_router.include_router(counterparties.router, tags=["counterparties"])
api_router.include_router(payment_promises.router, tags=["payment-promises"])
api_router.include_router(events.router, tags=["events"])
api_router.include_router(receivables.router, tags=["receivables"])
api_router.include_router(financial_intelligence.router, tags=["financial-intelligence"])
api_router.include_router(market_intelligence.router, tags=["market-intelligence"])
