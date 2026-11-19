/// Turns an audit log row into a readable sentence such as
/// "Created branch: Gulshan Office".
class AuditText {
  AuditText._();

  static const Map<String, String> _entities = {
    'organizations': 'company profile',
    'branches': 'branch',
    'departments': 'department',
    'designations': 'designation',
    'roles': 'role',
    'employees': 'employee',
    'employee_private': 'sensitive details',
    'employee_documents': 'document',
    'notices': 'notice',
  };

  static const Map<String, String> _verbs = {
    'create': 'Created',
    'insert': 'Created',
    'update': 'Updated',
    'delete': 'Deleted',
  };

  /// Table names that can appear in the audit trail, for the filter menu.
  static List<String> get entityTypes => _entities.keys.toList();

  static String entityLabel(String entityType) =>
      _entities[entityType] ?? entityType.replaceAll('_', ' ');

  static String verb(String action) => _verbs[action] ?? action;

  static String describe({
    required String action,
    required String entityType,
    String? summary,
  }) {
    final base = '${verb(action)} ${entityLabel(entityType)}';
    if (summary == null || summary.trim().isEmpty) return base;
    return '$base: ${summary.trim()}';
  }
}
