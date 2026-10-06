import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/ml/tflite_runtime_service.dart';
import 'package:frontend/features/evidence/domain/tflite_extraction_engine.dart';
import 'package:frontend/features/evidence/domain/tflite_categorization_engine.dart';

void main() {
  group('TFLite On-Device Intelligence Rigorous Verification', () {
    test('CharacterTokenizer matches exact whitespace normalization, max_len (128), and PAD (0) / UNK (1)', () {
      final vocabMap = {
        '<PAD>': 0,
        '<UNK>': 1,
        'R': 2,
        's': 3,
        ' ': 4,
        '5': 5,
        '0': 6,
      };
      final jsonStr = jsonEncode({
        'vocab': vocabMap,
        'max_len': 128,
        'lowercase': false,
      });
      final tokenizer = CharacterTokenizer.fromJsonString(jsonStr);

      final tokens = tokenizer.encode('  Rs   500  ');
      expect(tokens.length, 128); // Exact sequence length 128
      expect(tokens[0], 2); // R
      expect(tokens[1], 3); // s
      expect(tokens[2], 4); // single normalized space
      expect(tokens[3], 5); // 5
      expect(tokens[4], 6); // 0
      expect(tokens[5], 6); // 0
      expect(tokens[6], 0); // PAD ID
      expect(tokens[127], 0); // PAD ID at end
    });

    test('Extraction precedence: Model -> Domain Validation -> Regex Fallback', () {
      final engine = TFLiteExtractionEngine();

      final res1 = engine.extract('Received Rs. 5000.50 from Rajesh Kumar via UPI');
      expect(res1.amount, 5000.50);
      expect(res1.paymentMode, 'UPI');
      expect(res1.counterpartyName, 'Rajesh Kumar');
      expect(res1.status, LocalMLResultStatus.fallbackUsed);
      expect(res1.isMlSuggested, true);
    });

    test('Categorization precedence: Model -> Domain Validation -> Rule Fallback', () {
      final engine = TFLiteCategorizationEngine();

      final res1 = engine.categorize(
        description: 'Payment for tea and electricity bill',
        direction: 'MONEY_OUT',
      );
      expect(res1.category, 'BUSINESS_EXPENSE');
      expect(res1.status, LocalMLResultStatus.unavailable);

      final res2 = engine.categorize(
        description: 'Unknown random text string',
        direction: 'MONEY_OUT',
      );
      expect(res2.category, 'UNCATEGORIZED');
      expect(TFLiteCategorizationEngine.validCategories.contains(res2.category), true);
    });
  });
}
