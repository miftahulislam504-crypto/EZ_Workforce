import '../../core/utils/formatters.dart';

typedef Json = Map<String, dynamic>;

String? str(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

String strOr(dynamic value, [String fallback = '']) => str(value) ?? fallback;

int intOr(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool boolOr(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  return fallback;
}

/// Parses a `timestamptz` column.
DateTime? timestamp(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

/// Parses a `date` column.
DateTime? dateOnly(dynamic value) => Fmt.parseDate(value);

List<Json> jsonList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const [];
}

Json jsonMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
