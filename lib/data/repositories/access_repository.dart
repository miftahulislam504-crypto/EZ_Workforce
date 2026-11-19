import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/access_models.dart';
import '../models/json_utils.dart';

class AccessRepository {
  AccessRepository(this._client);

  final SupabaseClient _client;

  Future<List<PermissionDef>> permissionCatalog() async {
    final rows = await _client.from('permissions').select().order('sort_order');
    return rows.map(PermissionDef.fromJson).toList();
  }

  /// Roles with their permission codes and the number of employees using them.
  Future<List<Role>> roles() async {
    final rows = await _client
        .from('roles')
        .select('*, role_permissions(permission_code)')
        .order('is_owner', ascending: false)
        .order('is_system', ascending: false)
        .order('name');

    final usage = <String, int>{};
    try {
      final result = await _client.rpc('role_usage');
      for (final row in jsonList(result)) {
        usage[strOr(row['role_id'])] = intOr(row['employee_count']);
      }
    } catch (_) {
      // Usage counts are informational; the list still works without them.
    }

    return rows.map((row) {
      final codes = jsonList(row['role_permissions'])
          .map((e) => strOr(e['permission_code']))
          .toSet();
      final role = Role.fromJson(row);
      return role.copyWith(
        permissionCodes: codes,
        employeeCount: usage[role.id] ?? 0,
      );
    }).toList();
  }

  Future<void> saveRole({
    String? id,
    required String organizationId,
    required String name,
    String? description,
    required String dataScope,
  }) async {
    final values = {
      'name': name,
      'description': description,
      'data_scope': dataScope,
    };
    if (id == null) {
      await _client.from('roles').insert({
        ...values,
        'organization_id': organizationId,
      });
    } else {
      await _client.from('roles').update(values).eq('id', id);
    }
  }

  Future<void> deleteRole(String id) async {
    await _client.from('roles').delete().eq('id', id);
  }

  Future<void> setPermissions(String roleId, Set<String> codes) async {
    await _client.rpc(
      'set_role_permissions',
      params: {'p_role': roleId, 'p_codes': codes.toList()..sort()},
    );
  }
}
