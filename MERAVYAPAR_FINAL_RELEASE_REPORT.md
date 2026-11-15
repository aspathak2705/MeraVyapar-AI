# MERAVYAPAR AI — FINAL PRESENT-STATE AUDIT, REPAIR, TEST & PRODUCTION RELEASE REPORT

**Audit & Release Timestamp:** 2026-11-15T12:35:00+05:30  
**Repository Working Branch:** `main` (clean baseline)  
**Auditor:** Antigravity Autonomous Lead  
**Canonical Local Database:** `meravyapar_local.db` (Schema Version: 5)  
**Production Gateway Host:** Render Singapore (`https://meravyapar-ai-gateway.onrender.com/api/v1`)  
**Production APK Path:** `frontend/build/app/outputs/flutter-apk/app-release.apk`  
**APK SHA-256:** `E331FF5BFCDEF71F8FF276F0857B4AFF179DB5E4D033F4E31F9BA9AE5BBB4D45`  
**Build Status:** **VERIFIED & BUILT (Exit Code 0, 53.4 MB)**  

---

## 1. Executive Summary & Verdict

- **Canonical Authority**: Device SQLite (`meravyapar_local.db`) remains the sole source of truth for financial records. Core ledger operations (income, expense, promises, counterparties, receivables, payables, FIG, KharidSaathi landed cost) run 100% offline without database sync to cloud PostgreSQL or Supabase.
- **Production Gateway Decoupling**: Render runs `backend/app/gateway_main.py` launching a stateless FastAPI gateway (`meravyapar-ai-gateway`).
- **Defect Repaired — Nemotron Grounding**: Eliminated placeholder context in `backend/app/gateway/endpoints/financial_intelligence.py`. The endpoint accepts sanitized context snapshots (`events`, `payment_promises`, `receivables`, `computed_metrics`) without uploading raw ledger databases or private evidence.
- **Defect Repaired — API Client Reliability**: Hardened `frontend/lib/core/api/api_client.dart` with explicit 15-second request timeouts, structured error handling (`NETWORK_ERROR`, `MALFORMED_RESPONSE`), and HTTP status mapping.
- **Live Render Status**: Live probe to `https://meravyapar-ai-gateway.onrender.com/api/v1/health` and `/api/v1/auth/enroll` returns **HTTP 404**. Render service is either stopped/un-deployed or running legacy container. **Dashboard action required to trigger deployment of `render.yaml` with `rootDir: backend`.**

---

## 2. Workspace & Toolchain Inventory

- **Repository Root**: `C:\Users\athar\OneDrive\Documents\projects\MeraVyapar AI`
- **Flutter SDK**: `3.47.1` (stable channel, revision `6655482ec0`)
- **Dart SDK**: `3.13.1`
- **Python**: `3.10.11`
- **Android SDK**: `36.0.0` (Target SDK: `36`, Min SDK: `21`)
- **Gradle**: `8.3` (AGP `8.3.2`)
- **Package ID**: `com.example.frontend`

---

## 3. Render.yaml & Backend Architecture Audit

### Configuration Review: `render.yaml`
- `name`: `meravyapar-ai-gateway`
- `rootDir`: `backend`
- `startCommand`: `uvicorn app.gateway_main:app --host 0.0.0.0 --port $PORT --workers 2 --timeout-keep-alive 30`
- `buildCommand`: `pip install -r requirements.txt`
- `envVars`: Configured for stateless mode with explicit base URLs for Gnani (`https://api.vachana.ai`), SerpApi (`https://serpapi.com/search`), and OpenRouter (`https://openrouter.ai/api/v1`).
- `secrets`: Declares references for `GNANI_API_KEY`, `SERPAPI_API_KEY`, `OPENROUTER_API_KEY`, and `INTERNAL_INGEST_API_KEY`. No literal keys embedded in YAML.

### Registered Stateless Gateway Routes (`/api/v1`):
1. `GET /api/v1/health`: Gateway liveness and AI provider configuration flags.
2. `POST /api/v1/auth/enroll`: Issues short-lived gateway bearer tokens bound to installation UUID.
3. `GET /api/v1/voice/status`: Gnani speech stack status probe.
4. `POST /api/v1/voice/interact`: Multipart audio STT (Prisma v2.5) → Intent Classification → TTS (Timbre v2.5).
5. `POST /api/v1/voice/synthesize`: Direct speech synthesis returning WAV bytes.
6. `GET /api/v1/market-intelligence/relevant`: Profile-derived SerpApi multi-engine search with 24-hr caching.
7. `POST /api/v1/financial-intelligence/query`: Grounded Nemotron financial reasoning over sanitized device context.

