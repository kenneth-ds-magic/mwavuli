import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_state.dart';
import '../app/theme.dart';

/// Slim banner shown while offline. Reports how many logs are queued in the
/// encrypted on-device sync queue.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineModeProvider);
    if (!offline) return const SizedBox.shrink();
    final queued = ref.watch(syncQueueProvider);

    return Material(
      color: Palette.brown700,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(
                      text: 'Offline',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                      text: ' — $queued logs queued. '
                          'They\'ll sync automatically when you reconnect.'),
                ]),
                style: const TextStyle(
                    color: Colors.white, fontSize: 12.5, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
