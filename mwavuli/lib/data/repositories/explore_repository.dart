import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../models/community.dart';
import '../models/explore.dart';
import '../models/tree.dart';
import 'community_repository.dart';
import 'tree_repository.dart';

class ExploreRepository {
  ExploreRepository(this._api);
  final ApiClient _api;

  Future<ExploreData> fetchExplore({
    double? lat,
    double? lng,
    int radiusM = 50000,
  }) =>
      _api.fetchExplore(lat: lat, lng: lng, radiusM: radiusM);
}

final exploreRepositoryProvider =
    Provider((ref) => ExploreRepository(ref.watch(apiClientProvider)));

final exploreLocationProvider =
    StateProvider<ExploreLocation>((_) => const ExploreLocation());

final exploreFeedQueryProvider =
    StateProvider<ExploreFeedQuery>((_) => const ExploreFeedQuery());

final exploreProvider = FutureProvider<ExploreData>((ref) {
  final loc = ref.watch(exploreLocationProvider);
  return ref.watch(exploreRepositoryProvider).fetchExplore(
        lat: loc.lat,
        lng: loc.lng,
      );
});

/// Paginated community feed for Explore.
class ExploreFeedPage {
  const ExploreFeedPage({
    required this.trees,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<Tree> trees;
  final bool hasMore;
  final bool loadingMore;

  ExploreFeedPage copyWith({
    List<Tree>? trees,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      ExploreFeedPage(
        trees: trees ?? this.trees,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class ExploreFeedNotifier extends AsyncNotifier<ExploreFeedPage> {
  static const pageSize = 15;

  @override
  Future<ExploreFeedPage> build() async {
    final query = ref.watch(exploreFeedQueryProvider);
    final loc = ref.watch(exploreLocationProvider);
    final trees = await ref.watch(treeRepositoryProvider).feed(
          limit: pageSize,
          search: query.search,
          filter: query.filter,
          lat: query.filter == 'near' ? loc.lat : query.lat,
          lng: query.filter == 'near' ? loc.lng : query.lng,
          radiusM: query.radiusM,
        );
    return ExploreFeedPage(
      trees: trees,
      hasMore: trees.length >= pageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    if (current.trees.isEmpty) return;

    final before = current.trees.last.createdAt?.toUtc().toIso8601String();
    if (before == null) {
      state = AsyncData(current.copyWith(hasMore: false));
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final query = ref.read(exploreFeedQueryProvider);
      final loc = ref.read(exploreLocationProvider);
      final next = await ref.read(treeRepositoryProvider).feed(
            before: before,
            limit: pageSize,
            search: query.search,
            filter: query.filter,
            lat: query.filter == 'near' ? loc.lat : query.lat,
            lng: query.filter == 'near' ? loc.lng : query.lng,
            radiusM: query.radiusM,
          );
      final seen = current.trees.map((t) => t.id).toSet();
      final merged = [
        ...current.trees,
        ...next.where((t) => !seen.contains(t.id)),
      ];
      state = AsyncData(
        ExploreFeedPage(
          trees: merged,
          hasMore: next.length >= pageSize,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false, hasMore: false));
    }
  }
}

final exploreFeedProvider =
    AsyncNotifierProvider<ExploreFeedNotifier, ExploreFeedPage>(
  ExploreFeedNotifier.new,
);

final exploreUserSearchProvider =
    FutureProvider.family<List<SuggestedUser>, String>((ref, q) async {
  final trimmed = q.trim();
  if (trimmed.length < 2) return const [];
  return ref.watch(communityRepositoryProvider).searchUsers(trimmed);
});
