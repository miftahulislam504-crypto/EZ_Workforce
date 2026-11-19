import 'json_utils.dart';

class Employee {
  const Employee({
    required this.id,
    required this.organizationId,
    required this.employeeCode,
    required this.firstName,
    required this.roleId,
    this.lastName,
    this.fullName = '',
    this.userId,
    this.photoPath,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.maritalStatus,
    this.personalPhone,
    this.workPhone,
    this.workEmail,
    this.personalEmail,
    this.presentAddress,
    this.permanentAddress,
    this.emergencyContactName,
    this.emergencyContactRelation,
    this.emergencyContactPhone,
    this.joiningDate,
    this.employeeType = 'full_time',
    this.status = 'active',
    this.branchId,
    this.departmentId,
    this.designationId,
    this.managerId,
    this.workLocation,
    this.probationEndDate,
    this.confirmationDate,
    this.contractStartDate,
    this.contractEndDate,
    this.inviteCode,
    this.activatedAt,
    this.onboardingStatus = 'pending',
    this.archivedAt,
    this.createdAt,
  });

  factory Employee.fromJson(Json json) => Employee(
    id: strOr(json['id']),
    organizationId: strOr(json['organization_id']),
    userId: str(json['user_id']),
    employeeCode: strOr(json['employee_code']),
    firstName: strOr(json['first_name']),
    lastName: str(json['last_name']),
    fullName: strOr(json['full_name'], strOr(json['first_name'])),
    photoPath: str(json['photo_path']),
    dateOfBirth: dateOnly(json['date_of_birth']),
    gender: str(json['gender']),
    bloodGroup: str(json['blood_group']),
    maritalStatus: str(json['marital_status']),
    personalPhone: str(json['personal_phone']),
    workPhone: str(json['work_phone']),
    workEmail: str(json['work_email']),
    personalEmail: str(json['personal_email']),
    presentAddress: str(json['present_address']),
    permanentAddress: str(json['permanent_address']),
    emergencyContactName: str(json['emergency_contact_name']),
    emergencyContactRelation: str(json['emergency_contact_relation']),
    emergencyContactPhone: str(json['emergency_contact_phone']),
    joiningDate: dateOnly(json['joining_date']),
    employeeType: strOr(json['employee_type'], 'full_time'),
    status: strOr(json['status'], 'active'),
    branchId: str(json['branch_id']),
    departmentId: str(json['department_id']),
    designationId: str(json['designation_id']),
    managerId: str(json['manager_id']),
    roleId: strOr(json['role_id']),
    workLocation: str(json['work_location']),
    probationEndDate: dateOnly(json['probation_end_date']),
    confirmationDate: dateOnly(json['confirmation_date']),
    contractStartDate: dateOnly(json['contract_start_date']),
    contractEndDate: dateOnly(json['contract_end_date']),
    inviteCode: str(json['invite_code']),
    activatedAt: timestamp(json['activated_at']),
    onboardingStatus: strOr(json['onboarding_status'], 'pending'),
    archivedAt: timestamp(json['archived_at']),
    createdAt: timestamp(json['created_at']),
  );

  final String id;
  final String organizationId;
  final String? userId;
  final String employeeCode;
  final String firstName;
  final String? lastName;
  final String fullName;
  final String? photoPath;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String? maritalStatus;
  final String? personalPhone;
  final String? workPhone;
  final String? workEmail;
  final String? personalEmail;
  final String? presentAddress;
  final String? permanentAddress;
  final String? emergencyContactName;
  final String? emergencyContactRelation;
  final String? emergencyContactPhone;
  final DateTime? joiningDate;
  final String employeeType;
  final String status;
  final String? branchId;
  final String? departmentId;
  final String? designationId;
  final String? managerId;
  final String roleId;
  final String? workLocation;
  final DateTime? probationEndDate;
  final DateTime? confirmationDate;
  final DateTime? contractStartDate;
  final DateTime? contractEndDate;
  final String? inviteCode;
  final DateTime? activatedAt;
  final String onboardingStatus;
  final DateTime? archivedAt;
  final DateTime? createdAt;

  bool get isArchived => archivedAt != null;
  bool get hasLogin => userId != null;
}

/// Limited, non-sensitive view of an employee visible to every colleague.
class DirectoryEntry {
  const DirectoryEntry({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    required this.status,
    required this.employeeType,
    this.photoPath,
    this.workEmail,
    this.workPhone,
    this.joiningDate,
    this.branchId,
    this.branchName,
    this.departmentId,
    this.departmentName,
    this.designationId,
    this.designationTitle,
    this.managerId,
    this.managerName,
    this.hasLogin = false,
  });

