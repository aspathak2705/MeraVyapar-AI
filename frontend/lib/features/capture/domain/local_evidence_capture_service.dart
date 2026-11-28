import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/database/local_database_schema.dart';
import '../../../core/database/migration/migration_verification_service.dart';
import '../../evidence/domain/transaction_candidate_model.dart';

/// Structured outcome of financial SMS / evidence extraction
class ExtractedFinancialEvidence {
  final String amount;
  final int amountPaise;
  final String transactionType; // CREDIT, DEBIT, UNKNOWN
  final String paymentMode; // UPI, CARD, NETBANKING, CASH, UNKNOWN
  final String? counterparty;
  final String? normalizedCounterparty;
  final String? assignedCategory;
  final String? referenceNumber;
  final String? maskedAccount;
  final String rawClassification; // CREDIT, DEBIT, ATM, BANK_CHARGE, REFUND, REVERSAL, FAILED, PENDING, PAYMENT_REQUEST, BALANCE_ONLY, PROMO, OTP, UNKNOWN
  final bool isEligibleTransaction;
  final bool needsReview;
  final String? reviewReason;
  final String fingerprint;

  const ExtractedFinancialEvidence({
    required this.amount,
    required this.amountPaise,
    required this.transactionType,
    required this.paymentMode,
    this.counterparty,
    this.normalizedCounterparty,
    this.assignedCategory,
    this.referenceNumber,
    this.maskedAccount,
    required this.rawClassification,
    required this.isEligibleTransaction,
    required this.needsReview,
    this.reviewReason,
    required this.fingerprint,
  });
}

class LocalEvidenceCaptureService {
  final LocalDatabaseService _dbService;

