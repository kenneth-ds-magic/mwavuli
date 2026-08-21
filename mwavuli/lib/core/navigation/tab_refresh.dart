import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline/sync_service.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/explore_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/tree_repository.dart';

/// Invalidate the data providers for a shell tab so its screen refetches.
///
/// Called when the user switches tabs (or re-taps the current tab).
void refreshShellTab(WidgetRef ref, int index) {
  switch (index) {
    case 0:
      ref.invalidate(exploreProvider);
      ref.invalidate(exploreFeedProvider);
      ref.invalidate(activityFeedProvider);
    case 1:
      ref.invalidate(mapFeedProvider);
    case 2:
      ref.invalidate(communityProvider);
      ref.invalidate(activityFeedProvider);
    case 3:
      ref.invalidate(profileProvider);
      ref.invalidate(syncQueueCountProvider);
  }
}
