import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Central date and time localization formatter supporting English, Hindi, and Marathi.
class AppDateFormatter {
  static String formatDate(DateTime? date, {String? locale, bool includeTime = false}) {
    if (date == null) return '—';
    final loc = _normalizeLocale(locale);
    try {
      if (includeTime) {
        return DateFormat.yMMMd(loc).add_jm().format(date);
      }
      return DateFormat.yMMMd(loc).format(date);
    } catch (_) {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  static String formatIsoDate(String? isoString, {String? locale, bool includeTime = false}) {
    if (isoString == null || isoString.trim().isEmpty) return '—';
    final dt = DateTime.tryParse(isoString.trim());
    if (dt == null) return isoString;
    return formatDate(dt, locale: locale, includeTime: includeTime);
  }

  static String formatDateWithContext(
    BuildContext context,
    DateTime? date, {
    bool includeTime = false,
  }) {
    final locale = Localizations.localeOf(context).languageCode;
    return formatDate(date, locale: locale, includeTime: includeTime);
  }

  static String formatIsoWithContext(
    BuildContext context,
    String? isoString, {
    bool includeTime = false,
  }) {
    final locale = Localizations.localeOf(context).languageCode;
    return formatIsoDate(isoString, locale: locale, includeTime: includeTime);
  }

  static String _normalizeLocale(String? locale) {
    if (locale == null) return 'en';
    final code = locale.toLowerCase();
    if (code.startsWith('hi')) return 'hi';
    if (code.startsWith('mr')) return 'mr';
    return 'en';
  }
}
