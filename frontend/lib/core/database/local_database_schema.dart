/// Schema definitions and metadata for MeraVyapar AI Local-First SQLite Database.
/// 
/// Preserves financial precision using integer minor units (paise: 1 INR = 100 paise)
/// and ISO-8601 UTC timestamp strings.
class LocalDatabaseSchema {
  static const int version = 3;
  static const String databaseFileName = 'meravyapar_local.db';

  // Table Names
  static const String tableMerchantProfile = 'merchant_profile';
  static const String tableCanonicalTransactions = 'canonical_transactions';
  static const String tableFinancialCounterparties = 'financial_counterparties';
  static const String tablePaymentPromises = 'payment_promises';
  static const String tableFinancialEvents = 'financial_events';
  static const String tableEvidenceMetadata = 'evidence_metadata';
  static const String tableTransactionCandidates = 'transaction_candidates';
  static const String tableCommunicationDrafts = 'communication_drafts';
  static const String tableAuditLog = 'local_audit_log';
  static const String tableMigrationMetadata = 'migration_metadata';

  // SQL DDL statements for version 3
  static const List<String> createStatementsV3 = [
    '''
    CREATE TABLE IF NOT EXISTS $tableMerchantProfile (
      id TEXT PRIMARY KEY,
      display_name TEXT,
      phone_number TEXT,
      business_category TEXT,
      currency TEXT NOT NULL DEFAULT 'INR',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'ACTIVE'
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableFinancialCounterparties (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      name TEXT NOT NULL,
      phone_number TEXT,
      category TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_counterparties_merchant 
    ON $tableFinancialCounterparties(merchant_id);
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableCanonicalTransactions (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      amount_minor_units INTEGER,
      currency TEXT NOT NULL DEFAULT 'INR',
      transaction_type TEXT NOT NULL,
      payment_mode TEXT NOT NULL,
      counterparty_name TEXT,
      counterparty_id TEXT,
      transaction_reference TEXT,
      description TEXT,
      occurred_at TEXT,
      reconciliation_status TEXT NOT NULL DEFAULT 'UNRESOLVED',
      source_type TEXT,
      source_provider TEXT,
      is_simulated INTEGER NOT NULL DEFAULT 0,
      idempotency_key TEXT UNIQUE,
      created_at TEXT NOT NULL,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT,
      FOREIGN KEY (counterparty_id) REFERENCES $tableFinancialCounterparties(id) ON DELETE SET NULL
    );
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_transactions_merchant_occurred 
    ON $tableCanonicalTransactions(merchant_id, occurred_at);
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_transactions_idempotency
    ON $tableCanonicalTransactions(idempotency_key);
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tablePaymentPromises (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      counterparty_id TEXT,
      counterparty_name TEXT NOT NULL,
      amount_minor_units INTEGER NOT NULL,
      currency TEXT NOT NULL DEFAULT 'INR',
      direction TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'OPEN',
      source TEXT NOT NULL DEFAULT 'MERCHANT_DECLARED',
      due_date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      fulfilled_at TEXT,
      notes TEXT,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT,
      FOREIGN KEY (counterparty_id) REFERENCES $tableFinancialCounterparties(id) ON DELETE SET NULL
    );
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_promises_merchant_due 
    ON $tablePaymentPromises(merchant_id, due_date, status);
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableFinancialEvents (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      event_type TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      amount_minor_units INTEGER,
      event_date TEXT NOT NULL,
      severity TEXT NOT NULL DEFAULT 'NORMAL',
      status TEXT NOT NULL DEFAULT 'ACTIVE',
      created_at TEXT NOT NULL,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableEvidenceMetadata (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      filename TEXT NOT NULL,
      mime_type TEXT NOT NULL,
      file_size_bytes INTEGER NOT NULL,
      sha256_hash TEXT NOT NULL,
      storage_relative_path TEXT NOT NULL,
      captured_at TEXT NOT NULL,
      source_type TEXT NOT NULL,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_evidence_merchant_sha 
    ON $tableEvidenceMetadata(merchant_id, sha256_hash);
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableTransactionCandidates (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      primary_evidence_id TEXT NOT NULL,
      transaction_type TEXT NOT NULL,
      amount_minor_units INTEGER,
      currency TEXT NOT NULL DEFAULT 'INR',
      transaction_timestamp TEXT,
      counterparty_name TEXT,
      payment_mode TEXT NOT NULL DEFAULT 'UNKNOWN',
      description TEXT,
      lifecycle_status TEXT NOT NULL DEFAULT 'EXTRACTED',
      reconciliation_match_id TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT,
      FOREIGN KEY (primary_evidence_id) REFERENCES $tableEvidenceMetadata(id) ON DELETE CASCADE,
      FOREIGN KEY (reconciliation_match_id) REFERENCES $tableCanonicalTransactions(id) ON DELETE SET NULL
    );
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_candidates_merchant_status 
    ON $tableTransactionCandidates(merchant_id, lifecycle_status);
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableCommunicationDrafts (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      promise_id TEXT,
      action_type TEXT NOT NULL DEFAULT 'PAYMENT_REMINDER',
      channel TEXT NOT NULL,
      recipient_phone TEXT,
      recipient_name TEXT,
      draft_content TEXT NOT NULL,
      final_content TEXT,
      status TEXT NOT NULL DEFAULT 'DRAFT',
      idempotency_key TEXT,
      delivery_mode TEXT,
      confirmed_at TEXT,
      created_at TEXT NOT NULL,
      dispatched_at TEXT,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT,
      FOREIGN KEY (promise_id) REFERENCES $tablePaymentPromises(id) ON DELETE SET NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableAuditLog (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      action_type TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      details_json TEXT,
      occurred_at TEXT NOT NULL,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableMigrationMetadata (
      migration_key TEXT PRIMARY KEY,
      source_system TEXT NOT NULL,
      migrated_records_count INTEGER NOT NULL,
      migrated_at TEXT NOT NULL,
      checksum TEXT NOT NULL
    );
    '''
  ];
}
