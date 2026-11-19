import 'package:ez_workforce/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.required', () {
    test('rejects null, empty and blank input', () {
      expect(Validators.required(null, 'Name'), 'Name is required');
      expect(Validators.required('', 'Name'), 'Name is required');
      expect(Validators.required('   ', 'Name'), 'Name is required');
    });

    test('accepts text', () {
      expect(Validators.required('Rahim', 'Name'), isNull);
    });
  });

  group('Validators.email', () {
    test('accepts a normal address, ignoring surrounding spaces', () {
      expect(Validators.email(' hr@company.com '), isNull);
    });

    test('rejects blank and malformed addresses', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('hr@company'), isNotNull);
      expect(Validators.email('hr.company.com'), isNotNull);
    });

    test('optionalEmail allows blank but not malformed', () {
      expect(Validators.optionalEmail(''), isNull);
      expect(Validators.optionalEmail(null), isNull);
      expect(Validators.optionalEmail('nope'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('requires at least 8 characters', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('1234567'), isNotNull);
      expect(Validators.password('12345678'), isNull);
    });
  });

  group('Validators.matches', () {
    test('compares against the current value of the other field', () {
      var other = 'secret123';
      final validator = Validators.matches(() => other, 'Mismatch');
      expect(validator('secret123'), isNull);
      expect(validator('other'), 'Mismatch');
      other = 'changed';
      expect(validator('changed'), isNull);
    });
  });

  group('Validators.optionalPhone', () {
    test('allows blank and common phone formats', () {
      expect(Validators.optionalPhone(''), isNull);
      expect(Validators.optionalPhone('+880 1712-345678'), isNull);
    });

    test('rejects letters and short numbers', () {
      expect(Validators.optionalPhone('abc'), isNotNull);
      expect(Validators.optionalPhone('123'), isNotNull);
    });
  });

  group('Validators.compose', () {
    test('returns the first failure', () {
      final validator = Validators.compose([
        Validators.requiredField('Title'),
        Validators.maxLength(5),
      ]);
      expect(validator(''), 'Title is required');
      expect(validator('abcdefg'), isNotNull);
      expect(validator('abc'), isNull);
    });
  });

  group('Validators.clean', () {
    test('turns blank input into null and trims the rest', () {
      expect(Validators.clean(null), isNull);
      expect(Validators.clean('   '), isNull);
      expect(Validators.clean('  hello '), 'hello');
    });
  });
}
