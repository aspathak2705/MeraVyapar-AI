import '../../../core/database/local_database_service.dart';
import '../../../core/database/local_database_schema.dart';

enum FigNodeType { merchant, counterparty, transaction, paymentPromise, financialEvent, evidence, supplier, purchaseRequest, supplierQuotation, supplierObligation }

class FigNode {
  final String id;
  final FigNodeType type;
  final String label;
  final Map<String, dynamic> attributes;

  const FigNode({
    required this.id,
    required this.type,
    required this.label,
    required this.attributes,
  });
}

class FigEdge {
  final String sourceId;
  final String targetId;
  final String relationshipType;
  final Map<String, dynamic> metadata;

  const FigEdge({
    required this.sourceId,
    required this.targetId,
    required this.relationshipType,
    required this.metadata,
  });
}

class FigGraphSnapshot {
  final List<FigNode> nodes;
  final List<FigEdge> edges;
  final DateTime generatedAt;

  const FigGraphSnapshot({
    required this.nodes,
    required this.edges,
    required this.generatedAt,
  });
}

/// On-device Financial Intelligence Graph (FIG) derivation service.
/// Derives grounded entity relationships strictly from confirmed SQLite ledger records.
/// Never serves as the authoritative source of truth.
class LocalFinancialIntelligenceGraphService {
  final LocalDatabaseService _dbService;

  LocalFinancialIntelligenceGraphService({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Construct a dynamic FIG snapshot for the active merchant.
  Future<FigGraphSnapshot> buildGraphSnapshot({
    required String merchantId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    final nodes = <FigNode>[];
    final edges = <FigEdge>[];

    // 1. Merchant Root Node
    nodes.add(FigNode(
      id: merchantId,
      type: FigNodeType.merchant,
      label: 'Merchant Profile',
      attributes: {'merchant_id': merchantId},
    ));

    // 2. Counterparty Nodes
    final cpRows = await driver.query(
      '''
      SELECT id, name, category, phone_number
      FROM ${LocalDatabaseSchema.tableFinancialCounterparties}
      WHERE merchant_id = ?
      ''',
      [merchantId],
    );

    final cpIds = <String>{};
    for (final cp in cpRows) {
      final cpId = cp['id'] as String;
      cpIds.add(cpId);
      final cpName = cp['name'] as String;
      nodes.add(FigNode(
        id: cpId,
        type: FigNodeType.counterparty,
        label: cpName,
        attributes: {
          'category': cp['category'] ?? 'CUSTOMER',
          'phone': cp['phone_number'],
        },
      ));

      // Edge: Merchant -> Counterparty
      edges.add(FigEdge(
        sourceId: merchantId,
        targetId: cpId,
        relationshipType: 'INTERACTS_WITH',
        metadata: {'category': cp['category']},
      ));
    }

    // 3. Transaction Nodes & Links
    final txRows = await driver.query(
      '''
      SELECT id, counterparty_id, counterparty_name, amount_minor_units, transaction_type, occurred_at
      FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE merchant_id = ?
      ORDER BY occurred_at DESC
      LIMIT 100
      ''',
      [merchantId],
    );

    for (final tx in txRows) {
      final txId = tx['id'] as String;
      final cpId = tx['counterparty_id'] as String?;
      final type = tx['transaction_type'] as String? ?? 'UNKNOWN';
      final paise = tx['amount_minor_units'] as int? ?? 0;

      nodes.add(FigNode(
        id: txId,
        type: FigNodeType.transaction,
        label: '₹${(paise / 100.0).toStringAsFixed(2)} $type',
        attributes: {
          'type': type,
          'amount_paise': paise,
          'occurred_at': tx['occurred_at'],
        },
      ));

      // Edge: Merchant -> Transaction
      edges.add(FigEdge(
        sourceId: merchantId,
        targetId: txId,
        relationshipType: type == 'CREDIT' ? 'RECEIVED_INTO' : 'PAID_OUT_FROM',
        metadata: {'amount_paise': paise},
      ));

      // Edge: Counterparty -> Transaction (if linked)
      if (cpId != null && cpIds.contains(cpId)) {
        edges.add(FigEdge(
          sourceId: cpId,
          targetId: txId,
          relationshipType: 'TRANSACTED',
          metadata: {'amount_paise': paise},
        ));
      }
    }

    // 4. Payment Promise Nodes & Links
    final promiseRows = await driver.query(
      '''
      SELECT id, counterparty_id, counterparty_name, amount_minor_units, direction, status, due_date
      FROM ${LocalDatabaseSchema.tablePaymentPromises}
      WHERE merchant_id = ?
      ''',
      [merchantId],
    );

    for (final pr in promiseRows) {
      final prId = pr['id'] as String;
      final cpId = pr['counterparty_id'] as String?;
      final status = pr['status'] as String? ?? 'OPEN';
      final paise = pr['amount_minor_units'] as int? ?? 0;

      nodes.add(FigNode(
        id: prId,
        type: FigNodeType.paymentPromise,
        label: 'Promise ₹${(paise / 100.0).toStringAsFixed(2)} ($status)',
        attributes: {
          'status': status,
          'direction': pr['direction'],
          'due_date': pr['due_date'],
        },
      ));

      if (cpId != null && cpIds.contains(cpId)) {
        edges.add(FigEdge(
          sourceId: cpId,
          targetId: prId,
          relationshipType: 'PROMISED_PAYMENT',
          metadata: {'status': status, 'amount_paise': paise},
        ));
      }
    }

    // 5. Procurement Entities (Suppliers & Outgoing Obligations)
    try {
      final supplierRows = await driver.query(
        'SELECT id, name, category FROM ${LocalDatabaseSchema.tableSuppliers} WHERE merchant_id = ?',
        [merchantId],
      );
      for (final s in supplierRows) {
        final sId = s['id'] as String;
        nodes.add(FigNode(
          id: sId,
          type: FigNodeType.supplier,
          label: 'Supplier: ${s['name']}',
          attributes: {'category': s['category']},
        ));
        edges.add(FigEdge(
          sourceId: merchantId,
          targetId: sId,
          relationshipType: 'PROCURES_FROM',
          metadata: {'supplier_name': s['name']},
        ));
      }

      final obligationRows = await driver.query(
        'SELECT id, supplier_id, total_obligation_minor_units, outstanding_minor_units, status FROM ${LocalDatabaseSchema.tableSupplierObligations} WHERE merchant_id = ?',
        [merchantId],
      );
      for (final ob in obligationRows) {
        final obId = ob['id'] as String;
        final sId = ob['supplier_id'] as String;
        final outPaise = ob['outstanding_minor_units'] as int? ?? 0;
        nodes.add(FigNode(
          id: obId,
          type: FigNodeType.supplierObligation,
          label: 'Obligation ₹${(outPaise / 100.0).toStringAsFixed(2)}',
          attributes: {'status': ob['status'], 'outstanding_paise': outPaise},
        ));
        edges.add(FigEdge(
          sourceId: sId,
          targetId: obId,
          relationshipType: 'HOLDS_OBLIGATION',
          metadata: {'status': ob['status']},
        ));
      }
    } catch (_) {}

    return FigGraphSnapshot(
      nodes: nodes,
      edges: edges,
      generatedAt: DateTime.now().toUtc(),
    );
  }
}
