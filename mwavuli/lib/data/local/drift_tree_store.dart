import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../models/tree.dart';
import 'drift/app_database.dart';

/// Durable, offline-first SQLite database store (via Drift).
abstract interface class LocalTreeStore {
  Future<List<Tree>> all({bool? fromServerFilter});
  Future<Tree?> byId(String id);
  Future<void> upsert(Tree tree, {bool fromServer = true});
  Future<void> markSynced(String id, Tree syncedTree);
  Future<void> delete(String id);
  Future<void> clear();

  String resolveId(String id);
  void aliasOfflineId(String offlineId, String serverId);

  // User persistence in SQLite
  Future<void> saveUser(ProfileData profile, {bool fromServer = true});
  Future<ProfileData?> getCachedUser();
  Future<void> clearUser(String id);
}

class DriftTreeStore implements LocalTreeStore {
  DriftTreeStore(this._db);
  final AppDatabase _db;
  final Map<String, String> _offlineAliases = {};

  @override
  String resolveId(String id) {
    return _offlineAliases[id] ?? id;
  }

  @override
  void aliasOfflineId(String offlineId, String serverId) {
    _offlineAliases[offlineId] = serverId;
  }

  @override
  Future<List<Tree>> all({bool? fromServerFilter}) async {
    final payloads = await _db.allPayloads(fromServerFilter: fromServerFilter);
    return payloads
        .map((p) => Tree.fromCacheJson(jsonDecode(p) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Tree?> byId(String id) async {
    final targetId = resolveId(id);
    final payload = await _db.payloadById(targetId);
    if (payload == null) return null;
    return Tree.fromCacheJson(jsonDecode(payload) as Map<String, dynamic>);
  }

  @override
  Future<void> upsert(Tree tree, {bool fromServer = true}) async {
    await _db.upsertTree(
      tree.id,
      jsonEncode(tree.toCacheJson()),
      fromServer: fromServer,
    );
  }

  @override
  Future<void> markSynced(String id, Tree syncedTree) async {
    await _db.markTreeSynced(
      id,
      jsonEncode(syncedTree.copyWith(synced: true).toCacheJson()),
    );
  }

  @override
  Future<void> delete(String id) async {
    await _db.deleteTree(id);
  }

  @override
  Future<void> clear() => _db.clearAllTrees();

  // --- User Profile Persistence in SQLite ---
  @override
  Future<void> saveUser(ProfileData profile, {bool fromServer = true}) async {
    final map = profile.rawApiData ?? {
      'profile': {
        'id': profile.profile.id,
        'email': profile.profile.email,
        'username': profile.profile.username,
        'displayName': profile.profile.displayName,
        'bio': profile.profile.bio,
        'avatarUrl': profile.profile.avatarUrl,
        'points': profile.profile.points,
        'level': profile.profile.level,
        'levelName': profile.profile.levelName,
        'locationLabel': profile.profile.locationLabel,
        'createdAt': profile.profile.createdAt.toIso8601String(),
      },
      'social': {
        'following': profile.following,
        'followers': profile.followers,
      },
      'stats': {
        'trees': profile.treeCount,
        'species': profile.speciesCount,
        'points': profile.points,
      },
      'badges': profile.badges.map((b) => {
        'code': b.code,
        'name': b.name,
        'icon': b.icon,
        'awardedAt': b.awardedAt.toIso8601String(),
      }).toList(),
      'trees': profile.trees.map((t) => t.toCacheJson()).toList(),
    };
    await _db.upsertUser(
      id: profile.profile.id,
      email: profile.profile.email,
      username: profile.profile.username,
      displayName: profile.profile.displayName,
      role: 'user',
      payload: jsonEncode(map),
      fromServer: fromServer,
    );
  }

  @override
  Future<ProfileData?> getCachedUser() async {
    final cached = await _db.latestCachedUser();
    if (cached == null) return null;
    try {
      final map = jsonDecode(cached.payload) as Map<String, dynamic>;
      return ProfileData.fromApi(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearUser(String id) async {
    await _db.clearUser(id);
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final localTreeStoreProvider = Provider<LocalTreeStore>(
  (ref) => DriftTreeStore(ref.watch(appDatabaseProvider)),
);
