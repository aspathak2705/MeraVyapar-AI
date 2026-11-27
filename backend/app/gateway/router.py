from fastapi import APIRouter
from app.gateway.endpoints import (
    health,
    enrollment,
)

gateway_api_router = APIRouter()

# 1. Health & Readiness (Stateless)
gateway_api_router.include_router(health.router, tags=["health"])

# 2. Installation Enrollment (Stateless Session Token)
gateway_api_router.include_router(enrollment.router, tags=["enrollment"])
