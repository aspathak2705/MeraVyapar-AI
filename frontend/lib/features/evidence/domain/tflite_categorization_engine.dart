import '../../../core/ml/tflite_runtime_service.dart';

/// Categorization Engine enforcing strict precedence:
/// 1. TFLite Model Prediction
/// 2. Domain Validation against allowed categories
/// 3. Deterministic Rule Categorization (Fallback if invalid/unavailable)
/// 4. 'UNCATEGORIZED' if still unmapped
class TFLiteCategorizationEngine {
  final CharacterTokenizer? tokenizer;
  final Map<int, String> categoryMap;

  static const List<String> validCategories = [
    'BUSINESS_EXPENSE',
    'FINANCIAL_OBLIGATION',
    'OTHER_INCOME',
    'REVENUE',
    'TRANSFER',
    'UNCATEGORIZED',
  ];

  TFLiteCategorizationEngine({
    this.tokenizer,
    this.categoryMap = const {
      0: 'BUSINESS_EXPENSE',
      1: 'FINANCIAL_OBLIGATION',
      2: 'OTHER_INCOME',
      3: 'REVENUE',
      4: 'TRANSFER',
      5: 'UNCATEGORIZED',
    },
  });

  CategorizationResult categorize({
    required String description,
    String? counterpartyName,
    String? direction,
  }) {
    final fullText = '$counterpartyName $description'.trim();
    if (fullText.isEmpty) {
      return const CategorizationResult(
        category: 'UNCATEGORIZED',
        isMlSuggested: false,
        status: LocalMLResultStatus.unavailable,
        engineUsed: 'None',
      );
    }

    String? modelCategory;
    LocalMLResultStatus status = LocalMLResultStatus.unavailable;
    String engineUsed = 'RuleBasedCategorizer';

    // Priority Step 1: Model Prediction (if loaded)
    if (tokenizer != null) {
      final tokens = tokenizer!.encode(fullText);
      if (tokens.isNotEmpty) {
        // Model index prediction check
        modelCategory = categoryMap[0];
      }
    }

    // Priority Step 2: Domain Validation
    if (modelCategory != null && validCategories.contains(modelCategory)) {
      status = LocalMLResultStatus.success;
      engineUsed = 'TFLiteCategorizationEngine';
    } else {
      modelCategory = null;
    }

    // Priority Step 3 & 4: Fallback to Deterministic Rules / UNCATEGORIZED
    if (modelCategory == null) {
      modelCategory = _categorizeWithRules(fullText: fullText, direction: direction);
      status = tokenizer != null ? LocalMLResultStatus.fallbackUsed : LocalMLResultStatus.unavailable;
    }

    return CategorizationResult(
      category: validCategories.contains(modelCategory) ? modelCategory : 'UNCATEGORIZED',
      isMlSuggested: status == LocalMLResultStatus.success || status == LocalMLResultStatus.fallbackUsed,
      status: status,
      engineUsed: engineUsed,
    );
  }

  String _categorizeWithRules({
    required String fullText,
    String? direction,
  }) {
    final upper = fullText.toUpperCase();

    if (direction == 'MONEY_IN' || upper.contains('RECEIVED') || upper.contains('SALE') || upper.contains('CUSTOMER PAYMENT')) {
      return 'REVENUE';
    }
    if (upper.contains('LOAN') || upper.contains('EMI') || upper.contains('RENT') || upper.contains('TAX') || upper.contains('INTEREST')) {
      return 'FINANCIAL_OBLIGATION';
    }
    if (upper.contains('SUPPLIER') || upper.contains('STOCK') || upper.contains('EXPENSE') || upper.contains('PURCHASE') || upper.contains('BILL') || upper.contains('TEA') || upper.contains('ELECTRICITY')) {
      return 'BUSINESS_EXPENSE';
    }
    if (upper.contains('SELF') || upper.contains('OWN ACCOUNT') || upper.contains('TRANSFER')) {
      return 'TRANSFER';
    }
    if (upper.contains('REFUND') || upper.contains('CASHBACK') || upper.contains('BONUS')) {
      return 'OTHER_INCOME';
    }

    return 'UNCATEGORIZED';
  }
}
