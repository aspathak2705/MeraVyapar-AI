from fastapi import APIRouter
from app.gateway.endpoints import (
    health,
    voice,
    voice_interaction,
    market_intelligence,
    market_retrieval,
    enrollment,
    financial_intelligence,
)

gateway_api_router = APIRouter()

# 1. Health & Readiness (Stateless)
gateway_api_router.include_router(health.router, tags=["health"])

# 2. Installation Enrollment (Stateless Session Token)
gateway_api_router.include_router(enrollment.router, tags=["enrollment"])

# 3. Voice Intelligence (Gnani Status, Synthesis, and Voice Interaction)
gateway_api_router.include_router(voice.router, tags=["voice"])
gateway_api_router.include_router(voice_interaction.router, tags=["voice-interaction"])

# 4. Market Intelligence (Internal Ingestion & Stateless Market Retrieval)
gateway_api_router.include_router(market_intelligence.router, tags=["market-intelligence"])
gateway_api_router.include_router(market_retrieval.router, tags=["market-retrieval"])

# 5. Financial Intelligence (Stateless Nemotron Grounded Reasoning)
gateway_api_router.include_router(financial_intelligence.router, tags=["financial-intelligence"])

