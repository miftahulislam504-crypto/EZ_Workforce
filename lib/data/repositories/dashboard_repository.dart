import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/communication_models.dart';
import '../models/dashboard_models.dart';
import '../models/json_utils.dart';

class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  Future<AdminStats> adminStats() async {
    final result = await _client.rpc('dashboard_admin_stats');
    return AdminStats.fromJson(jsonMap(result));
  }

  Future<TeamStats> teamStats() async {
    final result = await _client.rpc('dashboard_team_stats');
    return TeamStats.fromJson(jsonMap(result));
  }

  Future<List<Celebration>> celebrations({int days = 30}) async {
    final result = await _client.rpc(
      'upcoming_celebrations',
      params: {'p_days': days},
    );
    return jsonList(result).map(Celebration.fromJson).toList();
  }
}

class AuditRepository {
  AuditRepository(this._client);

  final SupabaseClient _client;

  Future<List<AuditEntry>> list({
    String? entityType,
    int offset = 0,
    int limit = 40,
  }) async {
    var request = _client.from('audit_logs').select();
    if (entityType != null) request = request.eq('entity_type', entityType);
    final rows = await request
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map(AuditEntry.fromJson).toList();
  }
}
