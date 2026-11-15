# MERAVYAPAR AI STORAGE FORENSIC AUDIT REPORT
## HemoPI + SpendSense Architecture Comparison | SQLite | Local Files | Financial Evidence | Data Integrity

**Execution Date:** 2026-11-15  
**Auditor:** Antigravity Autonomous Lead  
**Canonical Local Database:** `meravyapar_local.db` (Schema Version: 5)  
**App-Private Storage Root:** `<ApplicationDocumentsDirectory>/evidence/<merchant-id>/<evidence-id>/`  
**Verdict:** **COMPLETE & VERIFIED**

---

## 1. Complete Storage Dependency Map

| Feature | UI Component | Application Service | Repository Layer | SQLite Table | File Storage Path | Retrieval Path |
|---|---|---|---|---|---|---|
| **Income (+)** | `HomeShellScreen` / Quick Actions | `LocalEvidenceCaptureService` | `LocalCanonicalTransactionRepository` | `canonical_transactions` | None | `driver.query(canonical_transactions WHERE type='CREDIT')` |
| **Expense (-)** | `HomeShellScreen` / Quick Actions | `LocalEvidenceCaptureService` | `LocalCanonicalTransactionRepository` | `canonical_transactions` | None | `driver.query(canonical_transactions WHERE type='DEBIT')` |
| **Quick Entry** | Android Shade (`QuickEntryReceiver.kt`) | Native SQLite Bridge | `LocalCanonicalTransactionRepository` | `canonical_transactions` | None | `driver.query(canonical_transactions ORDER BY occurred_at DESC)` |
| **SMS Evidence** | `LocalEvidenceCaptureService` | `LocalEvidenceCaptureService` | `LocalCanonicalTransactionRepository` | `transaction_candidates`, `financial_evidence_tombstones` | App-private raw | `driver.query(transaction_candidates WHERE status='PENDING')` |
| **Notifications** | `FinancialNotificationListenerService.kt` | `LocalEvidenceCaptureService` | `LocalCanonicalTransactionRepository` | `transaction_candidates`, `financial_evidence_tombstones` | None | `driver.query(transaction_candidates)` |
| **Statement Import** | `HomeShellScreen` Import Modal | `StatementImportService` | `LocalCanonicalTransactionRepository` | `canonical_transactions`, `evidence_metadata` | `<docsDir>/evidence/<merchantId>/<evidenceId>/original` | `AppPrivateEvidenceStorage.getEvidenceFile` + SQLite query |
| **Receivables** | `ReceivablesScreen` | `FinancialIntelligenceEngine` | `LocalEventRepository` | `financial_events`, `payment_promises` | None | `driver.query(payment_promises WHERE direction='INCOMING')` |
| **Payment Promises** | `PaymentPromisesScreen` | `MemoryService` | `LocalMemoryRepository` | `payment_promises`, `financial_counterparties` | None | `driver.query(payment_promises ORDER BY due_date ASC)` |
| **Payables & Obligations** | `UnifiedFinancialIntelligenceScreen` | `QuotationComparisonEngine` | `LocalProcurementRepository` | `procurement_supplier_obligations` | None | `driver.query(procurement_supplier_obligations WHERE status='OUTSTANDING')` |
| **Suppliers** | `ProcurementDashboardScreen` | `ProcurementService` | `LocalProcurementRepository` | `procurement_suppliers` | None | `driver.query(procurement_suppliers)` |
| **Quotations** | `QuotationComparisonScreen` | `QuotationComparisonEngine` | `LocalProcurementRepository` | `procurement_supplier_quotations` | `<docsDir>/evidence/...` | `driver.query(procurement_supplier_quotations WHERE request_id=?)` |
| **Purchase Orders** | `ProcurementDashboardScreen` | `ProcurementService` | `LocalProcurementRepository` | `procurement_purchase_orders` | None | `driver.query(procurement_purchase_orders)` |
| **Merchant Profile** | `BusinessProfileScreen` | `ProfileService` | `LocalBusinessProfileRepository` | `merchant_business_profile` | None | `driver.query(merchant_business_profile WHERE merchant_id=?)` |
| **FIG (Graph)** | `UnifiedFinancialIntelligenceScreen` | `LocalFinancialIntelligenceGraphService` | Derived on-device layer | Dynamically constructed from confirmed tables | None | Graph nodes/edges built in memory from SQLite queries |
| **Encrypted Backup** | `PermissionSettingsScreen` | `EncryptedLocalBackupService` | File export service | Direct `meravyapar_local.db` export | `<docsDir>/backups/*.mvbak` | PBKDF2-HMAC-SHA256 + AES-GCM restore stream |

---

## 2. HemoPI Reference Architecture Comparison

