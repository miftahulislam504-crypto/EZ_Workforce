import 'package:ez_workforce/data/models/json_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('str returns null for null and empty values', () {
    expect(str(null), isNull);
    expect(str(''), isNull);
    expect(str(12), '12');
  });

  test('strOr falls back', () {
    expect(strOr(null, 'x'), 'x');
    expect(strOr('a', 'x'), 'a');
    expect(strOr(null), '');
  });

  test('intOr reads ints, numbers and numeric strings', () {
    expect(intOr(5), 5);
    expect(intOr(5.9), 5);
    expect(intOr('7'), 7);
    expect(intOr('abc', 3), 3);
    expect(intOr(null), 0);
  });

  test('boolOr only trusts real booleans', () {
    expect(boolOr(true), isTrue);
    expect(boolOr(false, true), isFalse);
    expect(boolOr('true'), isFalse);
    expect(boolOr(null, true), isTrue);
  });

  test('timestamp parses ISO strings and ignores junk', () {
    final parsed = timestamp('2026-03-14T10:00:00Z');
    expect(parsed, isNotNull);
    expect(parsed!.toUtc(), DateTime.utc(2026, 3, 14, 10));
    expect(timestamp(null), isNull);
    expect(timestamp('junk'), isNull);
  });

  test('jsonList keeps only maps', () {
    final list = jsonList([
      {'a': 1},
      'skip',
      {'b': 2},
    ]);
    expect(list, [
      {'a': 1},
      {'b': 2},
    ]);
    expect(jsonList(null), isEmpty);
  });
}
