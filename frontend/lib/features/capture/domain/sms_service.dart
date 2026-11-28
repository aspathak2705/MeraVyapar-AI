import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:crypto/crypto.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database_schema.dart';
import '../../../core/database/local_database_service.dart';
import 'sms_parser.dart';

/// Deterministic ID to avoid duplicate entries between live broadcasts and inbox sync.
String smsIdentity(SmsMessage message, {bool receiptTime = false}) {
  final timestamp = !receiptTime && (message.dateSent ?? 0) > 0
      ? message.dateSent
      : message.date;
  return 'sms:${message.address}:${timestamp}:${message.body}';
}

/// Must be a top-level function for telephony background isolate execution.
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  final body = message.body;
  if (body == null || body.trim().isEmpty) return;

  final parsed = SmsParser.parse(body);
  if (parsed == null || !parsed.isEligible) return;

  final id = smsIdentity(message);
  final DateTime date;
  if (message.dateSent != null && message.dateSent! > 0) {
    date = DateTime.fromMillisecondsSinceEpoch(message.dateSent!, isUtc: true);
  } else if (message.date != null && message.date! > 0) {
    date = DateTime.fromMillisecondsSinceEpoch(message.date!, isUtc: true);
  } else {
    date = DateTime.now().toUtc();
  }

  await SmsService.persistParsedSmsTransaction(
    smsId: id,
    parsed: parsed,
    senderAddress: message.address ?? 'SMS',
    occurredAt: date,
    rawBody: body,
  );
}

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final Telephony _telephony = Telephony.instance;
  bool _listening = false;
  Future<void>? _sync;

  bool get isListening => _listening;

  bool get isPlatformSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Check runtime SMS permissions
  Future<bool> checkSmsPermissions() async {
    if (!isPlatformSupported) return false;
    try {
      final status = await Permission.sms.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Request runtime SMS permissions
  Future<bool> requestSmsPermissions() async {
    if (!isPlatformSupported) return false;
    try {
      final status = await Permission.sms.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Subscribe to incoming SMS broadcasts (foreground & background)
  void startListening() {
    if (!isPlatformSupported) return;
    if (_listening) return;

    try {
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          backgroundMessageHandler(message);
        },
        onBackgroundMessage: backgroundMessageHandler,
      );
      _listening = true;
      syncInbox();
    } catch (e) {
      debugPrint('SMS listener registration failed: $e');
    }
  }

  /// Recover missed SMS transactions from the past 30 days
  Future<void> syncInbox() => _sync ??= _syncInbox().whenComplete(() {
        _sync = null;
      });

  Future<void> _syncInbox() async {
    if (!isPlatformSupported) return;
    try {
      final granted = await checkSmsPermissions();
      if (!granted) return;

      final since = DateTime.now().subtract(const Duration(days: 30));
      final messages = await _telephony.getInboxSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.DATE_SENT,
        ],
        filter: SmsFilter.where(SmsColumn.DATE)
            .greaterThanOrEqualTo(since.millisecondsSinceEpoch.toString()),
      );

      for (final msg in messages) {
        await backgroundMessageHandler(msg);
      }
    } catch (error) {
      debugPrint('SMS inbox sync failed: $error');
    }
  }

  /// Resume listener and sync on app foreground
  Future<void> resume() async {
    if (!isPlatformSupported) return;
    final granted = await checkSmsPermissions();
    if (granted) {
      startListening();
      await syncInbox();
    }
  }

  /// Core database persistence implementation for parsed SMS transactions.
  /// Converts into canonical SQLite records with exact integer minor units (paise).
  static Future<bool> persistParsedSmsTransaction({
    required String smsId,
    required ParsedSmsTransaction parsed,
    required String senderAddress,
    required DateTime occurredAt,
    required String rawBody,
    LocalDatabaseService? dbService,
  }) async {
    final db = dbService ?? LocalDatabaseService.instance;
    if (!db.isInitialized) {
      await db.initialize();
    }
    final driver = db.driver;
    if (driver == null) return false;

    // 1. Locate active merchant ID
    final merchantRows = await driver.query(
      '''
      SELECT id FROM ${LocalDatabaseSchema.tableMerchantProfile}
      WHERE status = 'ACTIVE'
      LIMIT 1
      ''',
    );
    if (merchantRows.isEmpty) {
      return false;
    }
    final merchantId = merchantRows.first['id'] as String;

    // 2. Deterministic Idempotency Key & Evidence Fingerprint
    final shaHash = sha256.convert(utf8.encode(smsId)).toString();
    final idempotencyKey = 'sms_$shaHash';

    // 3. Deletion Tombstone Check (Prevent resurrecting merchant-deleted items)
    final tombstoneRows = await driver.query(
      '''
      SELECT id FROM ${LocalDatabaseSchema.tableEvidenceTombstones}
      WHERE merchant_id = ? AND (
        evidence_fingerprint = ? OR
        (source_reference IS NOT NULL AND source_reference != '' AND source_reference = ?)
      )
      ''',
      [merchantId, idempotencyKey, parsed.bankRefNo],
    );
    if (tombstoneRows.isNotEmpty) {
      return false; // Tombstoned by merchant
    }

    // 4. Duplicate Check in Canonical Transactions
    final existingCanonical = await driver.query(
      '''
      SELECT id FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE merchant_id = ? AND (
        idempotency_key = ? OR
        (transaction_reference IS NOT NULL AND transaction_reference != '' AND transaction_reference = ?)
      )
      ''',
      [merchantId, idempotencyKey, parsed.bankRefNo],
    );
    if (existingCanonical.isNotEmpty) {
      return false; // Already recorded
    }

    // 5. Merchant Counterparty Categorization Memory Check
    String effectiveCounterparty = parsed.merchant;
    String? assignedCategory;

    if (effectiveCounterparty.isNotEmpty && effectiveCounterparty != 'Unknown') {
      final overrideRows = await driver.query(
        '''
        SELECT normalized_name, assigned_category
        FROM ${LocalDatabaseSchema.tableCounterpartyOverrides}
        WHERE merchant_id = ? AND raw_counterparty_alias = ?
        ''',
        [merchantId, effectiveCounterparty.toLowerCase().trim()],
      );
      if (overrideRows.isNotEmpty) {
        effectiveCounterparty = overrideRows.first['normalized_name'] as String;
        assignedCategory = overrideRows.first['assigned_category'] as String?;
      }
    }

    final txId = const Uuid().v4();
    final evidenceId = const Uuid().v4();
    final candidateId = const Uuid().v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final occurredIso = occurredAt.toIso8601String();

    final desc = assignedCategory != null
        ? 'SMS from $senderAddress [Category: $assignedCategory]'
        : 'SMS from $senderAddress';

    // 6. Persist to Evidence Metadata
    await driver.execute(
      '''
      INSERT OR IGNORE INTO ${LocalDatabaseSchema.tableEvidenceMetadata} (
        id, merchant_id, filename, mime_type, file_size_bytes,
        sha256_hash, storage_relative_path, captured_at, source_type
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        evidenceId,
        merchantId,
        'sms_${occurredAt.millisecondsSinceEpoch}.txt',
        'text/plain',
        rawBody.length,
        shaHash,
        'evidence/sms_$shaHash.txt',
        occurredIso,
        'SMS',
      ],
    );

    // 7. Persist to Transaction Candidates (lifecycle status: PROMOTED)
    await driver.execute(
      '''
      INSERT OR IGNORE INTO ${LocalDatabaseSchema.tableTransactionCandidates} (
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
        parsed.type,
        parsed.amountPaise,
        'INR',
        occurredIso,
        effectiveCounterparty,
        parsed.paymentMode,
        desc,
        'PROMOTED',
        nowIso,
        nowIso,
      ],
    );

    // 8. Persist to Canonical Transactions (Direct Ledger & Cash-Flow Integration)
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
        parsed.amountPaise,
        'INR',
        parsed.type, // 'MONEY_IN' or 'MONEY_OUT'
        parsed.paymentMode,
        effectiveCounterparty,
        null,
        parsed.bankRefNo.isNotEmpty ? parsed.bankRefNo : null,
        desc,
        occurredIso,
        'SETTLED',
        'SMS',
        senderAddress,
        0,
        idempotencyKey,
        nowIso,
        nowIso,
      ],
    );

    return true;
  }
}
