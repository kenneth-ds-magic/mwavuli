import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../features/auth/auth_controller.dart';
import '../models/community.dart';

class CommunityRepository {
  CommunityRepository(this._api);
  final ApiClient _api;

  Future<CommunityData> fetchCommunity() async {
    final data = await _api.fetchCommunity();
    return CommunityData.fromApi(data);
  }

  Future<List<SuggestedUser>> searchUsers(String query) async {
    final items = await _api.searchUsers(query);
    return items.map(SuggestedUser.fromApi).toList();
  }

  Future<PublicUserProfile> fetchPublicUser(String userId) async {
    final data = await _api.fetchUser(userId);
    return PublicUserProfile.fromApi(data);
  }

  Future<SuggestedUser> fetchUser(String userId) async {
    final data = await _api.fetchUser(userId);
    return SuggestedUser.fromApi(data);
  }

  Future<void> follow(String userId) => _api.followUser(userId);

  Future<void> unfollow(String userId) => _api.unfollowUser(userId);

  Future<({List<LeaderboardEntry> items, bool hasMore})> fetchLeaderboardPage({
    int limit = 10,
    int offset = 0,
  }) async {
    final page = await _api.fetchLeaderboard(limit: limit, offset: offset);
    return (items: page.items, hasMore: page.hasMore);
  }
}

final communityRepositoryProvider =
    Provider((ref) => CommunityRepository(ref.watch(apiClientProvider)));

final communityProvider = FutureProvider<CommunityData>((ref) async {
  ref.watch(authControllerProvider);
  return ref.watch(communityRepositoryProvider).fetchCommunity();
});

final publicUserProvider =
    FutureProvider.family<PublicUserProfile, String>((ref, userId) async {
  return ref.watch(communityRepositoryProvider).fetchPublicUser(userId);
});

/// Paginated community activity (shared by Community + Explore notifications).
class ActivityFeedPage {
  const ActivityFeedPage({
    required this.items,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<ActivityItem> items;
  final bool hasMore;
  final bool loadingMore;

  ActivityFeedPage copyWith({
    List<ActivityItem>? items,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      ActivityFeedPage(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class ActivityFeedNotifier extends AsyncNotifier<ActivityFeedPage> {
  static const pageSize = 20;

  @override
  Future<ActivityFeedPage> build() async {
    final items =
        await ref.watch(apiClientProvider).fetchActivity(limit: pageSize);
    return ActivityFeedPage(
      items: items,
      hasMore: items.length >= pageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    if (current.items.isEmpty) return;

    final before = current.items.last.createdAt?.toUtc().toIso8601String();
    if (before == null) {
      state = AsyncData(current.copyWith(hasMore: false));
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref.read(apiClientProvider).fetchActivity(
            limit: pageSize,
            before: before,
          );
      final seen = current.items.map((a) => a.id).whereType<String>().toSet();
      final merged = [
        ...current.items,
        ...next.where((a) => a.id == null || !seen.contains(a.id)),
      ];
      state = AsyncData(
        ActivityFeedPage(
          items: merged,
          hasMore: next.length >= pageSize,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false, hasMore: false));
    }
  }
}

final activityFeedProvider =
    AsyncNotifierProvider<ActivityFeedNotifier, ActivityFeedPage>(
  ActivityFeedNotifier.new,
);

/// Explore notifications sheet — same source as Community recent activity.
final recentActivityProvider = FutureProvider.autoDispose<List<ActivityItem>>(
  (ref) async {
    final page = await ref.watch(activityFeedProvider.future);
    return page.items;
  },
);
