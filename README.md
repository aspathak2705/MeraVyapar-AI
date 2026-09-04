# MeraVyapar AI

## Core Product Vision
MeraVyapar AI is an AI-powered Financial Intelligence Layer for merchants.

## Current Phase: Phase 0 — Foundation & Identity
This phase establishes the monorepo structure, core backend architecture (FastAPI + Supabase PostgreSQL), identity resolution, tenant authorization isolation, and Flutter application shell.

No financial transactions, ML models, forecasts, or mock financial data are included in Phase 0.

## Architecture Overview
```text
Flutter Mobile App (frontend/)
       │
       ▼
FastAPI Backend (backend/)
       │
       ▼
Supabase PostgreSQL & Auth
```

Prepared Ephemeral Infrastructure:
- Redis (Caching / Ephemeral State)
- Cloudflare R2 (Evidence Storage abstraction)

## Local Setup

### Backend Setup
1. Navigate to backend: `cd backend`
2. Configure `.env` from `.env.example`:
   `cp .env.example .env`
3. Install dependencies:
   `pip install -r requirements.txt`
4. Run migrations:
   `alembic upgrade head`
5. Run server:
   `uvicorn app.main:app --reload`

### Frontend Setup
1. Navigate to frontend: `cd frontend`
2. Fetch dependencies: `flutter pub get`
3. Run app: `flutter run`

## Explicit Phase Boundary
Financial processing, parsing, categorization, ML pipelines, and financial intelligence graph belong strictly to later phases. Phase 0 contains zero mock financial data or charts.
