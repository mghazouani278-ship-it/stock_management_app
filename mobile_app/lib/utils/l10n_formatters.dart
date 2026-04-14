import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';

/// Localized date and number formatters respecting the app locale (en/ar).
/// Use with Provider to access LocaleProvider.
class L10nFormatters {
  const L10nFormatters._();

  /// Format a DateTime for short display (dd/MM/yyyy).
  static String formatDateShort(BuildContext context, DateTime date) {
    final locale = context.l10n.localeName;
    return DateFormat.yMd(locale).format(date);
  }

  /// Format a DateTime for medium display (date + time).
  static String formatDateTime(BuildContext context, DateTime date) {
    final locale = context.l10n.localeName;
    return DateFormat.yMd(locale).add_Hm().format(date);
  }

  /// Format a DateTime from API (ISO string, seconds since epoch, or Map with _seconds).
  static String? formatDateFromApi(BuildContext context, dynamic val) {
    if (val == null) return null;
    DateTime? dt;
    if (val is String) {
      dt = DateTime.tryParse(val);
    } else if (val is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(val * 1000);
    } else if (val is num) {
      dt = DateTime.fromMillisecondsSinceEpoch(val.toInt() * 1000);
    } else if (val is Map && (val['_seconds'] != null || val['seconds'] != null)) {
      final secVal = val['_seconds'] ?? val['seconds'] ?? 0;
      final sec = (secVal is num) ? secVal.toInt() : int.tryParse(secVal.toString()) ?? 0;
      dt = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    }
    if (dt != null) return formatDateTime(context, dt);
    return null;
  }

  /// Format a number according to the current locale (Arabic numerals for ar).
  static String formatNumber(BuildContext context, num value) {
    final locale = context.l10n.localeName;
    return NumberFormat.decimalPattern(locale).format(value);
  }
}
