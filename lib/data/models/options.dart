import '../../core/utils/formatters.dart';
import '../../core/widgets/app_text_field.dart';

/// Fixed value lists shared by forms and filters. Values mirror the
/// CHECK constraints in the database.
class Options {
  const Options._();

  static const List<String> genders = [
    'male',
    'female',
    'other',
    'prefer_not_to_say',
  ];
  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  static const List<String> maritalStatuses = [
    'single',
    'married',
    'divorced',
    'widowed',
  ];
  static const List<String> employeeTypes = [
    'full_time',
    'part_time',
    'contractual',
    'intern',
    'temporary',
  ];
  static const List<String> employeeStatuses = [
    'active',
    'probation',
    'on_leave',
    'suspended',
    'resigned',
    'terminated',
  ];
  static const List<String> documentTypes = [
    'cv',
    'national_id',
    'photograph',
    'education_certificate',
    'experience_certificate',
    'appointment_letter',
    'employment_contract',
    'other',
  ];
  static const List<String> noticeCategories = [
    'general',
    'hr',
    'policy',
    'event',
    'urgent',
  ];
  static const List<String> dataScopes = [
    'organization',
    'branch',
    'department',
    'self',
  ];

  static const Map<String, String> _labelOverrides = {
    'cv': 'CV / Resume',
    'national_id': 'National ID',
    'hr': 'HR',
    'prefer_not_to_say': 'Prefer not to say',
  };

  static String label(String value) =>
      _labelOverrides[value] ?? Fmt.humanize(value);

  static List<SelectOption<String>> select(List<String> values) =>
      values.map((v) => SelectOption<String>(v, label(v))).toList();

  static const List<String> businessTypes = [
    'Retail',
    'Manufacturing',
    'Technology',
    'Healthcare',
    'Education',
    'Hospitality',
    'Construction',
    'Logistics',
    'Financial Services',
    'Agriculture',
    'Garments and Textile',
    'Other',
  ];

  static const List<String> currencies = [
    'BDT',
    'USD',
    'EUR',
    'GBP',
    'INR',
    'AED',
    'SAR',
    'MYR',
    'SGD',
    'PKR',
  ];

  static const List<String> timezones = [
    'Asia/Dhaka',
    'Asia/Kolkata',
    'Asia/Karachi',
    'Asia/Dubai',
    'Asia/Riyadh',
    'Asia/Kuala_Lumpur',
    'Asia/Singapore',
    'Asia/Bangkok',
    'Asia/Tokyo',
    'Europe/London',
    'Europe/Berlin',
    'America/New_York',
    'America/Chicago',
    'America/Los_Angeles',
    'Australia/Sydney',
    'UTC',
  ];

  static const List<String> dateFormats = [
    'dd MMM yyyy',
    'dd/MM/yyyy',
    'MM/dd/yyyy',
    'yyyy-MM-dd',
  ];

  static const List<String> months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}
