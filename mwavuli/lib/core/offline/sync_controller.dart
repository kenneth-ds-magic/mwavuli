import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_state.dart';
import '../api/api_client.dart';
import '../api/upload_service.dart';
import '../camera/photo_capture.dart';
import '../../data/local/drift_tree_store.dart';
import 'connectivity.dart';
import 'sync_service.dart';

import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/tree_repository.dart';
import '../../data/repositories/explore_repository.dart';

/// Binds real connectivity to the UI offline flag and flushes the offline
/// queue when the device comes back online. Keep alive by watching it once at
/// the app root (see main.dart).
final syncControllerProvider = Provider<void>((ref) {
  ref.listen(connectivityProvider, (_, next) {
    next.whenData((online) {
      final simulate = ref.read(simulateOfflineProvider);
      ref.read(offlineModeProvider.notifier).state = simulate || !online;
      if (online && !simulate) {
        ref.read(syncServiceProvider).flush(
              ref.read(apiClientProvider),
              ref.read(uploadServiceProvider),
              ref.read(photoCacheProvider),
              localStore: ref.read(localTreeStoreProvider),
            ).then((_) {
          ref.invalidate(syncQueueCountProvider);
          ref.invalidate(profileProvider);
          ref.invalidate(feedProvider);
          ref.invalidate(mapFeedProvider);
          ref.invalidate(exploreProvider);
          ref.invalidate(exploreFeedProvider);
        });
      }
    });
  });
  ref.listen(simulateOfflineProvider, (_, simulate) {
    final online = ref.read(connectivityProvider).maybeWhen(
          data: (v) => v,
          orElse: () => true,
        );
    ref.read(offlineModeProvider.notifier).state = simulate || !online;
  });
});