  factory DirectoryEntry.fromJson(Json json) => DirectoryEntry(
    id: strOr(json['id']),
    employeeCode: strOr(json['employee_code']),
    fullName: strOr(json['full_name']),
    status: strOr(json['status'], 'active'),
    employeeType: strOr(json['employee_type'], 'full_time'),
    photoPath: str(json['photo_path']),
    workEmail: str(json['work_email']),
    workPhone: str(json['work_phone']),
    joiningDate: dateOnly(json['joining_date']),
    branchId: str(json['branch_id']),
    branchName: str(json['branch_name']),
    departmentId: str(json['department_id']),
    departmentName: str(json['department_name']),
    designationId: str(json['designation_id']),
    designationTitle: str(json['designation_title']),
    managerId: str(json['manager_id']),
    managerName: str(json['manager_name']),
    hasLogin: boolOr(json['has_login']),
  );

  final String id;
  final String employeeCode;
  final String fullName;
  final String status;
  final String employeeType;
  final String? photoPath;
  final String? workEmail;
  final String? workPhone;
  final DateTime? joiningDate;
  final String? branchId;
  final String? branchName;
  final String? departmentId;
  final String? departmentName;
  final String? designationId;
  final String? designationTitle;
  final String? managerId;
  final String? managerName;
  final bool hasLogin;
}

class EmployeePrivate {
  const EmployeePrivate({
    required this.employeeId,
    this.nationalId,
    this.passportNo,
    this.bankName,
    this.bankAccountName,
    this.bankAccountNumber,
    this.mfsProvider,
    this.mfsNumber,
  });

  factory EmployeePrivate.fromJson(Json json) => EmployeePrivate(
    employeeId: strOr(json['employee_id']),
    nationalId: str(json['national_id']),
    passportNo: str(json['passport_no']),
    bankName: str(json['bank_name']),
    bankAccountName: str(json['bank_account_name']),
    bankAccountNumber: str(json['bank_account_number']),
    mfsProvider: str(json['mfs_provider']),
    mfsNumber: str(json['mfs_number']),
  );

  final String employeeId;
  final String? nationalId;
  final String? passportNo;
  final String? bankName;
  final String? bankAccountName;
  final String? bankAccountNumber;
  final String? mfsProvider;
  final String? mfsNumber;
}

class EmployeeDocument {
  const EmployeeDocument({
    required this.id,
    required this.employeeId,
    required this.docType,
    required this.title,
    required this.storagePath,
    this.fileName,
    this.fileSize,
    this.createdAt,
  });

  factory EmployeeDocument.fromJson(Json json) => EmployeeDocument(
    id: strOr(json['id']),
    employeeId: strOr(json['employee_id']),
    docType: strOr(json['doc_type'], 'other'),
    title: strOr(json['title']),
    storagePath: strOr(json['storage_path']),
    fileName: str(json['file_name']),
    fileSize: json['file_size'] == null ? null : intOr(json['file_size']),
    createdAt: timestamp(json['created_at']),
  );

  final String id;
  final String employeeId;
  final String docType;
  final String title;
  final String storagePath;
  final String? fileName;
  final int? fileSize;
  final DateTime? createdAt;
}

class OnboardingItem {
  const OnboardingItem({
    required this.id,
    required this.employeeId,
    required this.title,
    this.description,
    this.isDone = false,
    this.doneAt,
    this.dueDate,
    this.sortOrder = 0,
  });

  factory OnboardingItem.fromJson(Json json) => OnboardingItem(
    id: strOr(json['id']),
    employeeId: strOr(json['employee_id']),
    title: strOr(json['title']),
    description: str(json['description']),
    isDone: boolOr(json['is_done']),
    doneAt: timestamp(json['done_at']),
    dueDate: dateOnly(json['due_date']),
    sortOrder: intOr(json['sort_order']),
  );

  final String id;
  final String employeeId;
  final String title;
  final String? description;
  final bool isDone;
  final DateTime? doneAt;
  final DateTime? dueDate;
  final int sortOrder;
}

class OnboardingTemplateItem {
  const OnboardingTemplateItem({
    required this.id,
    required this.title,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory OnboardingTemplateItem.fromJson(Json json) => OnboardingTemplateItem(
    id: strOr(json['id']),
    title: strOr(json['title']),
    description: str(json['description']),
    sortOrder: intOr(json['sort_order']),
    isActive: boolOr(json['is_active'], true),
  );

  final String id;
  final String title;
  final String? description;
  final int sortOrder;
  final bool isActive;
}
