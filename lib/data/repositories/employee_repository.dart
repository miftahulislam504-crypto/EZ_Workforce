import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee_models.dart';
import '../models/json_utils.dart';
import 'storage_helper.dart';

class DirectoryFilter {
  const DirectoryFilter({
    this.query = '',
    this.status,
    this.branchId,
    this.departmentId,
    this.employeeType,
  });

  final String query;
  final String? status;
  final String? branchId;
  final String? departmentId;
  final String? employeeType;

  bool get hasFilters =>
      status != null ||
      branchId != null ||
      departmentId != null ||
      employeeType != null;

  DirectoryFilter copyWith({
    String? query,
    Object? status = _keep,
    Object? branchId = _keep,
    Object? departmentId = _keep,
    Object? employeeType = _keep,
  }) {
    return DirectoryFilter(
      query: query ?? this.query,
      status: identical(status, _keep) ? this.status : status as String?,
      branchId: identical(branchId, _keep)
          ? this.branchId
          : branchId as String?,
      departmentId: identical(departmentId, _keep)
          ? this.departmentId
          : departmentId as String?,
      employeeType: identical(employeeType, _keep)
          ? this.employeeType
          : employeeType as String?,
    );
  }

  static const Object _keep = Object();

  @override
  bool operator ==(Object other) =>
      other is DirectoryFilter &&
      other.query == query &&
      other.status == status &&
      other.branchId == branchId &&
      other.departmentId == departmentId &&
      other.employeeType == employeeType;

  @override
  int get hashCode =>
      Object.hash(query, status, branchId, departmentId, employeeType);
}

class EmployeeRepository {
  EmployeeRepository(this._client, this._storage);

  final SupabaseClient _client;
  final StorageHelper _storage;

