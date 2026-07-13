import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_state.dart';
import '../api/api_client.dart';
import '../api/upload_service.dart';
import '../camera/photo_capture.dart';
import 'connectivity.dart';
import 'sync_service.dart';

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
            ).then((_) => ref.invalidate(syncQueueCountProvider));
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
