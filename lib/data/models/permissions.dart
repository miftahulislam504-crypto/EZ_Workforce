/// Permission codes. They mirror the `permissions` table in the database.
class Perm {
  const Perm._();

  static const String dashboardAdmin = 'dashboard.admin';
  static const String dashboardTeam = 'dashboard.team';
  static const String orgManage = 'org.manage';
  static const String branchesManage = 'branches.manage';
  static const String departmentsManage = 'departments.manage';
  static const String designationsManage = 'designations.manage';
  static const String rolesView = 'roles.view';
  static const String rolesManage = 'roles.manage';
  static const String rolesAssign = 'roles.assign';
  static const String employeesView = 'employees.view';
  static const String employeesCreate = 'employees.create';
  static const String employeesEdit = 'employees.edit';
  static const String employeesArchive = 'employees.archive';
  static const String employeesViewPrivate = 'employees.view_private';
  static const String employeesEditPrivate = 'employees.edit_private';
  static const String employeesDocuments = 'employees.documents';
  static const String employeesExport = 'employees.export';
  static const String onboardingManage = 'onboarding.manage';
  static const String noticesManage = 'notices.manage';
  static const String auditView = 'audit.view';
}