  /// Removes characters that would break the PostgREST `or` filter syntax.
  static String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[,()%*\\"]'), ' ').trim();

  // ---------------------------------------------------------- directory
  Future<List<DirectoryEntry>> searchDirectory(
    DirectoryFilter filter, {
    int offset = 0,
    int limit = 24,
  }) async {
    var request = _client.from('employee_directory').select();
    final query = _sanitize(filter.query);
    if (query.isNotEmpty) {
      request = request.or(
        'full_name.ilike.%$query%,employee_code.ilike.%$query%,'
        'work_email.ilike.%$query%,work_phone.ilike.%$query%',
      );
    }
    if (filter.status != null) request = request.eq('status', filter.status!);
    if (filter.branchId != null)
      request = request.eq('branch_id', filter.branchId!);
    if (filter.departmentId != null) {
      request = request.eq('department_id', filter.departmentId!);
    }
    if (filter.employeeType != null) {
      request = request.eq('employee_type', filter.employeeType!);
    }
    final rows = await request
        .order('full_name')
        .range(offset, offset + limit - 1);
    return rows.map(DirectoryEntry.fromJson).toList();
  }

  /// Lightweight list for pickers such as the reporting manager.
  Future<List<DirectoryEntry>> pickerList() async {
    final rows = await _client
        .from('employee_directory')
        .select()
        .not('status', 'in', '(resigned,terminated)')
        .order('full_name')
        .limit(1000);
    return rows.map(DirectoryEntry.fromJson).toList();
  }

  Future<DirectoryEntry?> directoryEntry(String id) async {
    final row = await _client
        .from('employee_directory')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : DirectoryEntry.fromJson(row);
  }

  // ------------------------------------------------------ full profile
  /// Returns null when the row is not visible to the caller.
  Future<Employee?> employee(String id) async {
    final row = await _client
        .from('employees')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Employee.fromJson(row);
  }

  Future<Employee> create(Json values) async {
    final row = await _client
        .from('employees')
        .insert(values)
        .select()
        .single();
    return Employee.fromJson(row);
  }

  Future<void> update(String id, Json values) async {
    await _client.from('employees').update(values).eq('id', id);
  }

  Future<void> archive(String id, {required bool archive}) async {
    await _client.rpc(
      'archive_employee',
      params: {'p_employee': id, 'p_archive': archive},
    );
  }

  Future<String> regenerateInvite(String id) async {
    final code = await _client.rpc(
      'regenerate_invite',
      params: {'p_employee': id},
    );
    return code.toString();
  }

  /// All employee rows visible to the caller, used for CSV export.
  Future<List<Employee>> exportRows(DirectoryFilter filter) async {
    var request = _client.from('employees').select();
    final query = _sanitize(filter.query);
    if (query.isNotEmpty) {
      request = request.or(
        'full_name.ilike.%$query%,employee_code.ilike.%$query%,work_email.ilike.%$query%',
      );
    }
    if (filter.status != null) request = request.eq('status', filter.status!);
    if (filter.branchId != null)
      request = request.eq('branch_id', filter.branchId!);
    if (filter.departmentId != null) {
      request = request.eq('department_id', filter.departmentId!);
    }
    if (filter.employeeType != null) {
      request = request.eq('employee_type', filter.employeeType!);
    }
    final rows = await request
        .isFilter('archived_at', null)
        .order('full_name')
        .limit(5000);
    return rows.map(Employee.fromJson).toList();
  }

  // ------------------------------------------------------------ photo
  Future<String> uploadPhoto({
    required String organizationId,
    required String employeeId,
    required bool isSelf,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = StorageHelper.extensionOf(fileName);
    final path =
        '$organizationId/$employeeId/photo-${DateTime.now().millisecondsSinceEpoch}'
        '${ext.isEmpty ? '' : '.$ext'}';
    await _storage.upload('avatars', path, bytes, fileName: fileName);
    if (isSelf) {
      await _client.rpc('set_my_photo', params: {'p_path': path});
    } else {
      await _client
          .from('employees')
          .update({'photo_path': path})
          .eq('id', employeeId);
    }
    return path;
  }

  String? photoUrl(String? path) =>
      path == null ? null : _storage.publicUrl('avatars', path);

  // ------------------------------------------------------ sensitive data
  Future<EmployeePrivate?> privateData(String employeeId) async {
    final row = await _client
        .from('employee_private')
        .select()
        .eq('employee_id', employeeId)
        .maybeSingle();
    return row == null ? null : EmployeePrivate.fromJson(row);
  }

  Future<void> savePrivateData({
    required String organizationId,
    required String employeeId,
    required Json values,
  }) async {
    await _client.from('employee_private').upsert({
      ...values,
      'employee_id': employeeId,
      'organization_id': organizationId,
    }, onConflict: 'employee_id');
  }

  // ---------------------------------------------------------- documents
  Future<List<EmployeeDocument>> documents(String employeeId) async {
    final rows = await _client
        .from('employee_documents')
        .select()
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false);
    return rows.map(EmployeeDocument.fromJson).toList();
  }

  Future<void> uploadDocument({
    required String organizationId,
    required String employeeId,
    required String docType,
    required String title,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path =
        '$organizationId/$employeeId/'
        '${DateTime.now().millisecondsSinceEpoch}_${StorageHelper.safeName(fileName)}';
    await _storage.upload(
      'employee-documents',
      path,
      bytes,
      fileName: fileName,
    );
    try {
      await _client.from('employee_documents').insert({
        'organization_id': organizationId,
        'employee_id': employeeId,
        'doc_type': docType,
        'title': title,
        'storage_path': path,
        'file_name': fileName,
        'file_size': bytes.length,
        'mime_type': StorageHelper.mimeFor(fileName),
        'uploaded_by': _client.auth.currentUser?.id,
      });
    } catch (_) {
      await _storage.remove('employee-documents', [path]);
      rethrow;
    }
  }

  Future<void> deleteDocument(EmployeeDocument document) async {
    await _client.from('employee_documents').delete().eq('id', document.id);
    await _storage.remove('employee-documents', [document.storagePath]);
  }

  Future<String> documentUrl(EmployeeDocument document) =>
      _storage.signedUrl('employee-documents', document.storagePath);

  // --------------------------------------------------------- onboarding
  Future<List<OnboardingItem>> onboardingItems(String employeeId) async {
    final rows = await _client
        .from('onboarding_items')
        .select()
        .eq('employee_id', employeeId)
        .order('sort_order')
        .order('created_at');
    return rows.map(OnboardingItem.fromJson).toList();
  }

  Future<void> setOnboardingDone(String itemId, bool done) async {
    await _client
        .from('onboarding_items')
        .update({'is_done': done})
        .eq('id', itemId);
  }

  Future<void> addOnboardingItem({
    required String organizationId,
    required String employeeId,
    required String title,
    String? description,
    int sortOrder = 100,
  }) async {
    await _client.from('onboarding_items').insert({
      'organization_id': organizationId,
      'employee_id': employeeId,
      'title': title,
      'description': description,
      'sort_order': sortOrder,
    });
  }

  Future<void> deleteOnboardingItem(String itemId) async {
    await _client.from('onboarding_items').delete().eq('id', itemId);
  }

  // ------------------------------------------------- onboarding template
  Future<List<OnboardingTemplateItem>> templateItems() async {
    final rows = await _client
        .from('onboarding_template_items')
        .select()
        .order('sort_order')
        .order('created_at');
    return rows.map(OnboardingTemplateItem.fromJson).toList();
  }

  Future<void> saveTemplateItem({
    String? id,
    required String organizationId,
    required Json values,
  }) async {
    if (id == null) {
      await _client.from('onboarding_template_items').insert({
        ...values,
        'organization_id': organizationId,
      });
    } else {
      await _client
          .from('onboarding_template_items')
          .update(values)
          .eq('id', id);
    }
  }

  Future<void> deleteTemplateItem(String id) async {
    await _client.from('onboarding_template_items').delete().eq('id', id);
  }
}
