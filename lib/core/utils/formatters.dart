import 'package:intl/intl.dart';

/// Formatting helpers. The date and time patterns follow the organization
/// settings and are refreshed whenever the app context loads.
class Fmt {
  const Fmt._();

  static String datePattern = 'dd MMM yyyy';
  static bool use24Hour = false;

  static void configure({String? datePattern, String? timeFormat}) {
    if (datePattern != null && datePattern.isNotEmpty) {
      try {
        DateFormat(datePattern).format(DateTime(2000));
        Fmt.datePattern = datePattern;
      } catch (_) {
        Fmt.datePattern = 'dd MMM yyyy';
      }
    }
    if (timeFormat != null) {
      use24Hour = timeFormat == '24h';
    }
  }

  static String date(DateTime? value) {
    if (value == null) return '-';
    return DateFormat(datePattern).format(value.toLocal());
  }

  /// A fixed example date, used to preview a date pattern.
  static String sampleDate(String pattern) {
    try {
      return DateFormat(pattern).format(DateTime(2026, 3, 14));
    } catch (_) {
      return pattern;
    }
  }

  static String time(DateTime? value) {
    if (value == null) return '-';
    return DateFormat(use24Hour ? 'HH:mm' : 'hh:mm a').format(value.toLocal());
  }

  static String dateTime(DateTime? value) {
    if (value == null) return '-';
    return '${date(value)}, ${time(value)}';
  }

  /// Parses a Postgres `date` column ("2026-01-31") without time zone shifts.
  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Postgres `date` literal for a [DateTime].
  static String isoDate(DateTime value) =>
      DateFormat('yyyy-MM-dd').format(value);

  static String relative(DateTime? value) {
    if (value == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(value.toLocal());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return date(value);
  }

  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// "full_time" -> "Full Time"
  static String humanize(String? value) {
    if (value == null || value.isEmpty) return '-';
    return value
        .split('_')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static String plural(int count, String singular, [String? plural]) {
    return count == 1
        ? '$count $singular'
        : '$count ${plural ?? '${singular}s'}';
  }

  /// Masks all but the last [visible] characters.
  static String mask(String? value, {int visible = 4}) {
    if (value == null || value.isEmpty) return '-';
    if (value.length <= visible) return '*' * value.length;
    return '${'*' * (value.length - visible)}${value.substring(value.length - visible)}';
  }
}
