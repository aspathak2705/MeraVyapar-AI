import 'dart:convert';

/// Status of local ML engine execution
enum LocalMLResultStatus {
  success,
  unavailable,
  invalidOutput,
  fallbackUsed,
}

/// Representation of extracted transaction details from raw text.
class ExtractionResult {
  final double? amount;
  final String? paymentMode;
  final String? counterpartyName;
  final String? sourceType;
  final String? transactionStatus;
  final String? transactionDate;
  final String? bankName;
  final bool isMlSuggested;
  final LocalMLResultStatus status;
  final String engineUsed;

  const ExtractionResult({
    this.amount,
    this.paymentMode,
    this.counterpartyName,
    this.sourceType,
    this.transactionStatus,
    this.transactionDate,
    this.bankName,
    required this.isMlSuggested,
    required this.status,
    required this.engineUsed,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'payment_mode': paymentMode,
        'counterparty_name': counterpartyName,
        'source_type': sourceType,
        'transaction_status': transactionStatus,
        'transaction_date': transactionDate,
        'bank_name': bankName,
        'is_ml_suggested': isMlSuggested,
        'status': status.name,
        'engine_used': engineUsed,
      };
}

/// Representation of categorization suggestion.
class CategorizationResult {
  final String category;
  final String? subcategory;
  final bool isMlSuggested;
  final LocalMLResultStatus status;
  final String engineUsed;

  const CategorizationResult({
    required this.category,
    this.subcategory,
    required this.isMlSuggested,
    required this.status,
    required this.engineUsed,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'subcategory': subcategory,
        'is_ml_suggested': isMlSuggested,
        'status': status.name,
        'engine_used': engineUsed,
      };
}

/// Tokenizer matching exact character vocabulary, normalization, and padding specs.
class CharacterTokenizer {
  final Map<String, int> vocab;
  final bool lowercase;
  final int maxLen;
  final int padId;
  final int unkId;

  CharacterTokenizer({
    required this.vocab,
    this.lowercase = false,
    this.maxLen = 128,
    this.padId = 0,
    this.unkId = 1,
  });

  factory CharacterTokenizer.fromJsonString(String jsonStr) {
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;
    final vocabMap = (decoded['vocab'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    final isLower = decoded['lowercase'] as bool? ?? false;
    final maxSeqLen = (decoded['max_len'] as num?)?.toInt() ?? 128;
    return CharacterTokenizer(
      vocab: vocabMap,
      lowercase: isLower,
      maxLen: maxSeqLen,
      padId: vocabMap['<PAD>'] ?? 0,
      unkId: vocabMap['<UNK>'] ?? 1,
    );
  }

  List<int> encode(String rawText) {
    // 1. Whitespace normalization
    var normalized = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (lowercase) {
      normalized = normalized.toLowerCase();
    }

    final tokens = <int>[];
    // 2. Truncation (left-to-right) up to maxLen
    for (var i = 0; i < normalized.length && i < maxLen; i++) {
      final char = normalized[i];
      tokens.add(vocab[char] ?? unkId);
    }

    // 3. Post-padding with PAD token ID up to maxLen
    while (tokens.length < maxLen) {
      tokens.add(padId);
    }
    return tokens;
  }
}
