# MeraVyapar AI — Technical Architecture
## Technical Architecture & Privacy-by-Design

```mermaid
flowchart TD
    subgraph Mobile Sandbox [Flutter Mobile Application]
        UI[PhonePe-Inspired Fintech UI: White & Purple]
        Theme[ThemeModeProvider: Light & Dark Mode]
        Auth[Local PIN Auth: PBKDF2 + Android Keystore]
        DB[(Local SQLite: meravyapar_local.db - WAL Mode)]
        FIG[Financial Intelligence Graph - Derived Layer]
        Forecast[Local Cash Flow Forecaster - Moving Avg Baseline]
        ActionRepo[Local Action Repository - Offline Drafts]
        WakeWord[LocalAcousticWakeWordEngine: 'Namaste Vyapar']

        UI <--> DB
        UI <--> Auth
        UI <--> Theme
        UI <--> FIG
        UI <--> Forecast
        UI <--> ActionRepo
        WakeWord -. "Foreground Activation" .-> UI
    end

    subgraph External Stateless Gateways [FastAPI Gateway]
        Gateway[FastAPI Gateway Daemon]
        GnaniSTT[Gnani Prisma v2.5 STT]
        GnaniTTS[Gnani Timbre v2.5 TTS - Nalini Voice]
        Nemotron[OpenRouter Nemotron - Structured Grounding]
        SerpApi[SerpApi - google, google_shopping, google_news]

        UI -- "Spoken Audio Only" --> GnaniSTT
        GnaniTTS -- "Synthesized WAV" --> UI
        UI -- "Aggregated Metrics Only" --> Gateway
        Gateway --> Nemotron
        Gateway --> SerpApi
    end
```

### Architectural Principles
- **Canonical Financial Authority**: Local SQLite is the sole source of financial truth. FastAPI has zero persistence.
- **Privacy Barrier**: Bank account numbers, full UTRs, and raw SMS are never transmitted to external providers.
- **Deterministic Math**: Calculations use integer minor units (paise). Floating point drift is eliminated.
- **Encrypted Local Backup**: AES-256-GCM authenticated encryption with PBKDF2 (60,000 rounds) key derivation and crash recovery rollback.
