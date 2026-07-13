import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../local/drift_tree_store.dart';
import '../models/tree.dart';
import '../models/tree_comment.dart';

/// Map pin filters. Category is applied server-side with bbox; health and
/// verified are applied client-side on the fetched set.
class MapFilters {
  const MapFilters({
    this.category = 'all',
    this.health,
    this.verifiedOnly = false,
  });

  final String category;
  final TreeHealth? health;
  final bool verifiedOnly;

  bool get isActive =>
      category != 'all' || health != null || verifiedOnly;

  MapFilters copyWith({
    String? category,
    TreeHealth? health,
    bool clearHealth = false,
    bool? verifiedOnly,
  }) =>
      MapFilters(
        category: category ?? this.category,
        health: clearHealth ? null : (health ?? this.health),
        verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      );

  @override
  bool operator ==(Object other) =>
      other is MapFilters &&
      other.category == category &&
      other.health == health &&
      other.verifiedOnly == verifiedOnly;

  @override
  int get hashCode => Object.hash(category, health, verifiedOnly);
}

/// Offline-first source of truth for trees. Tries the network, falls back to
/// the local cache, and always keeps the cache warm for offline use.
class TreeRepository {
  TreeRepository(this._local, this._api);
  final LocalTreeStore _local;
  final ApiClient _api;

  Future<List<Tree>> feed({
    String? bbox,
    String? before,
    int limit = 50,
    String? search,
    String filter = 'all',
    double? lat,
    double? lng,
    int radiusM = 50000,
  }) async {
    try {
      final remote = await _api.fetchFeed(
        bbox: bbox,
        before: before,
        limit: limit,
        search: search,
        filter: filter,
        lat: lat,
        lng: lng,
        radiusM: radiusM,
      );
      for (final t in remote) {
        await _local.upsert(t);
      }
      return remote;
    } catch (_) {
      if (before != null) rethrow;
      return _local.all();
    }
  }

  Future<Tree?> byId(String id) async {
    try {
      final detail = await _api.fetchTreeDetail(id);
      await _local.upsert(detail.tree);
      return detail.tree;
    } catch (_) {
      return _local.byId(id);
    }
  }

  Future<TreeDetail?> detailById(String id) async {
    try {
      final detail = await _api.fetchTreeDetail(id);
      await _local.upsert(detail.tree);
      return detail;
    } catch (_) {
      final tree = await _local.byId(id);
      if (tree == null) return null;
      return TreeDetail(tree: tree);
    }
  }

  Future<List<TreeComment>> comments(String treeId) =>
      _api.fetchComments(treeId);

  Future<TreeComment> postComment(String treeId, String body) =>
      _api.postComment(treeId, body);

  Future<int> like(String treeId) => _api.like(treeId);

  Future<int> unlike(String treeId) => _api.unlike(treeId);

  Future<void> reportTree(String treeId, {String reason = 'other'}) =>
      _api.report(targetType: 'tree', targetId: treeId, reason: reason);

  Future<bool> save(String treeId) => _api.saveTree(treeId);

  Future<bool> unsave(String treeId) => _api.unsaveTree(treeId);

  Future<List<Tree>> saved() => _api.fetchSavedTrees();

  /// Persist a freshly captured tree locally (the sync queue uploads later).
  Future<void> saveLocal(Tree tree) => _local.upsert(tree);

  Future<({bool verified, int verificationCount, bool userVerified})> verify(
      String treeId) async {
    return _api.verifyTree(treeId);
  }
}

final treeRepositoryProvider = Provider(
  (ref) => TreeRepository(
    ref.watch(localTreeStoreProvider),
    ref.watch(apiClientProvider),
  ),
);

/// Optional map viewport bbox (`minLng,minLat,maxLng,maxLat`). Null loads all.
final mapBboxProvider = StateProvider<String?>((_) => null);

final mapFiltersProvider = StateProvider<MapFilters>((_) => const MapFilters());

/// Rounds bbox coords so tiny camera jitter does not refetch the feed.
String? normalizeMapBbox(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(',');
  if (parts.length != 4) return raw;
  final nums = parts.map((p) => double.tryParse(p.trim())).toList();
  if (nums.any((n) => n == null)) return raw;
  return nums
      .map((n) => n!.toStringAsFixed(4))
      .join(',');
}

final mapFeedProvider = FutureProvider<List<Tree>>((ref) async {
  final bbox = ref.watch(mapBboxProvider);
  if (bbox == null) return const [];
  final filters = ref.watch(mapFiltersProvider);
  return ref.read(treeRepositoryProvider).feed(
        bbox: bbox,
        filter: filters.category,
      );
});

final feedProvider =
    FutureProvider<List<Tree>>((ref) => ref.watch(treeRepositoryProvider).feed());

final treeByIdProvider = FutureProvider.family<Tree?, String>(
    (ref, id) => ref.watch(treeRepositoryProvider).byId(id));

final treeDetailProvider = FutureProvider.family<TreeDetail?, String>(
    (ref, id) => ref.watch(treeRepositoryProvider).detailById(id));

final treeCommentsProvider = FutureProvider.family<List<TreeComment>, String>(
    (ref, treeId) => ref.watch(treeRepositoryProvider).comments(treeId));
