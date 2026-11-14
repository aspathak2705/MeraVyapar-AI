import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../data/local_canonical_transaction_repository.dart';
import '../domain/canonical_transaction_model.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/database/local_database_schema.dart';
import '../../../core/database/migration/migration_verification_service.dart';

class ExtractedStatementRecord {
  final String date; // YYYY-MM-DD or raw date string
  final String description;
  final String amount; // formatted decimal string e.g. "1500.00"
  final String type; // CREDIT or DEBIT
  final String? counterparty;
  final String? reference;
  final bool isPossibleDuplicate;
  final String? duplicateReason;
  bool isSelected;

  ExtractedStatementRecord({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    this.counterparty,
    this.reference,
    this.isPossibleDuplicate = false,
    this.duplicateReason,
    this.isSelected = true,
  });

  ExtractedStatementRecord copyWith({
    String? date,
    String? description,
    String? amount,
    String? type,
    String? counterparty,
    String? reference,
    bool? isPossibleDuplicate,
    String? duplicateReason,
    bool? isSelected,
  }) {
    return ExtractedStatementRecord(
      date: date ?? this.date,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      counterparty: counterparty ?? this.counterparty,
      reference: reference ?? this.reference,
      isPossibleDuplicate: isPossibleDuplicate ?? this.isPossibleDuplicate,
      duplicateReason: duplicateReason ?? this.duplicateReason,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class StatementImportService {
  final LocalDatabaseService _dbService;
  final LocalCanonicalTransactionRepository _txRepo;

  StatementImportService({
    LocalDatabaseService? dbService,
    LocalCanonicalTransactionRepository? txRepo,
  })  : _dbService = dbService ?? LocalDatabaseService.instance,
        _txRepo = txRepo ?? LocalCanonicalTransactionRepository();

  /// Parse text or raw bytes from a selected statement (CSV, PDF-extracted text, TXT, UPI export)
  /// and normalize into extracted records.
  List<ExtractedStatementRecord> parseStatementContent(String content, {String formatHint = 'CSV'}) {
    final List<ExtractedStatementRecord> records = [];
    final lines = LineSplitter.split(content).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    if (lines.isEmpty) return records;

    // Check if CSV format (delimiter: comma, semicolon, or tab)
    if (formatHint.toUpperCase() == 'CSV' || content.contains(',') || content.contains(';')) {
      records.addAll(_parseCsvLines(lines));
    }

    // If CSV parsing produced no records or format is text/PDF stream, parse line-by-line using financial patterns
    if (records.isEmpty) {
      records.addAll(_parseTextStatementLines(lines));
    }

    return records;
  }

  /// Check possible duplicates against existing canonical transactions in SQLite
  Future<List<ExtractedStatementRecord>> detectDuplicates({
    required String merchantId,
    required List<ExtractedStatementRecord> candidates,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return candidates;

    final existingTxs = await _txRepo.getCanonicalTransactions(merchantId: merchantId);
    final List<ExtractedStatementRecord> evaluated = [];

    for (final cand in candidates) {
      bool isDup = false;
      String? reason;

      // 1. Reference matching
      if (cand.reference != null && cand.reference!.isNotEmpty) {
        final match = existingTxs.firstWhere(
          (tx) => tx.transactionReference != null && tx.transactionReference!.trim().toLowerCase() == cand.reference!.trim().toLowerCase(),
          orElse: () => const CanonicalTransactionModel(
            id: '',
            merchantId: '',
            currency: 'INR',
            transactionType: '',
            paymentMode: '',
            reconciliationStatus: '',
            candidateLinks: [],
          ),
        );
        if (match.id.isNotEmpty) {
          isDup = true;
          reason = 'Matches existing transaction ref: ${cand.reference}';
        }
      }

      // 2. Fingerprint matching: same amount, direction, and date (or description similarity)
      if (!isDup) {
        final candPaise = _amountToPaise(cand.amount);
        for (final tx in existingTxs) {
          final txPaise = tx.amount != null ? _amountToPaise(tx.amount!) : -1;
          if (txPaise == candPaise && tx.transactionType == cand.type) {
            // Check date match if available
            final txDate = tx.occurredAt != null && tx.occurredAt!.length >= 10 ? tx.occurredAt!.substring(0, 10) : '';
            final candDate = cand.date.length >= 10 ? cand.date.substring(0, 10) : '';
            if (txDate.isNotEmpty && candDate.isNotEmpty && txDate == candDate) {
              isDup = true;
              reason = 'Identical amount (₹${cand.amount}) and date ($candDate)';
              break;
            }
          }
        }
      }

      evaluated.add(cand.copyWith(
        isPossibleDuplicate: isDup,
        duplicateReason: reason,
        isSelected: !isDup, // Default to unchecked if duplicate
      ));
    }

    return evaluated;
  }

  /// Confirm and persist selected extracted records into canonical SQLite ledger
  Future<int> persistConfirmedTransactions({
    required String merchantId,
    required List<ExtractedStatementRecord> confirmedRecords,
    required String sourceDocumentName,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Database not initialized');

    int persistedCount = 0;
    for (final rec in confirmedRecords) {
      if (!rec.isSelected) continue;

      final candPaise = _amountToPaise(rec.amount);
      if (candPaise <= 0) continue; // Skip zero/invalid amounts

      // Unique idempotency key based on document + reference/fingerprint
      final fingerprintInput = '$sourceDocumentName|${rec.date}|${rec.amount}|${rec.type}|${rec.reference ?? rec.description}';
      final idempotency = 'stmt_${sha256.convert(utf8.encode(fingerprintInput)).toString().substring(0, 24)}';

      final txOccurred = rec.date.length >= 10
          ? '${rec.date.substring(0, 10)}T12:00:00Z'
          : DateTime.now().toUtc().toIso8601String();

      await _txRepo.createTransaction(
        merchantId: merchantId,
        amount: rec.amount,
        transactionType: rec.type,
        paymentMode: 'BANK_TRANSFER',
        counterpartyName: rec.counterparty,
        transactionReference: rec.reference,
        description: '${rec.description} (Imported: $sourceDocumentName)',
        occurredAt: txOccurred,
        idempotencyKey: idempotency,
        sourceType: 'STATEMENT_IMPORT',
      );
      persistedCount++;
    }

    return persistedCount;
  }

  // Helper: parse CSV lines
  List<ExtractedStatementRecord> _parseCsvLines(List<String> lines) {
    final List<ExtractedStatementRecord> records = [];
    int dateIdx = -1;
    int descIdx = -1;
    int creditIdx = -1;
    int debitIdx = -1;
    int amountIdx = -1;
    int refIdx = -1;

    String delimiter = ',';
    if (lines.first.contains(';') && !lines.first.contains(',')) {
      delimiter = ';';
    } else if (lines.first.contains('\t') && !lines.first.contains(',')) {
      delimiter = '\t';
    }

    // Inspect header
    final headerCells = lines.first.split(delimiter).map((c) => c.replaceAll('"', '').trim().toLowerCase()).toList();
    for (int i = 0; i < headerCells.length; i++) {
      final h = headerCells[i];
      if (h.contains('date') || h.contains('txn date') || h.contains('value date')) {
        dateIdx = i;
      } else if (h.contains('narration') || h.contains('description') || h.contains('particulars') || h.contains('remarks')) {
        descIdx = i;
      } else if (h.contains('credit') || h.contains('deposit') || h.contains('cr')) {
        creditIdx = i;
      } else if (h.contains('debit') || h.contains('withdrawal') || h.contains('dr')) {
        debitIdx = i;
      } else if (h.contains('amount') || h.contains('txn amount')) {
        amountIdx = i;
      } else if (h.contains('ref') || h.contains('utr') || h.contains('chq') || h.contains('cheque')) {
        refIdx = i;
      }
    }

    // Parse subsequent data lines
    final startIndex = (dateIdx != -1 || amountIdx != -1 || creditIdx != -1) ? 1 : 0;
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      final cells = _splitCsvLine(line, delimiter);
      if (cells.length < 2) continue;

      String dateStr = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      if (dateIdx != -1 && dateIdx < cells.length) {
        final d = _normalizeDate(cells[dateIdx]);
        if (d != null) dateStr = d;
      }

      String description = 'Statement Transaction';
      if (descIdx != -1 && descIdx < cells.length && cells[descIdx].isNotEmpty) {
        description = cells[descIdx];
      }

      String? refNumber;
      if (refIdx != -1 && refIdx < cells.length && cells[refIdx].isNotEmpty) {
        refNumber = cells[refIdx];
      }

      String? amountStr;
      String type = 'CREDIT';

      // Check separate credit/debit columns
      if (creditIdx != -1 && creditIdx < cells.length && cells[creditIdx].isNotEmpty && _isValidAmount(cells[creditIdx])) {
        amountStr = _cleanAmount(cells[creditIdx]);
        type = 'CREDIT';
      } else if (debitIdx != -1 && debitIdx < cells.length && cells[debitIdx].isNotEmpty && _isValidAmount(cells[debitIdx])) {
        amountStr = _cleanAmount(cells[debitIdx]);
        type = 'DEBIT';
      } else if (amountIdx != -1 && amountIdx < cells.length && cells[amountIdx].isNotEmpty && _isValidAmount(cells[amountIdx])) {
        final rawAmt = cells[amountIdx];
        if (rawAmt.startsWith('-') || rawAmt.toLowerCase().endsWith('dr')) {
          type = 'DEBIT';
        } else {
          type = 'CREDIT';
        }
        amountStr = _cleanAmount(rawAmt);
      }

      if (amountStr != null && _amountToPaise(amountStr) > 0) {
        records.add(ExtractedStatementRecord(
          date: dateStr,
          description: description,
          amount: amountStr,
          type: type,
          reference: refNumber ?? _extractUtr(description),
          counterparty: _extractCounterparty(description),
        ));
      }
    }

    return records;
  }

  // Helper: parse text lines (e.g. from plain text / PDF statement export)
  List<ExtractedStatementRecord> _parseTextStatementLines(List<String> lines) {
    final List<ExtractedStatementRecord> records = [];
    final amountPattern = RegExp(r'(?:Rs\.?|INR|₹)?\s*([0-9,]+\.[0-9]{2})');

    for (final line in lines) {
      final amtMatch = amountPattern.firstMatch(line);
      if (amtMatch != null) {
        final rawAmt = amtMatch.group(1)!;
        final cleanAmt = rawAmt.replaceAll(',', '');
        final paise = MigrationVerificationService.parseExactPaise(cleanAmt);
        if (paise > 0) {
          final lower = line.toLowerCase();
          final isCredit = lower.contains('cr') || lower.contains('credit') || lower.contains('received') || lower.contains('deposit');
          final isDebit = lower.contains('dr') || lower.contains('debit') || lower.contains('paid') || lower.contains('withdrawal');
          final type = (isDebit && !isCredit) ? 'DEBIT' : 'CREDIT';

          final dateStr = _normalizeDate(line) ?? DateTime.now().toUtc().toIso8601String().substring(0, 10);
          final ref = _extractUtr(line);
          final cp = _extractCounterparty(line);

          records.add(ExtractedStatementRecord(
            date: dateStr,
            description: line.length > 80 ? '${line.substring(0, 77)}...' : line,
            amount: (paise / 100.0).toStringAsFixed(2),
            type: type,
            reference: ref,
            counterparty: cp,
          ));
        }
      }
    }

    return records;
  }

  List<String> _splitCsvLine(String line, String delimiter) {
    final List<String> result = [];
    bool insideQuotes = false;
    final buffer = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        insideQuotes = !insideQuotes;
      } else if (char == delimiter && !insideQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }

  String? _normalizeDate(String text) {
    // Matches DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD
    final dmyRegex = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})');
    final match = dmyRegex.firstMatch(text);
    if (match != null) {
      final day = match.group(1)!.padLeft(2, '0');
      final month = match.group(2)!.padLeft(2, '0');
      var year = match.group(3)!;
      if (year.length == 2) year = '20$year';
      return '$year-$month-$day';
    }

    final ymdRegex = RegExp(r'(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})');
    final ymdMatch = ymdRegex.firstMatch(text);
    if (ymdMatch != null) {
      final year = ymdMatch.group(1)!;
      final month = ymdMatch.group(2)!.padLeft(2, '0');
      final day = ymdMatch.group(3)!.padLeft(2, '0');
      return '$year-$month-$day';
    }

    return null;
  }

  bool _isValidAmount(String s) {
    final clean = s.replaceAll(RegExp(r'[^0-9\.]'), '');
    return double.tryParse(clean) != null && double.parse(clean) > 0;
  }

  String _cleanAmount(String s) {
    final clean = s.replaceAll(RegExp(r'[^0-9\.]'), '');
    final val = double.tryParse(clean) ?? 0.0;
    return val.toStringAsFixed(2);
  }

  int _amountToPaise(String amountStr) {
    try {
      return MigrationVerificationService.parseExactPaise(amountStr);
    } catch (_) {
      final val = double.tryParse(amountStr.replaceAll(',', ''));
      return val != null ? (val * 100).round() : 0;
    }
  }

  String? _extractUtr(String text) {
    final utrRegex = RegExp(r'(?:UPI\s*Ref|Ref|UTR|Txn\s*ID)[\s\:\/]*([A-Za-z0-9]{8,22})', caseSensitive: false);
    final match = utrRegex.firstMatch(text);
    return match?.group(1);
  }

  String? _extractCounterparty(String text) {
    final cpRegex = RegExp(r'(?:to|from|by|vpa)\s+([A-Za-z0-9\.\@\s]{3,30}?)(?:\/|\s+on|\s+ref|\.|$)', caseSensitive: false);
    final match = cpRegex.firstMatch(text);
    if (match != null) {
      final name = match.group(1)!.trim();
      if (!name.toLowerCase().contains('account') && !name.toLowerCase().contains('transfer')) {
        return name;
      }
    }
    return null;
  }
}