  LocalEvidenceCaptureService({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Known merchant alias mapping dictionary
  static final Map<String, String> _knownAliases = {
    'AMZN': 'Amazon',
    'AMAZON PAY': 'Amazon',
    'AVENUE SUPERMARTS': 'DMart',
    'DMART': 'DMart',
    'SWIGGY': 'Swiggy',
    'SWIGGY INSTAMART': 'Swiggy Instamart',
    'INSTAMART': 'Swiggy Instamart',
    'ZOMATO': 'Zomato',
    'BLINKIT': 'Blinkit',
    'ZEPTO': 'Zepto',
    'FLIPKART': 'Flipkart',
    'IRCTC': 'IRCTC',
    'JIO': 'Reliance Jio',
    'AIRTEL': 'Bharti Airtel',
    'VI': 'Vodafone Idea',
    'INDIAN OIL': 'Indian Oil',
    'HPCL': 'Hindustan Petroleum',
    'BPCL': 'Bharat Petroleum',
    'PETROL PUMP': 'Fuel Station',
    'MAHINDRA': 'Mahindra',
    'TATA MOTORS': 'Tata Motors',
    'PAYTM': 'Paytm',
    'PHONEPE': 'PhonePe',
    'BHARATPE': 'BharatPe',
    'GOOGLEPAY': 'Google Pay',
    'GPAY': 'Google Pay',
    'CRED': 'CRED',
    'TATACLIQ': 'Tata CLiQ',
  };

  /// Deterministic category mapping based on normalized counterparty or message context
  static final Map<String, String> _deterministicCategories = {
    'Amazon': 'E-commerce & Supplies',
    'DMart': 'Groceries & Provisions',
    'Swiggy': 'Food & Beverages',
    'Swiggy Instamart': 'Groceries & Provisions',
    'Zomato': 'Food & Beverages',
    'Blinkit': 'Groceries & Provisions',
    'Zepto': 'Groceries & Provisions',
    'Flipkart': 'E-commerce & Supplies',
    'IRCTC': 'Travel & Logistics',
    'Reliance Jio': 'Utilities & Communication',
    'Bharti Airtel': 'Utilities & Communication',
    'Vodafone Idea': 'Utilities & Communication',
    'Indian Oil': 'Fuel & Freight',
    'Hindustan Petroleum': 'Fuel & Freight',
    'Bharat Petroleum': 'Fuel & Freight',
    'Fuel Station': 'Fuel & Freight',
  };

  /// Compute deterministic SHA-256 fingerprint from evidence parameters
  static String generateEvidenceFingerprint({
    required String merchantId,
    required int amountPaise,
    required String direction,
    String? reference,
    String? counterparty,
  }) {
    final raw = '$merchantId|$amountPaise|$direction|${reference ?? ''}|${counterparty?.toLowerCase() ?? ''}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// Ingest raw evidence metadata into local SQLite, respecting tombstones, duplicate protection,
  /// and user categorization memory.
  Future<TransactionCandidateModel?> ingestEvidenceAndExtract({
    required String merchantId,
    required String filename,
    required String mimeType,
    required int fileSizeBytes,
    required String sha256Hash,
    required String storageRelativePath,
    required String sourceType, // 'SMS', 'STATEMENT', 'MANUAL', 'NOTIFICATION'
    String? rawText,
    String? declaredAmount,
    String? declaredType,
    String? counterpartyName,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    final candidateId = const Uuid().v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1. Deterministic Extraction
    final extraction = extractFinancialDetails(
      text: rawText ?? '',
      declaredAmount: declaredAmount,
      declaredType: declaredType,
      counterpartyName: counterpartyName,
      merchantId: merchantId,
    );

    // If message is non-financial (OTP, promo, balance-only, failed payment), do not create candidate
    if (!extraction.isEligibleTransaction && !extraction.needsReview) {
      return null;
    }

    // 2. Check Deletion Tombstones: Prevent resurrected deleted or rejected transactions
    final isTombstoned = await isFingerprintTombstoned(
      merchantId: merchantId,
      fingerprint: extraction.fingerprint,
      sourceReference: extraction.referenceNumber,
    );
    if (isTombstoned) {
      return null;
    }

    // 3. User Categorization Memory Override (Tier 0 check)
    String effectiveCounterparty = extraction.normalizedCounterparty ?? extraction.counterparty ?? '';
    String? effectiveCategory = extraction.assignedCategory;

    if (effectiveCounterparty.isNotEmpty) {
      final override = await getCounterpartyOverride(
        merchantId: merchantId,
        rawAlias: effectiveCounterparty,
      );
      if (override != null) {
        effectiveCounterparty = override['normalized_name'] as String;
        effectiveCategory = override['assigned_category'] as String;
      }
    }

    // 4. Idempotent Evidence Ingestion: Check if sha256 already exists for this merchant
    final existingEvidence = await driver.query(
      '''
      SELECT id FROM ${LocalDatabaseSchema.tableEvidenceMetadata}
      WHERE merchant_id = ? AND sha256_hash = ?
      ''',
      [merchantId, sha256Hash],
    );

    String evidenceId;
    if (existingEvidence.isNotEmpty) {
      evidenceId = existingEvidence.first['id'] as String;
    } else {
      evidenceId = const Uuid().v4();
      await driver.execute(
        '''
        INSERT INTO ${LocalDatabaseSchema.tableEvidenceMetadata} (
          id, merchant_id, filename, mime_type, file_size_bytes,
          sha256_hash, storage_relative_path, captured_at, source_type
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          evidenceId,
          merchantId,
          filename,
          mimeType,
          fileSizeBytes,
          sha256Hash,
          storageRelativePath,
          nowIso,
          sourceType,
        ],
      );
    }

    final candidateDescription = extraction.referenceNumber != null
        ? 'Ref: ${extraction.referenceNumber} | Extracted from $sourceType: $filename'
        : 'Extracted from $sourceType: $filename';

    final lifecycleStatus = extraction.needsReview ? 'NEEDS_REVIEW' : 'EXTRACTED';

    // 5. Persist Candidate into SQLite for crash resilience
    await driver.execute(
      '''
      INSERT INTO ${LocalDatabaseSchema.tableTransactionCandidates} (
        id, merchant_id, primary_evidence_id, transaction_type,
        amount_minor_units, currency, transaction_timestamp,
        counterparty_name, payment_mode, description,
        lifecycle_status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        candidateId,
        merchantId,
        evidenceId,
        extraction.transactionType,
        extraction.amountPaise,
        'INR',
        nowIso,
        effectiveCounterparty.isNotEmpty ? effectiveCounterparty : null,
        extraction.paymentMode,
        effectiveCategory != null ? '$candidateDescription [Category: $effectiveCategory]' : candidateDescription,
        extraction.isEligibleTransaction && !extraction.needsReview ? 'PROMOTED' : lifecycleStatus,
        nowIso,
        nowIso,
      ],
    );

    // 6. Direct Canonical Ledger Promotion: If eligible financial transaction, persist into canonical_transactions
    if (extraction.isEligibleTransaction && !extraction.needsReview) {
      final canonicalType = extraction.transactionType == 'CREDIT'
          ? 'MONEY_IN'
          : (extraction.transactionType == 'DEBIT' ? 'MONEY_OUT' : extraction.transactionType);
      final idempotencyKey = 'ev_${extraction.fingerprint}';

      final existingCanonical = await driver.query(
        '''
        SELECT id FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
        WHERE merchant_id = ? AND (
          idempotency_key = ? OR
          (transaction_reference IS NOT NULL AND transaction_reference != '' AND transaction_reference = ?)
        )
        ''',
        [merchantId, idempotencyKey, extraction.referenceNumber ?? ''],
      );

      if (existingCanonical.isEmpty) {
        final txId = const Uuid().v4();
        await driver.execute(
          '''
          INSERT INTO ${LocalDatabaseSchema.tableCanonicalTransactions} (
            id, merchant_id, amount_minor_units, currency, transaction_type,
            payment_mode, counterparty_name, counterparty_id, transaction_reference,
            description, occurred_at, reconciliation_status, source_type,
            source_provider, is_simulated, idempotency_key, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            txId,
            merchantId,
            extraction.amountPaise,
            'INR',
            canonicalType,
            extraction.paymentMode,
            effectiveCounterparty.isNotEmpty ? effectiveCounterparty : null,
            null,
            extraction.referenceNumber,
            effectiveCategory != null ? '$candidateDescription [Category: $effectiveCategory]' : candidateDescription,
            nowIso,
            'SETTLED',
            sourceType,
            filename,
            0,
            idempotencyKey,
            nowIso,
            nowIso,
          ],
        );
      }
    }

    return TransactionCandidateModel(
      id: candidateId,
      merchantId: merchantId,
      primaryEvidenceId: evidenceId,
      transactionType: extraction.transactionType,
      amount: extraction.amount,
      currency: 'INR',
      transactionTimestamp: nowIso,
      counterpartyName: effectiveCounterparty.isNotEmpty ? effectiveCounterparty : null,
      paymentMode: extraction.paymentMode,
      description: candidateDescription,
      normalizationStatus: 'NORMALIZED',
      reviewStatus: extraction.needsReview ? 'REVIEW_REQUIRED' : 'NOT_REQUIRED',
    );
  }

  /// High-precision deterministic parser for Indian bank & UPI notifications/SMS
  ExtractedFinancialEvidence extractFinancialDetails({
    required String text,
    String? declaredAmount,
    String? declaredType,
    String? counterpartyName,
    required String merchantId,
  }) {
    final lower = text.toLowerCase();

    // 1. Check for OTP / Security verification codes
    if (lower.contains('otp') || lower.contains('verification code') || lower.contains('one time password') || lower.contains('secret code') || lower.contains('do not share')) {
      final isOtpOnly = !lower.contains('debited') && !lower.contains('credited') && !lower.contains('paid you');
      if (isOtpOnly) {
        return ExtractedFinancialEvidence(
          amount: '0.00',
          amountPaise: 0,
          transactionType: 'UNKNOWN',
          paymentMode: 'UNKNOWN',
          rawClassification: 'OTP',
          isEligibleTransaction: false,
          needsReview: false,
          fingerprint: generateEvidenceFingerprint(merchantId: merchantId, amountPaise: 0, direction: 'OTP'),
        );
      }
    }

    // 2. Check for Promotional / Non-transactional messaging
    if (lower.contains('pre-approved') || lower.contains('apply now') || lower.contains('get loan') || lower.contains('congratulations! you are eligible') || lower.contains('flat off on your next')) {
      return ExtractedFinancialEvidence(
        amount: '0.00',
        amountPaise: 0,
        transactionType: 'UNKNOWN',
        paymentMode: 'UNKNOWN',
        rawClassification: 'PROMO',
        isEligibleTransaction: false,
        needsReview: false,
        fingerprint: generateEvidenceFingerprint(merchantId: merchantId, amountPaise: 0, direction: 'PROMO'),
      );
    }

    // 3. Check for Payment Request (e.g. "X has requested money from you")
    if (lower.contains('requested money') || lower.contains('request for rs') || lower.contains('collect request') || lower.contains('has requested ₹')) {
      return ExtractedFinancialEvidence(
        amount: '0.00',
        amountPaise: 0,
        transactionType: 'UNKNOWN',
        paymentMode: 'UPI',
        rawClassification: 'PAYMENT_REQUEST',
        isEligibleTransaction: false,
        needsReview: true,
        reviewReason: 'Payment request received; not settled transaction',
        fingerprint: generateEvidenceFingerprint(merchantId: merchantId, amountPaise: 0, direction: 'REQ'),
      );
    }

    // 4. Check for Failed / Declined Payments
    if (lower.contains('failed') || lower.contains('declined') || lower.contains('unsuccessful') || lower.contains('could not be processed') || lower.contains('transaction failed')) {
      return ExtractedFinancialEvidence(
        amount: '0.00',
        amountPaise: 0,
        transactionType: 'UNKNOWN',
        paymentMode: 'UNKNOWN',
        rawClassification: 'FAILED',
        isEligibleTransaction: false,
        needsReview: false,
        reviewReason: 'Transaction declined or failed at bank gateway',
        fingerprint: generateEvidenceFingerprint(merchantId: merchantId, amountPaise: 0, direction: 'FAILED'),
      );
    }

    // 5. Balance Inquiry Only (e.g. "Avail Bal Rs 1,450.00 in A/c XX1234")
    final hasBalKeywords = lower.contains('avail bal') || lower.contains('available balance') || lower.contains('clear balance') || lower.contains('bal rs.') || lower.contains('balance is');
    final hasTxKeywords = lower.contains('debited') || lower.contains('credited') || lower.contains('paid you') || lower.contains('sent you') || lower.contains('transferred') || lower.contains('paid rs') || lower.contains('spent');

    if (hasBalKeywords && !hasTxKeywords && declaredAmount == null) {
      return ExtractedFinancialEvidence(
        amount: '0.00',
        amountPaise: 0,
        transactionType: 'UNKNOWN',
        paymentMode: 'UNKNOWN',
        rawClassification: 'BALANCE_ONLY',
        isEligibleTransaction: false,
        needsReview: false,
        fingerprint: generateEvidenceFingerprint(merchantId: merchantId, amountPaise: 0, direction: 'BAL'),
      );
    }

    // 6. Direction Classification
    String txType = declaredType ?? 'UNKNOWN';
    String rawClassification = 'UNKNOWN';
    bool isCredit = false;
    bool isDebit = false;

    if (lower.contains('refunded') || lower.contains('refund')) {
      txType = 'CREDIT';
      rawClassification = 'REFUND';
      isCredit = true;
    } else if (lower.contains('reversed') || lower.contains('reversal')) {
      txType = 'CREDIT';
      rawClassification = 'REVERSAL';
      isCredit = true;
    } else if (lower.contains('atm') || lower.contains('cash withdrawal')) {
      txType = 'DEBIT';
      rawClassification = 'ATM';
      isDebit = true;
    } else if (lower.contains('annual fee') || lower.contains('sms charge') || lower.contains('service charge') || lower.contains('bank charge')) {
      txType = 'DEBIT';
      rawClassification = 'BANK_CHARGE';
      isDebit = true;
    } else if (lower.contains('paid you') || lower.contains('sent you') || lower.contains('credited') || lower.contains('received from') || lower.contains('deposited')) {
      txType = 'CREDIT';
      rawClassification = 'CREDIT';
      isCredit = true;
    } else if (lower.contains('you paid') || lower.contains('debited') || lower.contains('paid to') || lower.contains('transferred to') || lower.contains('spent')) {
      txType = 'DEBIT';
      rawClassification = 'DEBIT';
      isDebit = true;
    }

    // 7. Extract Exact Transaction Amount (Avoid picking balance figures)
    String? extractedAmount = declaredAmount;

    if (extractedAmount == null && text.isNotEmpty) {
      // Priority 1: Paired transaction patterns (verb-first and amount-first)
      final pairedPatterns = [
        RegExp(
          r'(?:debited(?:\s+by)?|credited(?:\s+with)?|paid\s+you|sent\s+you|paid|received|sent|transferred|spent|refunded|deposited).{0,25}?(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?).{0,50}?(?:debited|deducted|spent|paid|credited|received|deposited)',
          caseSensitive: false,
        ),
      ];

      for (final p in pairedPatterns) {
        final match = p.firstMatch(text);
        if (match != null) {
          extractedAmount = match.group(1)!.replaceAll(',', '');
          break;
        }
      }

      if (extractedAmount == null) {
        // Priority 2: Standard currency amount ignoring balance prefixes
        final generalAmtRegex = RegExp(
          r'(?<!(?:bal|balance|avail|available)[\s\:\.\=]*)(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
          caseSensitive: false,
        );
        final genMatch = generalAmtRegex.firstMatch(text);
        if (genMatch != null) {
          extractedAmount = genMatch.group(1)!.replaceAll(',', '');
        }
      }
    }

    int amountPaise = 0;
    if (extractedAmount != null && extractedAmount.isNotEmpty) {
      try {
        amountPaise = MigrationVerificationService.parseExactPaise(extractedAmount);
      } catch (_) {
        amountPaise = 0;
      }
    }

    // 8. Extract Reference / UTR / RRN
    String? reference;
    final utrRegex = RegExp(
      r'(?:UPI\s*Ref(?:\s*no)?|UTR(?:\s*no)?|Txn\s*ID|RRN|Ref(?:\s*no)?)\s*[:\s]*([A-Za-z0-9_-]+)',
      caseSensitive: false,
    );
    final utrMatch = utrRegex.firstMatch(text);
    if (utrMatch != null) {
      reference = utrMatch.group(1)!.trim();
    }

    // 9. Extract Masked Account Number (e.g. A/c XX1234 or ending 4321)
    String? maskedAccount;
    final acctRegex = RegExp(
      r'(?:A/c|Acct|Account|card)\s*(?:no\.?)?\s*([X\*]+[\d]{3,4}|[\d]{4})',
      caseSensitive: false,
    );
    final acctMatch = acctRegex.firstMatch(text);
    if (acctMatch != null) {
      maskedAccount = acctMatch.group(1)!.trim();
    }

    // 10. Extract Counterparty
    String? detectedCounterparty = counterpartyName;
    if (detectedCounterparty == null && text.isNotEmpty) {
      // E.g. "KAVITA SANDEEP PATHAK paid you ₹1.00"
      final paidYouRegex = RegExp(r'^([A-Za-z0-9\s]{3,35}?)\s+(?:paid|sent)\s+you', caseSensitive: false);
      final paidYouMatch = paidYouRegex.firstMatch(text.trim());
      if (paidYouMatch != null) {
        detectedCounterparty = paidYouMatch.group(1)!.trim();
      } else {
        // E.g. "transferred to <NAME>", "paid to <NAME>", "credited by <NAME>"
        // Skip match if immediately followed by currency symbol (e.g. "debited by Rs.")
        final matches = RegExp(
          r'(?:transferred\s+to|paid\s+to|sent\s+to|to|from|by|at|vpa)\s+([A-Za-z0-9\.\@\s]{3,35}?)(?:\s+on|\s+ref|\s+upi|\s+avl|\.|$)',
          caseSensitive: false,
        ).allMatches(text);

        for (final m in matches) {
          final cand = m.group(1)!.trim();
          final lowerCand = cand.toLowerCase();
          if (lowerCand.startsWith('rs') ||
              lowerCand.startsWith('inr') ||
              lowerCand.startsWith('₹') ||
              lowerCand.contains('account') ||
              lowerCand.contains('your') ||
              lowerCand.contains('a/c')) {
            continue;
          }
          detectedCounterparty = cand;
          break;
        }
      }
    }

    // 11. Normalize Counterparty & Categorize
    String? normalizedName;
    String? category;
    if (detectedCounterparty != null && detectedCounterparty.isNotEmpty) {
      final cleanCp = detectedCounterparty.trim();
      final upperCp = cleanCp.toUpperCase();

      final words = upperCp.split(RegExp(r'\s+'));
      for (final entry in _knownAliases.entries) {
        if (upperCp == entry.key || words.contains(entry.key)) {
          normalizedName = entry.value;
          break;
        }
      }
      normalizedName ??= cleanCp;

      if (_deterministicCategories.containsKey(normalizedName)) {
        category = _deterministicCategories[normalizedName];
      }
    }

    // 12. Payment Mode
    String paymentMode = 'UNKNOWN';
    if (lower.contains('upi') || lower.contains('vpa') || text.contains('@')) {
      paymentMode = 'UPI';
    } else if (lower.contains('card') || lower.contains('pos') || lower.contains('debit card') || lower.contains('credit card')) {
      paymentMode = 'CARD';
    } else if (lower.contains('netbanking') || lower.contains('imps') || lower.contains('neft') || lower.contains('rtgs')) {
      paymentMode = 'NETBANKING';
    } else if (rawClassification == 'ATM') {
      paymentMode = 'CASH';
    }

    final bool isEligible = amountPaise > 0 && (isCredit || isDebit);
    final bool needsReview = amountPaise <= 0 || txType == 'UNKNOWN' || detectedCounterparty == null;
    final String? reviewReason = amountPaise <= 0
        ? 'Missing or unparseable amount'
        : (txType == 'UNKNOWN' ? 'Ambiguous transaction direction' : null);

    final fingerprint = generateEvidenceFingerprint(
      merchantId: merchantId,
      amountPaise: amountPaise,
      direction: txType,
      reference: reference,
      counterparty: normalizedName ?? detectedCounterparty,
    );

    return ExtractedFinancialEvidence(
      amount: extractedAmount ?? '0.00',
      amountPaise: amountPaise,
      transactionType: txType,
      paymentMode: paymentMode,
      counterparty: detectedCounterparty,
      normalizedCounterparty: normalizedName,
      assignedCategory: category,
      referenceNumber: reference,
      maskedAccount: maskedAccount,
      rawClassification: rawClassification,
      isEligibleTransaction: isEligible,
      needsReview: needsReview,
      reviewReason: reviewReason,
      fingerprint: fingerprint,
    );
  }

  /// Check whether an evidence fingerprint exists in deletion tombstones table
  Future<bool> isFingerprintTombstoned({
    required String merchantId,
    required String fingerprint,
    String? sourceReference,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return false;

    final rows = await driver.query(
      '''
      SELECT id FROM ${LocalDatabaseSchema.tableEvidenceTombstones}
      WHERE merchant_id = ? AND (evidence_fingerprint = ? OR (source_reference IS NOT NULL AND source_reference = ?))
      ''',
      [merchantId, fingerprint, sourceReference ?? ''],
    );
    return rows.isNotEmpty;
  }

  /// Create deletion tombstone when merchant deletes or rejects a transaction
  Future<void> createTombstone({
    required String merchantId,
    required String fingerprint,
    String? sourceReference,
    String reason = 'MERCHANT_DELETED',
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final tombstoneId = const Uuid().v4();

    await driver.execute(
      '''
      INSERT OR IGNORE INTO ${LocalDatabaseSchema.tableEvidenceTombstones} (
        id, merchant_id, evidence_fingerprint, source_reference, reason, created_at
      ) VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [tombstoneId, merchantId, fingerprint, sourceReference, reason, nowIso],
    );
  }

  /// Retrieve user categorization memory override for a counterparty
  Future<Map<String, dynamic>?> getCounterpartyOverride({
    required String merchantId,
    required String rawAlias,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return null;

    final rows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableCounterpartyOverrides}
      WHERE merchant_id = ? AND raw_counterparty_alias = ?
      ''',
      [merchantId, rawAlias.trim().toLowerCase()],
    );

    if (rows.isNotEmpty) {
      return rows.first;
    }
    return null;
  }

  /// Record or update merchant categorization correction memory
  Future<void> recordCounterpartyOverride({
    required String merchantId,
    required String rawAlias,
    required String normalizedName,
    required String assignedCategory,
    bool applyToHistorical = false,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final overrideId = const Uuid().v4();
    final cleanAlias = rawAlias.trim().toLowerCase();

    await driver.execute(
      '''
      INSERT INTO ${LocalDatabaseSchema.tableCounterpartyOverrides} (
        id, merchant_id, raw_counterparty_alias, normalized_name, assigned_category,
        apply_to_historical, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(merchant_id, raw_counterparty_alias) DO UPDATE SET
        normalized_name = excluded.normalized_name,
        assigned_category = excluded.assigned_category,
        apply_to_historical = excluded.apply_to_historical,
        updated_at = excluded.updated_at
      ''',
      [
        overrideId,
        merchantId,
        cleanAlias,
        normalizedName.trim(),
        assignedCategory.trim(),
        applyToHistorical ? 1 : 0,
        nowIso,
        nowIso,
      ],
    );

    // If merchant explicitly requested historical propagation, update previous canonical transactions
    if (applyToHistorical) {
      await driver.execute(
        '''
        UPDATE ${LocalDatabaseSchema.tableCanonicalTransactions}
        SET counterparty_name = ?,
            description = description || ' [Category: ' || ? || ']'
        WHERE merchant_id = ? AND LOWER(counterparty_name) = ?
        ''',
        [normalizedName.trim(), assignedCategory.trim(), merchantId, cleanAlias],
      );
    }
  }
}