---

## 4. AI Provider Integration Status

| Provider | Model / Endpoint | Mode | Local & Adapter Verification | Production Deployment Status |
|---|---|---|---|---|
| **Gnani Voice STT** | Prisma v2.5 (`https://api.vachana.ai/api/v1/stt/inference`) | Production Proxy | **PASS (8/8 tests passed)** in `test_gnani_speech_adapters.py` | **BLOCKED** by Render deployment 404 |
| **Gnani Voice TTS** | Timbre v2.5 (`https://api.vachana.ai/api/v1/tts/inference`) | Production Proxy | **PASS** (66KB audio synthesized in adapter test) | **BLOCKED** by Render deployment 404 |
| **SerpApi Market** | Google Search, Shopping, News (`https://serpapi.com/search`) | Production Proxy | **PASS (9/9 tests passed)** in `test_market_retrieval_gateway.py` | **BLOCKED** by Render deployment 404 |
| **OpenRouter / Nemotron** | `nvidia/nemotron-3-super-120b-a12b:free` | Production Proxy | **PASS (2/2 tests passed)** in `test_grounded_evidence_fusion.py` | **BLOCKED** by Render deployment 404 |

---

## 5. Automated Verification Battery

### Backend Pytest Suite:
- **Command**: `python -m pytest tests/services/ tests/test_market_retrieval_gateway.py -q`
- **Results**: **68 passed in 1.66s**
- **Coverage**: Gnani STT/TTS adapters, SerpApi client caching and query building, Nemotron grounded evidence fusion, simulated payment HMAC protection, and financial event research planner.

### Flutter Test Suite:
- **Command**: `flutter test`
- **Results**: **36 passed in 4.0s**
- **Coverage**:
  - Encrypted backup container & PBKDF2-HMAC-SHA256 key derivation (2 tests)
  - SQLite V5 schema & additive migration (2 tests)
  - Integer paise invariants & cash movement arithmetic (3 tests)
  - Notification extraction & merchant business profile SQLite persistence (3 tests)
  - Android permission lifecycle & rationale handling (3 tests)
  - KharidSaathi landed cost integer paise calculation & quote comparison (10 tests)
  - SpendSense SMS intelligence, UTR extraction, tombstones & Tier 0 overrides (6 tests)
  - HemoPI local file storage, SHA-256 verification, traversal rejection, safe deletion (4 tests)
  - Full architecture runtime integration & FIG graph derivation (3 tests)

### Flutter Static Analysis:
- **Command**: `flutter analyze`
- **Results**: **0 errors** (92 deprecation/style warnings).

---

## 6. Final Production Release APK Verification

- **Artifact Path**: `frontend/build/app/outputs/flutter-apk/app-release.apk`
- **File Size**: `55,983,510 bytes` (~53.4 MB)
- **SHA-256 Checksum**: `E331FF5BFCDEF71F8FF276F0857B4AFF179DB5E4D033F4E31F9BA9AE5BBB4D45`
- **Build Mode**: Release (`--release`)
- **Gateway Base URL**: `https://meravyapar-ai-gateway.onrender.com/api/v1` (Compile-time `--dart-define=API_BASE_URL=...`)
- **Target SDK**: 36 | **Min SDK**: 21
- **Package ID**: `com.example.frontend`
- **Network Security**: Zero localhost, zero `127.0.0.1`, zero `adb reverse`.
- **Offline Readiness**: All core financial ledgers run 100% offline against local SQLite.

---

## 7. Remaining Production Deployment Blocker & Required Action

- **Observed Blocker**: Deployed Render URL `https://meravyapar-ai-gateway.onrender.com/` returns **HTTP 404**.
- **Root Cause**: The current Render service deployment has not been synced or triggered with root `render.yaml` (`rootDir: backend`, startCommand: `uvicorn app.gateway_main:app`).
- **Required Action in Render Dashboard**:
  1. Open Render Dashboard → `meravyapar-ai-gateway`.
  2. In **Settings**, ensure **Root Directory** is set to `backend` and **Start Command** is set to `uvicorn app.gateway_main:app --host 0.0.0.0 --port $PORT --workers 2 --timeout-keep-alive 30`.
  3. Ensure Environment Variables `GNANI_API_KEY`, `SERPAPI_API_KEY`, and `OPENROUTER_API_KEY` are configured.
  4. Trigger **Manual Deploy** → **Clear build cache & deploy**.
