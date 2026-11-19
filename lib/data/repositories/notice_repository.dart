import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/communication_models.dart';
import '../models/json_utils.dart';
import 'storage_helper.dart';

class NoticeStats {
  const NoticeStats({
    required this.audience,
    required this.read,
    required this.acknowledged,
  });

  final int audience;
  final int read;
  final int acknowledged;
}

class NoticeRepository {
  NoticeRepository(this._client, this._storage);

  final SupabaseClient _client;
  final StorageHelper _storage;

  Future<List<Notice>> list({
    required String employeeId,
    String? category,
    String? status,
    int offset = 0,
    int limit = 30,
  }) async {
    var request = _client.from('notices').select();
    if (category != null) request = request.eq('category', category);
    if (status != null) request = request.eq('status', status);
    final rows = await request
        .order('is_pinned', ascending: false)
        .order('publish_at', ascending: false)
        .range(offset, offset + limit - 1);
    return _withReceipts(rows, employeeId);
  }

  Future<Notice?> get(String id, {required String employeeId}) async {
    final row = await _client
        .from('notices')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final merged = await _withReceipts([row], employeeId);
    return merged.first;
  }

  Future<List<Notice>> _withReceipts(List<Json> rows, String employeeId) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => strOr(r['id'])).toList();
    final receipts = await _client
        .from('notice_receipts')
        .select('notice_id, read_at, acknowledged_at')
        .eq('employee_id', employeeId)
        .inFilter('notice_id', ids);
    final byNotice = {for (final r in receipts) strOr(r['notice_id']): r};
    return rows.map((row) {
      final receipt = byNotice[strOr(row['id'])];
      return Notice.fromJson({
        ...row,
        'read_at': receipt?['read_at'],
        'acknowledged_at': receipt?['acknowledged_at'],
      });
    }).toList();
  }

  Future<Notice> save({String? id, required Json values}) async {
    final Json row;
    if (id == null) {
      row = await _client.from('notices').insert(values).select().single();
    } else {
      row = await _client
          .from('notices')
          .update(values)
          .eq('id', id)
          .select()
          .single();
    }
    return Notice.fromJson(row);
  }

  Future<void> delete(Notice notice) async {
    await _client.from('notices').delete().eq('id', notice.id);
    await _storage.remove(
      'notice-attachments',
      notice.attachments.map((a) => a.path).toList(),
    );
  }

  Future<void> markRead({
    required String noticeId,
    required String employeeId,
    required String organizationId,
  }) async {
    final existing = await _client
        .from('notice_receipts')
        .select('read_at')
        .eq('notice_id', noticeId)
        .eq('employee_id', employeeId)
        .maybeSingle();
    if (existing != null && existing['read_at'] != null) return;
    await _client.from('notice_receipts').upsert({
      'notice_id': noticeId,
      'employee_id': employeeId,
      'organization_id': organizationId,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'notice_id,employee_id');
  }

  Future<void> acknowledge({
    required String noticeId,
    required String employeeId,
    required String organizationId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('notice_receipts').upsert({
      'notice_id': noticeId,
      'employee_id': employeeId,
      'organization_id': organizationId,
      'read_at': now,
      'acknowledged_at': now,
    }, onConflict: 'notice_id,employee_id');
  }

  Future<NoticeStats> stats(String noticeId) async {
    final result = await _client.rpc(
      'notice_stats',
      params: {'p_notice': noticeId},
    );
    final map = jsonMap(result);
    return NoticeStats(
      audience: intOr(map['audience']),
      read: intOr(map['read']),
      acknowledged: intOr(map['acknowledged']),
    );
  }

  Future<NoticeAttachment> uploadAttachment({
    required String organizationId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path =
        '$organizationId/files/'
        '${DateTime.now().millisecondsSinceEpoch}_${StorageHelper.safeName(fileName)}';
    await _storage.upload(
      'notice-attachments',
      path,
      bytes,
      fileName: fileName,
    );
    return NoticeAttachment(path: path, name: fileName, size: bytes.length);
  }

  /// Deletes uploaded files that were never saved with a notice.
  Future<void> removeAttachmentFiles(List<NoticeAttachment> attachments) async {
    if (attachments.isEmpty) return;
    try {
      await _storage.remove(
        'notice-attachments',
        attachments.map((a) => a.path).toList(),
      );
    } catch (_) {
      // A leftover file is harmless; do not block the user.
    }
  }

  Future<String> attachmentUrl(NoticeAttachment attachment) =>
      _storage.signedUrl('notice-attachments', attachment.path);
}
