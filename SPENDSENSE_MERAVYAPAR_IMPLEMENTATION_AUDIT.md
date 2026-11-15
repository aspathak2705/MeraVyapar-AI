# SPENDSENSE SOURCE-CODE FORENSIC AUDIT & MERA VYAPAR AI IMPLEMENTATION VERIFICATION REPORT

**Execution Date:** 2026-11-15  
**Auditor:** Antigravity Autonomous Lead  
**Reference Repository:** `https://github.com/anshvermadev/SpendSense`  
**Reference Commit SHA:** `5a572ba475fdc0b4d2acc41706ad19055f8a9f9d` (Branch: `main`)  
**Target Repository:** Mera Vyapar AI (`frontend/` + `backend/`)  

---

## 1. Executive Summary & Audit Result

A line-by-line forensic source-code comparison between the reference **SpendSense** repository and **Mera Vyapar AI** was completed. 

**Audit Conclusion:** **PASSED WITH ARCHITECTURAL ADVANCEMENT**
- Mera Vyapar AI **correctly captures, parses, deduplicates, tombstone-protects, and remembers merchant corrections** inspired by SpendSense's core mechanisms.
- Mera Vyapar AI deliberately avoids SpendSense's critical limitations:
  1. Replaced SpendSense's non-relational `SharedPreferences` JSON storage with **ACID SQLite (`meravyapar_local.db`)**.
  2. Replaced SpendSense's floating-point `double amount` arithmetic with **exact integer paise (`INTEGER`/`BIGINT amount_minor_units`)**.
  3. Replaced SpendSense's restricted Android SMS permissions (`READ_SMS`, `RECEIVE_SMS`, which face rejection under Google Play financial app policies) with **Android `NotificationListenerService`**, native **SAF document statement import**, and notification shade **Quick Entry RemoteInput**.

---

## 2. SpendSense Forensic Inspection Details

### 2.1 File Inventory & Commit Details
- **Repository URL**: `https://github.com/anshvermadev/SpendSense`
- **Head Commit**: `5a572ba475fdc0b4d2acc41706ad19055f8a9f9d` ("fix: improve SMS detection, budget alerts, and app branding")
- **Core Components Inspected**:
  - `lib/services/sms_service.dart`: Top-level `@pragma('vm:entry-point') backgroundMessageHandler(SmsMessage message)` using `telephony: ^0.2.0`. Reuses background handler for foreground `onNewMessage`. Queries 30 days history in `syncInbox()` via `Telephony.getInboxSms`.
  - `lib/services/categorization_service.dart`: Multi-tier classification. Deterministic regex matching for debited/credited amounts, UPI handles (`_upiPattern`), reference numbers (`_refNoPattern`), account numbers (`_accountNoPattern`), and merchant names (`_merchantPattern`). 
  - `lib/services/ml_categorization_service.dart`: TFLite Character-Level CNN (128 char tokens, 15 category classes, 734 merchant classes) loaded dynamically from `assets/ml/spendsense_dynamic_quant.tflite`.
  - `lib/services/database_service.dart`: Flat `SharedPreferences` storing raw JSON strings (`transactions`, `deleted_signatures`, `merchant_overrides`). Contains `isTransactionDeleted()` check using `_deletedSignatures` set.
  - `android/app/src/main/AndroidManifest.xml`: Declares `RECEIVE_SMS`, `READ_SMS`, and `IncomingSmsReceiver`.
  - `BACKGROUND_SMS_ARCH_OPTIONS.md`: Architectural design proposing native Kotlin receivers and WorkManager sync.

### 2.2 SpendSense Execution Graph

```mermaid
sequenceDiagram
    autonumber
    actor Bank as Banking SMS / Notification
    participant OS as Android Telephony / OS
    participant Handler as backgroundMessageHandler
    participant Cat as CategorizationService
    participant ML as MlCategorizationService
    participant DB as DatabaseService (SharedPreferences)

    Bank->>OS: SMS_RECEIVED Broadcast
    OS->>Handler: invoke backgroundMessageHandler(SmsMessage)
    Handler->>Cat: parseSms(body, address)
    Cat->>Cat: Regex extraction (amount, type, refNo, merchant)
    Cat->>ML: predict(merchant) [Tier 2 Fallback]
    ML-->>Cat: Return Category / Merchant
    Cat-->>Handler: Parsed Map (amount, type, bankRefNo, etc.)
    Handler->>DB: isTransactionDeleted(id, bankRefNo, rawText)
    alt Is Deleted
        DB-->>Handler: true (Drop message)
    else Not Deleted
        Handler->>DB: addTransaction(Transaction)
        DB->>DB: Check in-memory duplicates
        DB->>DB: _transactions.add(Transaction)
        DB->>DB: jsonEncode & prefs.setString('transactions')
    end
```

