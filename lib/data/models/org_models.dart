import 'json_utils.dart';

class Organization {
  const Organization({
    required this.id,
    required this.name,
    this.legalName,
    this.businessType,
    this.logoPath,
    this.email,
    this.phone,
    this.website,
    this.addressLine,
    this.city,
    this.stateRegion,
    this.postalCode,
    this.country,
    this.timezone = 'Asia/Dhaka',
    this.currency = 'BDT',
    this.dateFormat = 'dd MMM yyyy',
    this.timeFormat = '12h',
    this.fiscalYearStartMonth = 1,
    this.employeeIdPrefix = 'EMP',
    this.plan = 'trial',
    this.subscriptionStatus = 'trialing',
    this.trialEndsAt,
    this.maxEmployees = 50,
    this.maxBranches = 5,
  });

  factory Organization.fromJson(Json json) => Organization(
    id: strOr(json['id']),
    name: strOr(json['name']),
    legalName: str(json['legal_name']),
    businessType: str(json['business_type']),
    logoPath: str(json['logo_path']),
    email: str(json['email']),
    phone: str(json['phone']),
    website: str(json['website']),
    addressLine: str(json['address_line']),
    city: str(json['city']),
    stateRegion: str(json['state_region']),
    postalCode: str(json['postal_code']),
    country: str(json['country']),
    timezone: strOr(json['timezone'], 'Asia/Dhaka'),
    currency: strOr(json['currency'], 'BDT'),
    dateFormat: strOr(json['date_format'], 'dd MMM yyyy'),
    timeFormat: strOr(json['time_format'], '12h'),
    fiscalYearStartMonth: intOr(json['fiscal_year_start_month'], 1),
    employeeIdPrefix: strOr(json['employee_id_prefix'], 'EMP'),
    plan: strOr(json['plan'], 'trial'),
    subscriptionStatus: strOr(json['subscription_status'], 'trialing'),
    trialEndsAt: timestamp(json['trial_ends_at']),
    maxEmployees: intOr(json['max_employees'], 50),
    maxBranches: intOr(json['max_branches'], 5),
  );

  final String id;
  final String name;
  final String? legalName;
  final String? businessType;
  final String? logoPath;
  final String? email;
  final String? phone;
  final String? website;
  final String? addressLine;
  final String? city;
  final String? stateRegion;
  final String? postalCode;
  final String? country;
  final String timezone;
  final String currency;
  final String dateFormat;
  final String timeFormat;
  final int fiscalYearStartMonth;
  final String employeeIdPrefix;
  final String plan;
  final String subscriptionStatus;
  final DateTime? trialEndsAt;
  final int maxEmployees;
  final int maxBranches;
}

class Branch {
  const Branch({
    required this.id,
    required this.name,
    this.code,
    this.addressLine,
    this.city,
    this.phone,
    this.email,
    this.managerEmployeeId,
    this.isHeadOffice = false,
    this.isActive = true,
  });

  factory Branch.fromJson(Json json) => Branch(
    id: strOr(json['id']),
    name: strOr(json['name']),
    code: str(json['code']),
    addressLine: str(json['address_line']),
    city: str(json['city']),
    phone: str(json['phone']),
    email: str(json['email']),
    managerEmployeeId: str(json['manager_employee_id']),
    isHeadOffice: boolOr(json['is_head_office']),
    isActive: boolOr(json['is_active'], true),
  );

  final String id;
  final String name;
  final String? code;
  final String? addressLine;
  final String? city;
  final String? phone;
  final String? email;
  final String? managerEmployeeId;
  final bool isHeadOffice;
  final bool isActive;
}

class Department {
  const Department({
    required this.id,
    required this.name,
    this.code,
    this.description,
    this.headEmployeeId,
    this.parentDepartmentId,
    this.isActive = true,
  });

  factory Department.fromJson(Json json) => Department(
    id: strOr(json['id']),
    name: strOr(json['name']),
    code: str(json['code']),
    description: str(json['description']),
    headEmployeeId: str(json['head_employee_id']),
    parentDepartmentId: str(json['parent_department_id']),
    isActive: boolOr(json['is_active'], true),
  );

  final String id;
  final String name;
  final String? code;
  final String? description;
  final String? headEmployeeId;
  final String? parentDepartmentId;
  final bool isActive;
}

class Designation {
  const Designation({
    required this.id,
    required this.title,
    this.level = 1,
    this.departmentId,
    this.description,
    this.isActive = true,
  });

  factory Designation.fromJson(Json json) => Designation(
    id: strOr(json['id']),
    title: strOr(json['title']),
    level: intOr(json['level'], 1),
    departmentId: str(json['department_id']),
    description: str(json['description']),
    isActive: boolOr(json['is_active'], true),
  );

  final String id;
  final String title;
  final int level;
  final String? departmentId;
  final String? description;
  final bool isActive;
}
