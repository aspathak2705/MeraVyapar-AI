# MeraVyapar AI — Gnani AI Integration
## Multilingual Voice Autopilot with Gnani Prisma v2.5 & Timbre v2.5

### 1. Integration Scope
Gnani AI provides the primary voice conversational layer for MeraVyapar AI:
- **Speech-to-Text (STT)**: Gnani Prisma v2.5 (`POST https://api.vachana.ai/stt/v3`).
- **Text-to-Speech (TTS)**: Gnani Timbre v2.5 (`POST https://api.vachana.ai/api/v1/tts/inference`).
- **Wake-Word Autopilot**: Foreground on-device acoustic detection of the custom phrase **"Namaste Vyapar"**.

---

### 2. Integration Architecture
1. **Wake Phrase Activation**: When the merchant says *"Namaste Vyapar"*, `LocalAcousticWakeWordEngine` halts wake listening and transfers single-microphone ownership to `VoiceInteractionController`.
2. **Audio Streaming & STT**: The user's spoken command (e.g. in Hindi: *"Sharma ji ka payment reminder draft karo"*) is captured in WAV/PCM format and submitted to Gnani Prisma.
3. **Intent Parsing & Safeguard**: Intent is mapped to a candidate action and displayed in `VoiceConfirmationCard`. Spoken words **never** autonomously mutate the database.
4. **Local Execution**: Upon merchant confirmation, the reminder is saved to SQLite via `LocalActionRepository`.
5. **Spoken Feedback**: Gnani Timbre synthesizes a natural response in Hindi or English using the `Nalini` voice model.

---

### 3. Graceful Offline Degradation
If internet connectivity is interrupted or Gnani service times out, the mobile application displays a clean network message and allows the merchant to perform all ledger operations manually without crashing or corrupting data.
