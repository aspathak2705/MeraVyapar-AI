# MeraVyapar AI — Final Completion Master Plan
## Great Indian AI Internship Challenge Submission Programme

### 1. Vision & Architecture Integrity
- **Client**: Flutter + Riverpod mobile application.
- **Ledger Source of Truth**: Local SQLite (`meravyapar_local.db`).
- **Intelligence Layer**: On-device Financial Intelligence Graph (FIG) & Cash Flow Forecaster.
- **Voice Foundation**: Gnani Prisma v2.5 STT & Timbre v2.5 TTS.
- **External Gateways**: FastAPI stateless backend (Nemotron reasoning & SerpApi market discovery).
- **Security Boundaries**: Zero unauthenticated financial mutations; Zero cloud ledger storage; Approval Gates A & B held.

---

### 2. Dependency-Aware Implementation Sequence

```mermaid
flowchart TD
    subgraph Step 1: Core Navigation & Visibility
        A1[Wire /intelligence Route in AppRouter] --> A2[Add Financial Intelligence Card in HomeShellScreen]
    end

    subgraph Step 2: Action Center Local-First Unification
        B1[Implement LocalActionRepository on SQLite] --> B2[Connect Overdue Receivables to Reminder Drafting]
    end

    subgraph Step 3: Gnani Voice Autopilot Refinement
        C1[Connect Voice Intent to Screen Navigation & Confirmation Card] --> C2[Validate Multi-lingual Hindi/English Audio Flow]
    end

    subgraph Step 4: Submission Packaging & Verification
        D1[Verify Static Flutter & Backend Integrity] --> D2[Finalize Technical Submission Deck & Demo Script]
    end

    Step 1 --> Step 2
    Step 2 --> Step 3
    Step 3 --> Step 4
```

---

### 3. Immediate Implementation Tasks (Submission Critical)

#### Task 1: Navigation & Unified Intelligence Showcase
- **Files**: `frontend/lib/core/router/app_router.dart`, `frontend/lib/features/home/presentation/home_shell_screen.dart`
- **Action**: Add route `/intelligence` routing to `UnifiedFinancialIntelligenceScreen`. Surface a prominent "Financial Intelligence & Cash Flow" action card on the home screen.

#### Task 2: Local Action Center Integration
- **Files**: `frontend/lib/features/actions/data/local_action_repository.dart`, `frontend/lib/features/actions/presentation/action_center_screen.dart`
- **Action**: Provide local SQLite persistence for communication drafts (`communication_drafts` table) and direct reminder creation from overdue payment promises.

#### Task 3: Voice Autopilot End-to-End Verification
- **Files**: `frontend/lib/features/voice/presentation/voice_interaction_controller.dart`
- **Action**: Ensure voice transcription triggers action parsing, shows `VoiceConfirmationCard`, and guides merchant with voice feedback via Gnani TTS.

---

### 4. Definition of Done
1. Merchant can launch app, authenticate locally via PIN, and view real-time deterministic metrics (Inflows, Outflows, Net Movement, Receivables, Payables).
2. 14-day cash flow outlook displays either calculated trajectory or clean `INSUFFICIENT_HISTORY` banner.
3. Merchant can activate Gnani voice assistant, speak a command in Hindi or English, and review the parsed transaction or reminder.
4. All 5 audit deliverables generated in `audit_output/`.
