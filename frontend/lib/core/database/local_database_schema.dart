/// Schema definitions and metadata for MeraVyapar AI Local-First SQLite Database.
/// 
/// Preserves financial precision using integer minor units (paise: 1 INR = 100 paise)
/// and ISO-8601 UTC timestamp strings.
class LocalDatabaseSchema {
  static const int version = 4;
  static const String databaseFileName = 'meravyapar_local.db';

  // Table Names
  static const String tableMerchantProfile = 'merchant_profile';
  static const String tableMerchantBusinessProfile = 'merchant_business_profile';
  static const String tableCanonicalTransactions = 'canonical_transactions';
  static const String tableFinancialCounterparties = 'financial_counterparties';
  static const String tablePaymentPromises = 'payment_promises';
  static const String tableFinancialEvents = 'financial_events';
  static const String tableEvidenceMetadata = 'evidence_metadata';
  static const String tableTransactionCandidates = 'transaction_candidates';
  static const String tableCommunicationDrafts = 'communication_drafts';
  static const String tableAuditLog = 'local_audit_log';
  static const String tableMigrationMetadata = 'migration_metadata';

  // Procurement & Supplier Intelligence Tables (Additive V4)
  static const String tableSuppliers = 'procurement_suppliers';
  static const String tablePurchaseRequests = 'procurement_purchase_requests';
  static const String tableSupplierQuotations = 'procurement_supplier_quotations';
  static const String tablePurchaseOrders = 'procurement_purchase_orders';
  static const String tableSupplierObligations = 'procurement_supplier_obligations';

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
    CREATE TABLE IF NOT EXISTS $tableMerchantBusinessProfile (
      merchant_id TEXT PRIMARY KEY,
      business_name TEXT NOT NULL,
      business_category TEXT NOT NULL,
      business_type TEXT NOT NULL,
      products_and_services TEXT,
      city TEXT,
      state TEXT,
      customer_type TEXT,
      sales_channels TEXT,
      main_procurement_categories TEXT,
      turnover_range TEXT,
      business_goals TEXT,
      updated_at TEXT NOT NULL
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

  // SQL DDL statements for version 4 (KharidSaathi Procurement Additions)
  static const List<String> procurementStatementsV4 = [
    '''
    CREATE TABLE IF NOT EXISTS $tableSuppliers (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      name TEXT NOT NULL,
      contact_person TEXT,
      phone_number TEXT,
      email TEXT,
      category TEXT,
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_procurement_suppliers_merchant
    ON $tableSuppliers(merchant_id, name);
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tablePurchaseRequests (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      title TEXT NOT NULL,
      item_name TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit TEXT NOT NULL,
      grade_spec TEXT,
      dimensions TEXT,
      delivery_timeline TEXT,
      status TEXT NOT NULL DEFAULT 'OPEN',
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_procurement_pr_merchant
    ON $tablePurchaseRequests(merchant_id, status);
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableSupplierQuotations (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      purchase_request_id TEXT,
      supplier_id TEXT NOT NULL,
      supplier_name TEXT NOT NULL,
      item_name TEXT NOT NULL,
      specification TEXT,
      quantity REAL NOT NULL,
      unit TEXT NOT NULL,
      unit_price_minor_units INTEGER NOT NULL,
      gst_rate_percent REAL NOT NULL DEFAULT 18.0,
      freight_minor_units INTEGER NOT NULL DEFAULT 0,
      other_charges_minor_units INTEGER NOT NULL DEFAULT 0,
      total_landed_cost_minor_units INTEGER NOT NULL,
      delivery_days INTEGER NOT NULL DEFAULT 7,
      payment_terms TEXT NOT NULL DEFAULT 'CREDIT_30_DAYS',
      valid_until TEXT,
      is_accepted INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT,
      FOREIGN KEY (purchase_request_id) REFERENCES $tablePurchaseRequests(id) ON DELETE SET NULL,
      FOREIGN KEY (supplier_id) REFERENCES $tableSuppliers(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_procurement_quotes_pr
    ON $tableSupplierQuotations(purchase_request_id, total_landed_cost_minor_units);
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tablePurchaseOrders (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      purchase_request_id TEXT,
      quotation_id TEXT NOT NULL,
      supplier_id TEXT NOT NULL,
      supplier_name TEXT NOT NULL,
      item_name TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit TEXT NOT NULL,
      total_amount_minor_units INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'CONFIRMED',
      delivery_status TEXT NOT NULL DEFAULT 'PENDING',
      quality_status TEXT NOT NULL DEFAULT 'PENDING',
      created_at TEXT NOT NULL,
      delivered_at TEXT,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT,
      FOREIGN KEY (purchase_request_id) REFERENCES $tablePurchaseRequests(id) ON DELETE SET NULL,
      FOREIGN KEY (quotation_id) REFERENCES $tableSupplierQuotations(id) ON DELETE RESTRICT,
      FOREIGN KEY (supplier_id) REFERENCES $tableSuppliers(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableSupplierObligations (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      purchase_order_id TEXT NOT NULL,
      supplier_id TEXT NOT NULL,
      supplier_name TEXT NOT NULL,
      total_obligation_minor_units INTEGER NOT NULL,
      settled_minor_units INTEGER NOT NULL DEFAULT 0,
      outstanding_minor_units INTEGER NOT NULL,
      due_date TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'PENDING',
      created_at TEXT NOT NULL,
      settled_at TEXT,
      FOREIGN KEY (merchant_id) REFERENCES $tableMerchantProfile(id) ON DELETE RESTRICT,
      FOREIGN KEY (purchase_order_id) REFERENCES $tablePurchaseOrders(id) ON DELETE RESTRICT,
      FOREIGN KEY (supplier_id) REFERENCES $tableSuppliers(id) ON DELETE RESTRICT
    );
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_supplier_obligations_merchant
    ON $tableSupplierObligations(merchant_id, status, due_date);
    '''
  ];

  /// Combined creation statements for fresh installations (V4)
  static List<String> get createStatementsV4 => [
        ...createStatementsV3,
        ...procurementStatementsV4,
      ];
}
