# MeraVyapar AI — Claims & Evidence Register
## Great Indian AI Internship Challenge Verification Matrix

| Challenge Requirement / Claim | Technical Implementation | Codebase Evidence Path | Verification Level |
|---|---|---|---|
| **Local-First Financial Ledger** | SQLite WAL mode, integer paise math, offline storage | `frontend/lib/core/database/local_database_service.dart` | Source Implemented & Static Verified |
| **Authentic Gnani AI Speech Integration** | Prisma v2.5 STT & Timbre v2.5 TTS REST adapters | `backend/app/infrastructure/speech/gnani_stt_adapter.py` | Source Implemented & Contract Verified |
| **Namaste Vyapar Wake-Word** | Foreground acoustic pattern detector with lifecycle pause | `frontend/lib/features/voice/services/wake_word_detector_service.dart` | Source Implemented (Device tuning pending) |
| **Deterministic Cash Flow Forecasting** | Moving-average baseline + promise scheduling | `frontend/lib/features/intelligence/domain/local_cashflow_forecasting_engine.dart` | Source Implemented & Static Verified |
| **Explainable Receivables Prioritization** | Deterministic HIGH/MEDIUM/LOW heuristic | `LocalFinancialIntelligenceEngine.getPrioritizedReceivables()` | Source Implemented & Static Verified |
| **Offline Communication Drafts** | SQLite persistence of draft reminders & audit events | `frontend/lib/features/actions/data/local_action_repository.dart` | Source Implemented & Static Verified |
| **Grounded LLM Reasoning** | Nemotron prompt grounding with amount regex validation | `backend/app/infrastructure/ai/nemotron_provider.py` | Source Implemented & Static Verified |
| **Restricted SerpApi Search** | Locked to `google`, `google_shopping`, `google_news` | `backend/app/infrastructure/market_intelligence/serpapi_client.py` | Source Implemented & Static Verified |
| **Encrypted AEAD Local Backups** | AES-256-GCM + PBKDF2 (60k rounds) + crash journal | `frontend/lib/core/backup/encrypted_local_backup_service.dart` | Source Implemented & Static Verified |
| **PhonePe-Style Dark/Light UI** | Purple tokens, custom icons, bottom nav | `frontend/lib/core/theme/` & `home_shell_screen.dart` | Source Implemented & Static Verified |
