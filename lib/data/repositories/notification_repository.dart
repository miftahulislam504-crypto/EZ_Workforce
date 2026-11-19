import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/communication_models.dart';
import '../models/json_utils.dart';

class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  static const List<String> categories = [
    'notice',
    'employee',
    'onboarding',
    'system',
    'security',
  ];

  Future<List<AppNotification>> list({
    bool unreadOnly = false,
    int offset = 0,
    int limit = 40,
  }) async {
    var request = _client.from('notifications').select();
    if (unreadOnly) request = request.isFilter('read_at', null);
    final rows = await request
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map(AppNotification.fromJson).toList();
  }

  Future<int> unreadCount() async {
    final rows = await _client
        .from('notifications')
        .select('id')
        .isFilter('read_at', null);
    return rows.length;
  }

  Future<void> markRead(String id) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> markAllRead() async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .isFilter('read_at', null);
  }

  Future<void> delete(String id) async {
    await _client.from('notifications').delete().eq('id', id);
  }

  /// Creates notifications for notices whose publish time has arrived.
  Future<void> dispatchDueNotices() async {
    await _client.rpc('dispatch_due_notice_notifications');
  }

  Future<List<NotificationPreference>> preferences() async {
    final rows = await _client.from('notification_preferences').select();
    final saved = {for (final r in rows) strOr(r['category']): r};
    return categories.map((category) {
      final row = saved[category];
      return NotificationPreference(
        category: category,
        inApp: row == null ? true : boolOr(row['in_app'], true),
        push: row == null ? true : boolOr(row['push'], true),
      );
    }).toList();
  }

  Future<void> savePreference({
    required String employeeId,
    required String organizationId,
    required NotificationPreference preference,
  }) async {
    await _client.from('notification_preferences').upsert({
      'employee_id': employeeId,
      'organization_id': organizationId,
      'category': preference.category,
      'in_app': preference.inApp,
      'push': preference.push,
    }, onConflict: 'employee_id,category');
  }

  RealtimeChannel subscribe(String employeeId, void Function() onChange) {
    return _client
        .channel('notifications-$employeeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'employee_id',
            value: employeeId,
          ),
          callback: (payload) => onChange(),
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
