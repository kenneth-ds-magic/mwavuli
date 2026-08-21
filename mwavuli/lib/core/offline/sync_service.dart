import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/upload_service.dart';
import '../camera/photo_capture.dart';

/// Offline-first write queue. Each item is a create-request plus the on-disk
/// paths of its (already EXIF-stripped) photos. Stored **encrypted** via
/// flutter_secure_storage; photo bytes live in the app cache (PhotoCache).
class SyncService {
  SyncService(this._storage);
  final FlutterSecureStorage _storage;
  static const _key = 'mwavuli.sync_queue';

  Future<List<Map<String, dynamic>>> _read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _write(List<Map<String, dynamic>> q) =>
      _storage.write(key: _key, value: jsonEncode(q));

  /// Queue a create-request plus the cache paths of its photos.
  Future<int> enqueue(Map<String, dynamic> body, List<String> photoPaths) async {
    final q = await _read()..add({'type': 'create', 'body': body, 'photoPaths': photoPaths});
    await _write(q);
    return q.length;
  }

  /// Queue an update-request for an existing tree when offline.
  Future<int> enqueueUpdate(String treeId, Map<String, dynamic> body) async {
    final q = await _read()..add({
      'type': 'update',
      'treeId': treeId,
      'body': body,
    });
    await _write(q);
    return q.length;
  }

  Future<int> pendingCount() async => (await _read()).length;

  /// Validate queued items; if an item is missing required fields (e.g. missing body,
  /// missing commonName on create, or missing treeId on update), delete it.
  Future<int> validateAndCleanQueue() async {
    final q = await _read();
    if (q.isEmpty) return 0;
    final valid = <Map<String, dynamic>>[];
    var removedCount = 0;
    for (final item in q) {
      final type = item['type'] as String? ?? 'create';
      if (type == 'update') {
        final treeId = item['treeId'] as String?;
        final body = item['body'];
        if (treeId != null &&
            treeId.isNotEmpty &&
            body is Map &&
            body.isNotEmpty) {
          valid.add(item);
        } else {
          removedCount++;
        }
      } else {
        final body = item['body'];
        if (body is Map &&
            body['commonName'] != null &&
            (body['commonName'] as String).trim().isNotEmpty) {
          valid.add(item);
        } else {
          removedCount++;
        }
      }
    }
    if (removedCount > 0) {
      await _write(valid);
    }
    return removedCount;
  }

  /// Upload every queued log: create the tree, then PUT each cached photo to
  /// its presigned URL. Successful items (and their cache files) are removed;
  /// failures stay queued for the next attempt.
  Future<void> flush(ApiClient api, UploadService upload, PhotoCache cache) async {
    final q = await _read();
    if (q.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (final item in q) {
      try {
        final type = item['type'] as String? ?? 'create';
        if (type == 'update') {
          final treeId = item['treeId'] as String?;
          final body = (item['body'] as Map).cast<String, dynamic>();
          if (treeId != null) {
            await api.updateTree(treeId, body);
          }
        } else {
          final body = (item['body'] as Map).cast<String, dynamic>();
          final paths = (item['photoPaths'] as List?)?.cast<String>() ?? const [];
          final res = await api.createTree(body);
          final uploads = (res['uploads'] as List?) ?? const [];
          for (var i = 0; i < uploads.length && i < paths.length; i++) {
            final uploadMap = (uploads[i] as Map).cast<String, dynamic>();
            final bytes = await cache.read(paths[i]);
            final photoId = uploadMap['photoId'] as String?;
            if (bytes != null && photoId != null) {
              try {
                await api.uploadPhoto(photoId, bytes);
              } catch (_) {
                // Individual photo upload error does not force re-creation of tree.
              }
            }
          }
          for (final p in paths) {
            await cache.delete(p);
          }
        }
      } catch (_) {
        remaining.add(item);
      }
    }
    await _write(remaining);
  }
}

final secureStorageProvider = Provider((_) => const FlutterSecureStorage());

final syncServiceProvider =
    Provider((ref) => SyncService(ref.watch(secureStorageProvider)));

final syncQueueCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(syncServiceProvider).pendingCount();
});
