from fastapi import APIRouter
from app.api.v1.endpoints import health, merchants, business_profile

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(merchants.router, tags=["merchants"])
api_router.include_router(business_profile.router, tags=["business-profile"])
