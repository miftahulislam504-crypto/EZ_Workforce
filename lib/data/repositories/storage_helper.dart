import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase Storage used by several repositories.
class StorageHelper {
  StorageHelper(this._client);

  final SupabaseClient _client;

  static const Map<String, String> _mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt': 'text/plain',
    'csv': 'text/csv',
  };

  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static String mimeFor(String fileName) =>
      _mimeTypes[extensionOf(fileName)] ?? 'application/octet-stream';

  /// Keeps only characters that are safe inside an object path.
  static String safeName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'file' : cleaned;
  }

  Future<void> upload(
    String bucket,
    String path,
    Uint8List bytes, {
    required String fileName,
    bool upsert = false,
  }) async {
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeFor(fileName),
            upsert: upsert,
          ),
        );
  }

  Future<void> remove(String bucket, List<String> paths) async {
    if (paths.isEmpty) return;
    await _client.storage.from(bucket).remove(paths);
  }

  String publicUrl(String bucket, String path) =>
      _client.storage.from(bucket).getPublicUrl(path);

  Future<String> signedUrl(String bucket, String path, {int seconds = 3600}) =>
      _client.storage.from(bucket).createSignedUrl(path, seconds);
}
