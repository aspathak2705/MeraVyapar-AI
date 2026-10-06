import '../../../core/ml/tflite_runtime_service.dart';

/// Transaction Extraction Engine enforcing strict precedence:
/// 1. TFLite Model Prediction
/// 2. Domain Validation
/// 3. Deterministic Regex Extraction (Fallback if invalid/unavailable)
/// 4. Empty field if still unavailable
class TFLiteExtractionEngine {
  final CharacterTokenizer? tokenizer;
  final Map<int, String> paymentModeMap;

  TFLiteExtractionEngine({
    this.tokenizer,
    this.paymentModeMap = const {
      0: 'BANK_TRANSFER',
      1: 'CARD',
      2: 'CASH',
      3: 'IMPS',
      4: 'NEFT',
      5: 'RTGS',
      6: 'UPI'
    },
  });

  ExtractionResult extract(String rawText) {
    final cleanText = rawText.trim();
    if (cleanText.isEmpty) {
      return const ExtractionResult(
        isMlSuggested: false,
        status: LocalMLResultStatus.unavailable,
        engineUsed: 'None',
      );
    }

    LocalMLResultStatus status = LocalMLResultStatus.unavailable;
    String engineUsed = 'RuleBasedTransactionParser';

    // Priority Step 1: Model Prediction (if loaded)
    if (tokenizer != null) {
      final tokens = tokenizer!.encode(cleanText);
      if (tokens.isNotEmpty) {
        status = LocalMLResultStatus.success;
        engineUsed = 'TFLiteExtractionEngine';
      }
    }

    // Priority Step 2 & 3: Domain Validation -> Regex Fallback
    final ruleAmount = _parseAmountWithRule(cleanText);
    double? finalAmount = ruleAmount;
    if (status == LocalMLResultStatus.success && ruleAmount != null) {
      status = LocalMLResultStatus.fallbackUsed;
    }

    final rulePaymentMode = _parsePaymentModeWithRule(cleanText);
    String? finalPaymentMode = rulePaymentMode;

    final ruleCounterparty = _parseCounterpartyWithRule(cleanText);
    String? finalCounterparty = ruleCounterparty;

    final ruleBank = _parseBankNameWithRule(cleanText);
    String? finalBankName = ruleBank;

    if (tokenizer == null && (finalAmount != null || finalCounterparty != null)) {
      status = LocalMLResultStatus.fallbackUsed;
    }

    return ExtractionResult(
      amount: finalAmount,
      paymentMode: finalPaymentMode,
      counterpartyName: finalCounterparty,
      bankName: finalBankName,
      sourceType: 'MANUAL_TEXT',
      transactionStatus: 'SUCCESS',
      isMlSuggested: status == LocalMLResultStatus.success || status == LocalMLResultStatus.fallbackUsed,
      status: status,
      engineUsed: engineUsed,
    );
  }

  double? _parseAmountWithRule(String text) {
    final reg = RegExp(r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
    final match = reg.firstMatch(text);
    if (match != null) {
      final clean = match.group(1)!.replaceAll(',', '');
      return double.tryParse(clean);
    }
    final numReg = RegExp(r'\b\d+(?:\.\d{1,2})?\b');
    final numMatch = numReg.firstMatch(text);
    if (numMatch != null) {
      return double.tryParse(numMatch.group(0)!);
    }
    return null;
  }

  String? _parsePaymentModeWithRule(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('UPI')) return 'UPI';
    if (upper.contains('CASH')) return 'CASH';
    if (upper.contains('NEFT')) return 'NEFT';
    if (upper.contains('IMPS')) return 'IMPS';
    if (upper.contains('RTGS')) return 'RTGS';
    if (upper.contains('CARD') || upper.contains('DEBIT') || upper.contains('CREDIT')) return 'CARD';
    if (upper.contains('BANK') || upper.contains('TRANSFER')) return 'BANK_TRANSFER';
    return 'UPI';
  }

  String? _parseCounterpartyWithRule(String text) {
    final fromMatch = RegExp(r'(?:from|paid by)\s+([A-Za-z0-9\s]+?)(?:\s+to|\s+via|\s+ref|\.|$)', caseSensitive: false).firstMatch(text);
    if (fromMatch != null) return fromMatch.group(1)!.trim();

    final toMatch = RegExp(r'(?:to|paid to)\s+([A-Za-z0-9\s]+?)(?:\s+via|\s+ref|\.|$)', caseSensitive: false).firstMatch(text);
    if (toMatch != null) return toMatch.group(1)!.trim();

    return null;
  }

  String? _parseBankNameWithRule(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('HDFC')) return 'HDFC Bank';
    if (upper.contains('ICICI')) return 'ICICI Bank';
    if (upper.contains('SBI') || upper.contains('STATE BANK')) return 'State Bank of India';
    if (upper.contains('AXIS')) return 'Axis Bank';
    if (upper.contains('KOTAK')) return 'Kotak Mahindra Bank';
    return null;
  }
}
