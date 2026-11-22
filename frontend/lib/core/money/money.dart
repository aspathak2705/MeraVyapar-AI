import 'package:intl/intl.dart';

/// Exact INR/paise conversion for persistence and financial calculations.
///
/// Amounts arrive as human-entered decimal strings. Never route those values
/// through `double`, because binary floating point can change paise values.
class Money {
  static final RegExp _inrPattern = RegExp(r'^(0|[1-9]\d*)(?:\.(\d{1,2}))?$');

  static int parseInrToPaise(String input) {
    final normalized = input.trim().replaceAll(',', '');
    final match = _inrPattern.firstMatch(normalized);
    if (match == null) {
      throw const FormatException(
          'Enter a valid amount with at most two decimal places.');
    }
    final rupees = int.parse(match.group(1)!);
    final fractional = (match.group(2) ?? '').padRight(2, '0');
    final paise = int.parse(fractional);
    return rupees * 100 + paise;
  }

  static String formatPaise(int paise) {
    final sign = paise < 0 ? '-' : '';
    final absolute = paise.abs();
    return '$sign${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
  }

  /// Localized Indian currency formatting with standard Indian numbering grouping:
  /// e.g. ₹1,000, ₹25,000, ₹1,50,000, ₹1,25,00,000.
  /// All canonical calculations remain integer paise. Presentation-only.
  static String formatInr(int paise, {bool showDecimals = false, String symbol = '₹'}) {
    final sign = paise < 0 ? '-' : '';
    final absPaise = paise.abs();
    final fractional = absPaise % 100;

    final inrFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: symbol,
      decimalDigits: showDecimals ? 2 : (fractional == 0 ? 0 : 2),
    );

    final formatted = inrFormatter.format(absPaise / 100.0).trim();
    return '$sign$formatted';
  }

  /// Format rupee numbers using standard Indian comma grouping.
  static String formatRupees(num rupees, {bool showDecimals = false, String symbol = '₹'}) {
    final paise = (rupees * 100).round();
    return formatInr(paise, showDecimals: showDecimals, symbol: symbol);
  }
}