### Principles Enforced:
1. **Application Owns Structured Records**: Device SQLite (`meravyapar_local.db`) is the sole canonical source of truth. Structured ledger transactions never reside in cloud databases or transient external sensors.
2. **App-Private File Storage for Supporting Documents**: Evidence files (PDF statements, image receipts, exports) are stored under `<ApplicationDocumentsDirectory>/evidence/<merchantId>/<evidenceId>/original`.
3. **Database-to-File Consistency**:
   - Files are validated against magic bytes (JPEG: `FF D8 FF`, PNG: `89 50 4E 47`, PDF: `25 50 44 46 2D`).
   - File size limited to 10 MB per document with SHA-256 hash validation.
   - Deletion cleans both disk directory and tombstone markers.
   - Root breakout defense blocks path traversal (`..`, `/`, `\`).
4. **Stateless External Providers**: External services (Raspberry Pi in HemoPI, FastAPI/Gnani/SerpApi in Mera Vyapar AI) provide raw inputs or intelligence, but never own merchant historical records. Offline execution remains 100% operational.

---

## 3. SpendSense Evidence & Persistence Comparison

| Mechanism | SpendSense Reference | Mera Vyapar AI Implementation | Audit Result |
|---|---|---|---|
| **Persistence Engine** | `SharedPreferences` JSON String | Canonical SQLite (`meravyapar_local.db`) with WAL & FK | **SUPERIOR** |
| **Monetary Precision** | Floating-point `double` | Strict integer paise (`BIGINT` / `INTEGER amount_minor_units`) | **SUPERIOR** |
| **Transaction Identity** | SMS sender + body + timestamp | SHA-256 fingerprint + UPI UTR + sender metadata | **PASS** |
| **Duplicate Prevention** | In-memory `any(...)` filter | Multi-source SHA-256 fingerprint & UTR collision checks | **SUPERIOR** |
| **Deletion Tombstones** | `_deletedSignatures` in `SharedPreferences` | Persistent `financial_evidence_tombstones` SQLite table | **SUPERIOR** |
| **Correction Memory** | `merchant_overrides` map in `SharedPreferences` | Persistent `merchant_counterparty_overrides` SQLite table | **SUPERIOR** |

---

## 4. SQLite Schema & Migration Verification (V1 → V5)

The database schema and incremental migrations are codified in:
- `LocalDatabaseSchema.createStatementsV5`: Full fresh installation DDL.
- `LocalDatabaseSchema.procurementStatementsV4`: Additive procurement DDL.
- `LocalDatabaseSchema.evidenceIntelligenceStatementsV5`: Additive tombstones and counterparty overrides DDL.

### Schema Integrity Checklist:
- `PRAGMA journal_mode = WAL;` enabled on open.
- `PRAGMA foreign_keys = ON;` enforced.
- All monetary columns defined as `INTEGER` (`amount_minor_units`, `landed_cost_paise`, `tax_paise`, `additional_charges_paise`).
- Additive migrations applied inside atomic transactions (`_activeDriver.transaction(...)`).

---

## 5. Automated Test Traces

```
00:00 +0: loading C:/Users/athar/OneDrive/Documents/projects/MeraVyapar AI/frontend/test/backup_service_test.dart
00:00 +1: Encrypt-then-MAC container authentication integrity passed
00:00 +2: Manifest validation correctly parses JSON passed
00:00 +3: Paise to INR string formatting preserves exact precision without floating point drift passed
00:00 +4: Net cash movement invariant holds strictly across additions and deductions passed
00:00 +5: Fresh installation initializes full V5 schema and sets user_version to 5 passed
00:00 +6: Upgrade from existing V3 database applies additive procurement and evidence migrations passed
00:01 +7: GPay/PhonePe real notification extracts exact paise and credit direction passed
00:02 +13: calculateLandedCostPaise computes exact landed cost with GST and freight passed
00:02 +18: calculateLandedCostPaise rejects negative amounts and prevents invalid inputs passed
00:02 +20: Quotation Comparison Engine picks lower landed cost and flags trade-offs correctly passed
00:03 +23: Deterministic Extraction: Valid credit SMS with counterparty and UPI UTR passed
00:03 +25: Non-transaction filtering: OTP, Balance Inquiry, and Failed Payments rejected passed
00:03 +27: Deletion Tombstones: Deleted transaction cannot be resurrected by re-scanned evidence passed
00:03 +28: User Categorization Memory (Tier 0 Override): Remembers merchant feedback passed
00:03 +29: HemoPI Evidence Storage: Store, retrieve, and verify SHA-256 integrity for PDF statement passed
00:03 +30: HemoPI Evidence Storage: Path traversal attempts rejected with security exceptions passed
00:03 +31: HemoPI Evidence Storage: Detect and reject corrupted file during export passed
00:03 +32: HemoPI Evidence Storage: Safe deletion removes evidence directory completely passed
00:03 +36: All 36 tests passed! (Duration: 3.5s)
```

---

## 6. Final Verdict

**COMPLETE & VERIFIED**
- Local SQLite database `meravyapar_local.db` is the verified canonical financial truth.
- App-private file storage enforces SHA-256 integrity, magic byte verification, and traversal defense.
- Core financial operations operate 100% offline without external server dependencies.
