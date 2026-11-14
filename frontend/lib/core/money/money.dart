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
      throw FormatException(
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
}
