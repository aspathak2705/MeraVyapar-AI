import 'dart:core';

class ParsedRequirementDraft {
  final String rawPrompt;
  final String itemName;
  final double quantity;
  final String unit;
  final String? gradeSpec;
  final String? dimensions;
  final String? thickness;
  final String? deliveryTimeline;
  final List<String> missingSpecifications;
  final String? clarificationQuestion;
  final bool isReadyForConfirmation;

  const ParsedRequirementDraft({
    required this.rawPrompt,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.gradeSpec,
    this.dimensions,
    this.thickness,
    this.deliveryTimeline,
    required this.missingSpecifications,
    this.clarificationQuestion,
    required this.isReadyForConfirmation,
  });

  ParsedRequirementDraft copyWith({
    String? itemName,
    double? quantity,
    String? unit,
    String? gradeSpec,
    String? dimensions,
    String? thickness,
    String? deliveryTimeline,
    List<String>? missingSpecifications,
    String? clarificationQuestion,
    bool? isReadyForConfirmation,
  }) {
    return ParsedRequirementDraft(
      rawPrompt: rawPrompt,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      gradeSpec: gradeSpec ?? this.gradeSpec,
      dimensions: dimensions ?? this.dimensions,
      thickness: thickness ?? this.thickness,
      deliveryTimeline: deliveryTimeline ?? this.deliveryTimeline,
      missingSpecifications: missingSpecifications ?? this.missingSpecifications,
      clarificationQuestion: clarificationQuestion ?? this.clarificationQuestion,
      isReadyForConfirmation: isReadyForConfirmation ?? this.isReadyForConfirmation,
    );
  }
}

/// Assistant that parses natural procurement speech (Hindi / English / Hinglish / Marathi)
/// and triggers interactive specification clarification for missing critical attributes.
class ProcurementVoiceAssistant {
  static ParsedRequirementDraft parseRequirement(String input) {
    final text = input.trim();
    final lower = text.toLowerCase();

    // 1. Extract Quantity & Unit
    double quantity = 1.0;
    String unit = 'units';

    final qtyMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(kg|किलो|किग्रा|ton|टन|sheets|sheet|शीट|bags|बोरी|pcs|pieces|नग|meter|मीटर|ft|feet|लीटर|litre|l)\b', caseSensitive: false)
        .firstMatch(lower);

    if (qtyMatch != null) {
      quantity = double.tryParse(qtyMatch.group(1) ?? '1') ?? 1.0;
      final rawUnit = (qtyMatch.group(2) ?? 'units').toLowerCase();
      if (rawUnit.contains('kg') || rawUnit.contains('किलो') || rawUnit.contains('किग्रा')) {
        unit = 'kg';
      } else if (rawUnit.contains('ton') || rawUnit.contains('टन')) {
        unit = 'tonnes';
      } else if (rawUnit.contains('sheet') || rawUnit.contains('शीट')) {
        unit = 'sheets';
      } else if (rawUnit.contains('bag') || rawUnit.contains('बोरी')) {
        unit = 'bags';
      } else if (rawUnit.contains('pcs') || rawUnit.contains('piece') || rawUnit.contains('नग')) {
        unit = 'pcs';
      } else {
        unit = rawUnit;
      }
    } else {
      // Fallback: standalone number
      final numMatch = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(lower);
      if (numMatch != null) {
        quantity = double.tryParse(numMatch.group(1) ?? '1') ?? 1.0;
      }
    }

    // 2. Extract Grade / Specification
    String? grade;
    if (lower.contains('304') || lower.contains('ss304') || lower.contains('ss 304')) {
      grade = 'SS 304';
    } else if (lower.contains('316') || lower.contains('ss316') || lower.contains('ss 316')) {
      grade = 'SS 316';
    } else if (lower.contains('202') || lower.contains('ss202')) {
      grade = 'SS 202';
    } else if (lower.contains('ms') || lower.contains('mild steel')) {
      grade = 'Mild Steel (MS)';
    }

    // 3. Extract Item Name
    String item = 'Material';
    if (lower.contains('stainless steel') || lower.contains('स्टेनलेस स्टील')) {
      item = lower.contains('sheet') || lower.contains('शीट')
          ? 'Stainless Steel Sheets'
          : (lower.contains('pipe') ? 'Stainless Steel Pipes' : 'Stainless Steel');
    } else if (lower.contains('steel') || lower.contains('स्टील')) {
      item = lower.contains('sheet') || lower.contains('शीट') ? 'Steel Sheets' : 'Steel';
    } else if (lower.contains('cement') || lower.contains('सीमेंट')) {
      item = 'Cement';
      if (unit == 'units') unit = 'bags';
    } else if (lower.contains('copper') || lower.contains('तांबा')) {
      item = 'Copper Wire';
    } else {
      item = text;
    }

    // 4. Extract Delivery Timeline
    String? delivery;
    if (lower.contains('next week') || lower.contains('अगले हफ्ते') || lower.contains('पुढील आठवड्यात')) {
      delivery = '7 days';
    } else if (lower.contains('urgent') || lower.contains('कल') || lower.contains('उद्या') || lower.contains('tomorrow')) {
      delivery = '1-2 days';
    } else if (lower.contains('month') || lower.contains('महीने')) {
      delivery = '30 days';
    }

    // 5. Check Dimensions & Thickness
    String? dimensions;
    final dimMatch = RegExp(r'(\d+[\s*xX]\s*\d+\s*(?:ft|feet|mm|inch)?)').firstMatch(text);
    if (dimMatch != null) {
      dimensions = dimMatch.group(1);
    }

    String? thickness;
    final thkMatch = RegExp(r'(\d+(?:\.\d+)?\s*(?:mm|gauge|गेज|मिमी))\b', caseSensitive: false).firstMatch(text);
    if (thkMatch != null) {
      thickness = thkMatch.group(1);
    }

    // 6. Detect Missing Critical Specifications
    final missing = <String>[];
    if (item.toLowerCase().contains('sheet') || item.toLowerCase().contains('plate')) {
      if (thickness == null) missing.add('thickness');
      if (dimensions == null) missing.add('dimensions');
    }
    if (grade == null && (item.toLowerCase().contains('steel') || item.toLowerCase().contains('metal'))) {
      missing.add('grade');
    }

    String? clarification;
    if (missing.contains('thickness') && missing.contains('dimensions')) {
      clarification = 'What sheet thickness (e.g. 2mm) and dimensions (e.g. 8x4 ft) are required for accurate quote comparison?';
    } else if (missing.contains('thickness')) {
      clarification = 'What thickness (e.g. 1.5mm, 2mm) do you need?';
    } else if (missing.contains('dimensions')) {
      clarification = 'What dimensions or sheet size (e.g. 8x4 ft) are needed?';
    } else if (missing.contains('grade')) {
      clarification = 'Which material grade (e.g. SS 304, SS 316) should suppliers quote for?';
    }

    return ParsedRequirementDraft(
      rawPrompt: input,
      itemName: item,
      quantity: quantity,
      unit: unit,
      gradeSpec: grade,
      dimensions: dimensions,
      thickness: thickness,
      deliveryTimeline: delivery,
      missingSpecifications: missing,
      clarificationQuestion: clarification,
      isReadyForConfirmation: missing.isEmpty,
    );
  }
}
