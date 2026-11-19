import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/json_utils.dart';
import '../models/org_models.dart';
import 'storage_helper.dart';

class OrganizationRepository {
  OrganizationRepository(this._client, this._storage);

  final SupabaseClient _client;
  final StorageHelper _storage;

  // ------------------------------------------------------------ company
  Future<Organization> getOrganization() async {
    final row = await _client.from('organizations').select().single();
    return Organization.fromJson(row);
  }

  Future<void> updateOrganization(String id, Json values) async {
    await _client.from('organizations').update(values).eq('id', id);
  }

  Future<String> uploadLogo({
    required String organizationId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = StorageHelper.extensionOf(fileName);
    final path =
        '$organizationId/logo-${DateTime.now().millisecondsSinceEpoch}'
        '${ext.isEmpty ? '' : '.$ext'}';
    await _storage.upload('org-assets', path, bytes, fileName: fileName);
    await _client
        .from('organizations')
        .update({'logo_path': path})
        .eq('id', organizationId);
    return path;
  }

  String? logoUrl(String? path) =>
      path == null ? null : _storage.publicUrl('org-assets', path);

  // ------------------------------------------------------------ branches
  Future<List<Branch>> branches() async {
    final rows = await _client.from('branches').select().order('name');
    return rows.map(Branch.fromJson).toList();
  }

  Future<void> saveBranch({
    String? id,
    required String organizationId,
    required Json values,
  }) async {
    if (id == null) {
      await _client.from('branches').insert({
        ...values,
        'organization_id': organizationId,
      });
    } else {
      await _client.from('branches').update(values).eq('id', id);
    }
  }

  Future<void> deleteBranch(String id) async {
    await _client.from('branches').delete().eq('id', id);
  }

  // --------------------------------------------------------- departments
  Future<List<Department>> departments() async {
    final rows = await _client.from('departments').select().order('name');
    return rows.map(Department.fromJson).toList();
  }

  Future<void> saveDepartment({
    String? id,
    required String organizationId,
    required Json values,
  }) async {
    if (id == null) {
      await _client.from('departments').insert({
        ...values,
        'organization_id': organizationId,
      });
    } else {
      await _client.from('departments').update(values).eq('id', id);
    }
  }

  Future<void> deleteDepartment(String id) async {
    await _client.from('departments').delete().eq('id', id);
  }

  // -------------------------------------------------------- designations
  Future<List<Designation>> designations() async {
    final rows = await _client
        .from('designations')
        .select()
        .order('level', ascending: false)
        .order('title');
    return rows.map(Designation.fromJson).toList();
  }

  Future<void> saveDesignation({
    String? id,
    required String organizationId,
    required Json values,
  }) async {
    if (id == null) {
      await _client.from('designations').insert({
        ...values,
        'organization_id': organizationId,
      });
    } else {
      await _client.from('designations').update(values).eq('id', id);
    }
  }

  Future<void> deleteDesignation(String id) async {
    await _client.from('designations').delete().eq('id', id);
  }
}
