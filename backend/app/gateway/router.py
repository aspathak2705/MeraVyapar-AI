from fastapi import APIRouter
from app.gateway.endpoints import health, voice, market_intelligence, enrollment

gateway_api_router = APIRouter()

# 1. Health & Readiness (Stateless)
gateway_api_router.include_router(health.router, tags=["health"])

# 2. Installation Enrollment (Stateless Session Token)
gateway_api_router.include_router(enrollment.router, tags=["enrollment"])

# 3. Voice Intelligence (Gnani STT / TTS)
gateway_api_router.include_router(voice.router, tags=["voice"])

# 4. Market Intelligence (Internal Ingestion & Retrieval Gateway)
gateway_api_router.include_router(market_intelligence.router, tags=["market-intelligence"])

