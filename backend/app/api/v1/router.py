from fastapi import APIRouter
from app.api.v1.endpoints import (
    health,
    merchants,
    business_profile,
    evidence,
    transaction_candidates,
    canonical_transactions,
    reconciliation
)

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(merchants.router, tags=["merchants"])
api_router.include_router(business_profile.router, tags=["business-profile"])
api_router.include_router(evidence.router, tags=["evidence"])
api_router.include_router(transaction_candidates.router, tags=["transaction-candidates"])
api_router.include_router(canonical_transactions.router, tags=["canonical-transactions"])
api_router.include_router(reconciliation.router, tags=["reconciliation"])
