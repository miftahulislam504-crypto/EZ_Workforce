import 'json_utils.dart';

class ContextEmployee {
  const ContextEmployee({
    required this.id,
    required this.employeeCode,
    required this.firstName,
    required this.fullName,
    this.lastName,
    this.photoPath,
    this.workEmail,
    this.status = 'active',
    this.branchId,
    this.departmentId,
    this.designationId,
    this.branchName,
    this.departmentName,
    this.designationTitle,
    this.onboardingStatus = 'completed',
  });

  factory ContextEmployee.fromJson(Json json) => ContextEmployee(
    id: strOr(json['id']),
    employeeCode: strOr(json['employee_code']),
    firstName: strOr(json['first_name']),
    lastName: str(json['last_name']),
    fullName: strOr(json['full_name']),
    photoPath: str(json['photo_path']),
    workEmail: str(json['work_email']),
    status: strOr(json['status'], 'active'),
    branchId: str(json['branch_id']),
    departmentId: str(json['department_id']),
    designationId: str(json['designation_id']),
    branchName: str(json['branch_name']),
    departmentName: str(json['department_name']),
    designationTitle: str(json['designation_title']),
    onboardingStatus: strOr(json['onboarding_status'], 'completed'),
  );

  final String id;
  final String employeeCode;
  final String firstName;
  final String? lastName;
  final String fullName;
  final String? photoPath;
  final String? workEmail;
  final String status;
  final String? branchId;
  final String? departmentId;
  final String? designationId;
  final String? branchName;
  final String? departmentName;
  final String? designationTitle;
  final String onboardingStatus;
}

class ContextRole {
  const ContextRole({
    required this.id,
    required this.name,
    required this.isOwner,
    required this.dataScope,
  });

  factory ContextRole.fromJson(Json json) => ContextRole(
    id: strOr(json['id']),
    name: strOr(json['name']),
    isOwner: boolOr(json['is_owner']),
    dataScope: strOr(json['data_scope'], 'self'),
  );

  final String id;
  final String name;
  final bool isOwner;
  final String dataScope;
}

class ContextOrganization {
  const ContextOrganization({
    required this.id,
    required this.name,
    this.logoPath,
    this.timezone = 'Asia/Dhaka',
    this.currency = 'BDT',
    this.dateFormat = 'dd MMM yyyy',
    this.timeFormat = '12h',
    this.plan = 'trial',
    this.subscriptionStatus = 'trialing',
    this.trialEndsAt,
  });

  factory ContextOrganization.fromJson(Json json) => ContextOrganization(
    id: strOr(json['id']),
    name: strOr(json['name']),
    logoPath: str(json['logo_path']),
    timezone: strOr(json['timezone'], 'Asia/Dhaka'),
    currency: strOr(json['currency'], 'BDT'),
    dateFormat: strOr(json['date_format'], 'dd MMM yyyy'),
    timeFormat: strOr(json['time_format'], '12h'),
    plan: strOr(json['plan'], 'trial'),
    subscriptionStatus: strOr(json['subscription_status'], 'trialing'),
    trialEndsAt: timestamp(json['trial_ends_at']),
  );

  final String id;
  final String name;
  final String? logoPath;
  final String timezone;
  final String currency;
  final String dateFormat;
  final String timeFormat;
  final String plan;
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
}

/// Everything the app needs to know about the signed-in person.
class AppContext {
  const AppContext({
    required this.employee,
    required this.role,
    required this.organization,
    required this.permissions,
    this.unreadNotifications = 0,
  });

  factory AppContext.fromJson(Json json) => AppContext(
    employee: ContextEmployee.fromJson(jsonMap(json['employee'])),
    role: ContextRole.fromJson(jsonMap(json['role'])),
    organization: ContextOrganization.fromJson(jsonMap(json['organization'])),
    permissions: ((json['permissions'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet(),
    unreadNotifications: intOr(json['unread_notifications']),
  );

  final ContextEmployee employee;
  final ContextRole role;
  final ContextOrganization organization;
  final Set<String> permissions;
  final int unreadNotifications;

  bool can(String permission) =>
      role.isOwner || permissions.contains(permission);
  bool canAny(Iterable<String> codes) => codes.any(can);

  /// Whether the person manages other people (any management permission).
  bool get isManagement =>
      can('dashboard.admin') || can('dashboard.team') || can('employees.view');
}