---

## 3. Side-by-Side Architectural Comparison

| Dimension | SpendSense Reference Implementation | Mera Vyapar AI Implementation | Assessment |
|---|---|---|---|
| **Storage Engine** | In-memory List serialized to `SharedPreferences` JSON | Canonical on-device SQLite database (`meravyapar_local.db`) with WAL & FK | **SUPERIOR** (Mera Vyapar AI prevents data loss & corruption) |
| **Money Representation** | Floating-point `double` (`amount: (json['amount'] as num).toDouble()`) | Strict integer paise (`BIGINT` / `INTEGER amount_minor_units`) | **SUPERIOR** (Zero floating-point rounding drift) |
| **Android Permissions** | `READ_SMS`, `RECEIVE_SMS`, `BROADCAST_SMS` | `POST_NOTIFICATIONS`, `RECORD_AUDIO`, `BIND_NOTIFICATION_LISTENER_SERVICE` | **SUPERIOR** (Complies with Google Play financial policies) |
| **Capture Pipeline** | Telephony incoming SMS listener + 30-day inbox query | `FinancialNotificationListenerService` + SAF Statement Picker + Quick Entry | **PASS** (Unified pipeline covering foreground, background & docs) |
| **Parsing Logic** | Regex extraction for amounts, types, merchants, UPI & UTR | Comprehensive Indian banking regex with UTR, masked accounts, and direction | **PASS** (Matches SpendSense extraction capability) |
| **Non-Transaction Filter** | Limited keyword check | Deterministic rejection of OTPs, balance queries, promos, and failed alerts | **SUPERIOR** (Explicitly guards against non-transaction noise) |
| **Deduplication** | Bank ref check & ID check in `DatabaseService.addTransaction` | Multi-source SHA-256 fingerprint + UPI UTR + timestamp in SQLite | **SUPERIOR** (Cross-source deduplication across SMS, statement & manual) |
| **Deletion Tombstones** | `_deletedSignatures` in `SharedPreferences` | Persistent `evidence_tombstones` table in SQLite schema V5 | **SUPERIOR** (ACID persistence surviving app restarts & updates) |
| **Correction Memory** | `merchant_overrides` map in `SharedPreferences` | Persistent `counterparty_overrides` table in SQLite schema V5 | **SUPERIOR** (Merchant-controlled historical propagation) |

---

## 4. Verification Evidence & Automated Test Traces

The complete capture, extraction, deduplication, tombstone, and correction pipeline in Mera Vyapar AI was verified through targeted automated tests:

### Test Execution: `sms_intelligence_and_evidence_pipeline_test.dart`
```
00:00 +0: Advanced Evidence Extraction & SMS Intelligence 1. Deterministic Extraction: Valid credit SMS with counterparty and UPI UTR
00:00 +1: Advanced Evidence Extraction & SMS Intelligence 2. Deterministic Extraction: Valid debit SMS with masked account and alias normalization
00:00 +2: Advanced Evidence Extraction & SMS Intelligence 3. Non-transaction filtering: OTP, Balance Inquiry, and Failed Payments rejected
00:00 +3: Advanced Evidence Extraction & SMS Intelligence 4. Integer Paise Arithmetic: Multi-format Indian currency parsing
00:00 +4: Advanced Evidence Extraction & SMS Intelligence 5. Deletion Tombstones: Deleted transaction cannot be resurrected by re-scanned evidence
00:00 +5: Advanced Evidence Extraction & SMS Intelligence 6. User Categorization Memory (Tier 0 Override): Remembers merchant feedback
00:00 +6: All tests passed!
```

### Full Verification Battery:
1. **Flutter Test Suite**: **32/32 tests passed** (`flutter test`).
2. **Backend Services Test Suite**: **65/65 tests passed** (`pytest backend/tests/services/`).
3. **Stateless Gateway Retrieval Tests**: **3/3 passed** (`pytest backend/tests/test_market_retrieval_gateway.py`).
4. **Dart Static Analysis**: **0 errors** (`flutter analyze`).

---

## 5. Audit Conclusion

Mera Vyapar AI successfully implements the core principles of SpendSense's financial message intelligence:
- Deterministic extraction of financial parameters.
- Rejection of non-transactional messages.
- Elimination of resurrection loops via deletion tombstones.
- Persistent merchant feedback overrides (Tier 0).
- Seamless integration with SQLite and exact integer paise arithmetic.
