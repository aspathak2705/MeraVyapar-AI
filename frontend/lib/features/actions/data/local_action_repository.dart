import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../../core/database/local_database_schema.dart';
import '../domain/communication_action_model.dart';
import '../domain/communication_audit_event_model.dart';

/// Local-First Action Repository.
/// All communication drafts and audit events are persisted in local SQLite.
/// Completely operational offline without requiring backend or PostgreSQL connection.
class LocalActionRepository {
  final LocalDatabaseService _dbService;

  LocalActionRepository({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Fetch all communication drafts for the active merchant.
  Future<List<CommunicationAction>> fetchActions({
    required String merchantId,
    String? statusFilter,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return [];

    String sql = '''
      SELECT * FROM ${LocalDatabaseSchema.tableCommunicationDrafts}
      WHERE merchant_id = ?
    ''';
    final List<dynamic> args = [merchantId];

    if (statusFilter != null && statusFilter.isNotEmpty) {
      sql += ' AND UPPER(status) = ?';
      args.add(statusFilter.toUpperCase());
    }

    sql += ' ORDER BY created_at DESC';

    final rows = await driver.query(sql, args);
    return rows.map((r) => _mapRowToCommunicationAction(r)).toList();
  }

  /// Get single action by ID scoped to merchant.
  Future<CommunicationAction?> getActionById({
    required String actionId,
    required String merchantId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return null;

    final rows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableCommunicationDrafts}
      WHERE id = ? AND merchant_id = ?
      ''',
      [actionId, merchantId],
    );

    if (rows.isEmpty) return null;
    return _mapRowToCommunicationAction(rows.first);
  }

  /// Draft a payment reminder locally from local payment promise data.
  /// If existing draft exists for this promise, reuse it; otherwise create template draft.
  Future<CommunicationAction> draftPaymentReminder({
    required String promiseId,
    required String channel,
    required String merchantId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) {
      throw StateError('Local database driver not initialized');
    }

    // 1. Check if a draft already exists for this promise and merchant
    final existingRows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableCommunicationDrafts}
      WHERE promise_id = ? AND merchant_id = ? AND status != 'CANCELLED'
      ORDER BY created_at DESC
      ''',
      [promiseId, merchantId],
    );

    if (existingRows.isNotEmpty) {
      return _mapRowToCommunicationAction(existingRows.first);
    }

    // 2. Fetch promise details from local SQLite
    final promiseRows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tablePaymentPromises}
      WHERE id = ? AND merchant_id = ?
      ''',
      [promiseId, merchantId],
    );

    String counterpartyName = 'Customer';
    String amountFormatted = '0.00';
    String dueDateStr = 'soon';
    String? recipientPhone;

    if (promiseRows.isNotEmpty) {
      final pRow = promiseRows.first;
      counterpartyName = pRow['counterparty_name'] as String? ?? 'Customer';
      final amountMinor = pRow['amount_minor_units'] as int? ?? 0;
      amountFormatted = (amountMinor / 100.0).toStringAsFixed(2);
      final rawDueDate = pRow['due_date'] as String?;
      if (rawDueDate != null) {
        dueDateStr = rawDueDate.split('T').first;
      }

      // Check counterparty phone if counterparty_id present
      final cpId = pRow['counterparty_id'] as String?;
      if (cpId != null) {
        final cpRows = await driver.query(
          '''
          SELECT phone_number FROM ${LocalDatabaseSchema.tableFinancialCounterparties}
          WHERE id = ? AND merchant_id = ?
          ''',
          [cpId, merchantId],
        );
        if (cpRows.isNotEmpty) {
          recipientPhone = cpRows.first['phone_number'] as String?;
        }
      }
    }

    // 3. Construct deterministic, verified fact-based draft template
    final draftText = 'Namaste $counterpartyName ji, this is a gentle reminder regarding the payment of ₹$amountFormatted due on $dueDateStr. Kindly confirm once transferred. Thank you.';

    final actionId = const Uuid().v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final idempotencyKey = 'draft_${promiseId}_${DateTime.now().millisecondsSinceEpoch}';

    await driver.transaction((txn) async {
      await txn.execute(
        '''
        INSERT INTO ${LocalDatabaseSchema.tableCommunicationDrafts} (
          id, merchant_id, promise_id, channel, recipient_phone,
          recipient_name, draft_content, status, created_at,
          action_type, idempotency_key
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          actionId,
          merchantId,
          promiseId,
          channel.toUpperCase(),
          recipientPhone,
          counterpartyName,
          draftText,
          'DRAFT',
          nowIso,
          'PAYMENT_REMINDER',
          idempotencyKey,
        ],
      );

      // Audit event
      await txn.execute(
        '''
        INSERT INTO ${LocalDatabaseSchema.tableAuditLog} (
          id, merchant_id, action_type, entity_type, entity_id, details_json, occurred_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          const Uuid().v4(),
          merchantId,
          'DRAFT_CREATED',
          'COMMUNICATION_ACTION',
          actionId,
          jsonEncode({
            'channel': channel,
            'promise_id': promiseId,
            'status': 'DRAFT',
          }),
          nowIso,
        ],
      );
    });

    final created = await getActionById(actionId: actionId, merchantId: merchantId);
    return created!;
  }

  /// Update draft content and transition status to READY_FOR_REVIEW.
  Future<CommunicationAction> updateDraft({
    required String actionId,
    required String finalContent,
    required String merchantId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) {
      throw StateError('Local database driver not initialized');
    }

    final current = await getActionById(actionId: actionId, merchantId: merchantId);
    if (current == null) {
      throw ArgumentError('Action not found: $actionId');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();

    await driver.transaction((txn) async {
      await txn.execute(
        '''
        UPDATE ${LocalDatabaseSchema.tableCommunicationDrafts}
        SET final_content = ?, status = 'READY_FOR_REVIEW'
        WHERE id = ? AND merchant_id = ?
        ''',
        [finalContent, actionId, merchantId],
      );

      await txn.execute(
        '''
        INSERT INTO ${LocalDatabaseSchema.tableAuditLog} (
          id, merchant_id, action_type, entity_type, entity_id, details_json, occurred_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          const Uuid().v4(),
          merchantId,
          'DRAFT_EDITED',
          'COMMUNICATION_ACTION',
          actionId,
          jsonEncode({
            'previous_status': current.status.toDisplayString(),
            'new_status': 'READY_FOR_REVIEW',
          }),
          nowIso,
        ],
      );
    });

    return (await getActionById(actionId: actionId, merchantId: merchantId))!;
  }

  /// Confirm action by merchant. Transitions status to CONFIRMED_BY_MERCHANT.
  Future<CommunicationAction> confirmAction({
    required String actionId,
    required String merchantId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) {
      throw StateError('Local database driver not initialized');
    }

    final current = await getActionById(actionId: actionId, merchantId: merchantId);
    if (current == null) {
      throw ArgumentError('Action not found: $actionId');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();

    await driver.transaction((txn) async {
      await txn.execute(
        '''
        UPDATE ${LocalDatabaseSchema.tableCommunicationDrafts}
        SET status = 'CONFIRMED_BY_MERCHANT', confirmed_at = ?
        WHERE id = ? AND merchant_id = ?
        ''',
        [nowIso, actionId, merchantId],
      );

      await txn.execute(
        '''
        INSERT INTO ${LocalDatabaseSchema.tableAuditLog} (
          id, merchant_id, action_type, entity_type, entity_id, details_json, occurred_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          const Uuid().v4(),
          merchantId,
          'ACTION_CONFIRMED',
          'COMMUNICATION_ACTION',
          actionId,
          jsonEncode({
            'previous_status': current.status.toDisplayString(),
            'new_status': 'CONFIRMED_BY_MERCHANT',
          }),
          nowIso,
        ],
      );
    });

    return (await getActionById(actionId: actionId, merchantId: merchantId))!;
  }

  /// Cancel action.
  Future<CommunicationAction> cancelAction({
    required String actionId,
    required String merchantId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) {
      throw StateError('Local database driver not initialized');
    }

    final current = await getActionById(actionId: actionId, merchantId: merchantId);
    if (current == null) {
      throw ArgumentError('Action not found: $actionId');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();

    await driver.transaction((txn) async {
      await txn.execute(
        '''
        UPDATE ${LocalDatabaseSchema.tableCommunicationDrafts}
        SET status = 'CANCELLED'
        WHERE id = ? AND merchant_id = ?
        ''',
        [actionId, merchantId],
      );

      await txn.execute(
        '''
        INSERT INTO ${LocalDatabaseSchema.tableAuditLog} (
          id, merchant_id, action_type, entity_type, entity_id, details_json, occurred_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          const Uuid().v4(),
          merchantId,
          'ACTION_CANCELLED',
          'COMMUNICATION_ACTION',
          actionId,
          jsonEncode({
            'previous_status': current.status.toDisplayString(),
            'new_status': 'CANCELLED',
          }),
          nowIso,
        ],
      );
    });

    return (await getActionById(actionId: actionId, merchantId: merchantId))!;
  }

  /// Record external dispatch handoff (e.g., opened in OS share / WhatsApp / SMS).
  /// Preserves distinction between OS handoff and confirmed remote delivery.
  Future<CommunicationAction> recordExternalHandoff({
    required String actionId,
    required String merchantId,
    String? deliveryMode,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) {
      throw StateError('Local database driver not initialized');
    }

    final current = await getActionById(actionId: actionId, merchantId: merchantId);
    if (current == null) {
      throw ArgumentError('Action not found: $actionId');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();

    await driver.transaction((txn) async {
      await txn.execute(
        '''
        UPDATE ${LocalDatabaseSchema.tableCommunicationDrafts}
        SET status = 'SENT', dispatched_at = ?, delivery_mode = ?
        WHERE id = ? AND merchant_id = ?
        ''',
        [nowIso, deliveryMode ?? 'OS_SHARE_INTENT', actionId, merchantId],
      );

      await txn.execute(
        '''
        INSERT INTO ${LocalDatabaseSchema.tableAuditLog} (
          id, merchant_id, action_type, entity_type, entity_id, details_json, occurred_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          const Uuid().v4(),
          merchantId,
          'EXTERNAL_HANDOFF_DISPATCHED',
          'COMMUNICATION_ACTION',
          actionId,
          jsonEncode({
            'delivery_mode': deliveryMode ?? 'OS_SHARE_INTENT',
            'status': 'SENT',
          }),
          nowIso,
        ],
      );
    });

    return (await getActionById(actionId: actionId, merchantId: merchantId))!;
  }

  /// Retrieve local audit trail for a communication action.
  Future<List<CommunicationAuditEvent>> fetchAuditTrail({
    required String actionId,
    required String merchantId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return [];

    final rows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableAuditLog}
      WHERE entity_id = ? AND merchant_id = ?
      ORDER BY occurred_at ASC
      ''',
      [actionId, merchantId],
    );

    return rows.map((r) {
      Map<String, dynamic> meta = {};
      final jsonStr = r['details_json'] as String?;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          meta = jsonDecode(jsonStr) as Map<String, dynamic>;
        } catch (_) {}
      }

      return CommunicationAuditEvent(
        id: r['id'] as String,
        communicationActionId: r['entity_id'] as String,
        eventType: r['action_type'] as String,
        previousStatus: meta['previous_status'] as String?,
        newStatus: meta['new_status'] as String? ?? 'UNKNOWN',
        actorType: 'MERCHANT',
        metadataInfo: meta,
        occurredAt: DateTime.tryParse(r['occurred_at'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();
  }

  CommunicationAction _mapRowToCommunicationAction(Map<String, dynamic> row) {
    return CommunicationAction(
      id: row['id'] as String,
      merchantId: row['merchant_id'] as String,
      actionType: ActionType.fromString(row['action_type'] as String? ?? 'PAYMENT_REMINDER'),
      channel: CommunicationChannel.fromString(row['channel'] as String? ?? 'MANUAL'),
      status: ActionStatus.fromString(row['status'] as String? ?? 'DRAFT'),
      draftContent: row['draft_content'] as String? ?? '',
      finalContent: row['final_content'] as String?,
      targetEntityId: row['target_entity_id'] as String?,
      targetEntityType: row['target_entity_type'] as String?,
      promiseId: row['promise_id'] as String?,
      idempotencyKey: row['idempotency_key'] as String? ?? '',
      providerMessageId: row['provider_message_id'] as String?,
      providerName: row['provider_name'] as String?,
      deliveryMode: row['delivery_mode'] as String?,
      externalDeliveryConfirmed: false,
      errorCode: null,
      errorMessage: null,
      confirmedAt: row['confirmed_at'] != null ? DateTime.tryParse(row['confirmed_at'] as String) : null,
      sentAt: row['dispatched_at'] != null ? DateTime.tryParse(row['dispatched_at'] as String) : null,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
