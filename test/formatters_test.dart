import 'package:ez_workforce/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    Fmt.configure(datePattern: 'dd MMM yyyy', timeFormat: '12h');
  });

  group('Fmt.initials', () {
    test('uses first and last word', () {
      expect(Fmt.initials('Abdul Karim Chowdhury'), 'AC');
      expect(Fmt.initials('rahim'), 'R');
    });

    test('handles blank names', () {
      expect(Fmt.initials('   '), '?');
    });
  });

  group('Fmt.humanize', () {
    test('turns snake_case into words', () {
      expect(Fmt.humanize('full_time'), 'Full Time');
      expect(Fmt.humanize('active'), 'Active');
    });

    test('returns a dash for empty values', () {
      expect(Fmt.humanize(null), '-');
      expect(Fmt.humanize(''), '-');
    });
  });

  group('Fmt.plural', () {
    test('picks singular or plural', () {
      expect(Fmt.plural(1, 'branch', 'branches'), '1 branch');
      expect(Fmt.plural(3, 'branch', 'branches'), '3 branches');
      expect(Fmt.plural(0, 'person', 'people'), '0 people');
      expect(Fmt.plural(2, 'notice'), '2 notices');
    });
  });

  group('Fmt.mask', () {
    test('keeps only the last characters visible', () {
      expect(Fmt.mask('1234567890'), '******7890');
      expect(Fmt.mask('123'), '***');
      expect(Fmt.mask(null), '-');
    });
  });

  group('dates', () {
    test('parseDate ignores the time zone', () {
      final parsed = Fmt.parseDate('2026-01-31');
      expect(parsed, DateTime(2026, 1, 31));
      expect(Fmt.parseDate(null), isNull);
      expect(Fmt.parseDate('not a date'), isNull);
    });

    test('isoDate writes a Postgres date literal', () {
      expect(Fmt.isoDate(DateTime(2026, 3, 4)), '2026-03-04');
    });

    test('date follows the configured pattern', () {
      expect(Fmt.date(DateTime(2026, 3, 14)), '14 Mar 2026');
      Fmt.configure(datePattern: 'yyyy-MM-dd');
      expect(Fmt.date(DateTime(2026, 3, 14)), '2026-03-14');
      expect(Fmt.date(null), '-');
    });

    test('time follows the 12 and 24 hour setting', () {
      final value = DateTime(2026, 3, 14, 15, 5);
      Fmt.configure(timeFormat: '12h');
      expect(Fmt.time(value), '03:05 PM');
      Fmt.configure(timeFormat: '24h');
      expect(Fmt.time(value), '15:05');
    });

    test('relative describes recent times', () {
      final now = DateTime.now();
      expect(Fmt.relative(now), 'Just now');
      expect(
        Fmt.relative(now.subtract(const Duration(minutes: 5))),
        '5 min ago',
      );
      expect(Fmt.relative(now.subtract(const Duration(hours: 3))), '3 hr ago');
      expect(Fmt.relative(now.subtract(const Duration(days: 2))), '2 d ago');
    });
  });
}
