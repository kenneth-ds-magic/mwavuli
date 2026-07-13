import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tree.dart';
import 'drift/app_database.dart';

/// Durable, offline-first cache of trees (SQLite via Drift).
abstract interface class LocalTreeStore {
  Future<List<Tree>> all();
  Future<Tree?> byId(String id);
  Future<void> upsert(Tree tree);
}

class DriftTreeStore implements LocalTreeStore {
  DriftTreeStore(this._db);
  final AppDatabase _db;

  @override
  Future<List<Tree>> all() async {
    final payloads = await _db.allPayloads();
    return payloads
        .map((p) => Tree.fromCacheJson(jsonDecode(p) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Tree?> byId(String id) async {
    final payload = await _db.payloadById(id);
    if (payload == null) return null;
    return Tree.fromCacheJson(jsonDecode(payload) as Map<String, dynamic>);
  }

  @override
  Future<void> upsert(Tree tree) async {
    await _db.upsertTree(tree.id, jsonEncode(tree.toCacheJson()));
  }

  Future<void> clear() => _db.clearAll();
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final localTreeStoreProvider = Provider<LocalTreeStore>(
  (ref) => DriftTreeStore(ref.watch(appDatabaseProvider)),
);
