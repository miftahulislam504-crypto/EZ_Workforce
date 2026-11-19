typedef FieldValidator = String? Function(String? value);

class Validators {
  const Validators._();

  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _phone = RegExp(r'^[+]?[0-9 ()\-]{6,20}$');

  static String? required(String? value, [String label = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static FieldValidator requiredField(String label) =>
      (value) => required(value, label);

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_email.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!_email.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!_phone.hasMatch(value.trim())) return 'Enter a valid phone number';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static FieldValidator matches(String Function() other, String message) =>
      (value) => value == other() ? null : message;

  static FieldValidator maxLength(int max) => (value) {
    if (value != null && value.length > max) {
      return 'Use at most $max characters';
    }
    return null;
  };

  static FieldValidator compose(List<FieldValidator> validators) => (value) {
    for (final validator in validators) {
      final result = validator(value);
      if (result != null) return result;
    }
    return null;
  };

  /// Returns null for blank strings, otherwise the trimmed value. Used to
  /// store empty optional inputs as NULL in the database.
  static String? clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
