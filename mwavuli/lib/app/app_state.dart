import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide UI state (accessibility + offline demo toggles).
///
/// In production, [offlineModeProvider] is driven by the connectivity
/// service (see core/offline/connectivity.dart); it is exposed as a
/// StateProvider here so the UI has a single source of truth to read.

/// WCAG: high-contrast theme toggle.
final highContrastProvider = StateProvider<bool>((_) => false);

/// WCAG: larger-text toggle (also respects the OS text scale).
final largeTextProvider = StateProvider<bool>((_) => false);

/// Whether the device is currently offline (connectivity or forced simulation).
final offlineModeProvider = StateProvider<bool>((_) => false);

/// Demo toggle: force offline mode even when connectivity is available.
final simulateOfflineProvider = StateProvider<bool>((_) => false);

/// Number of logs waiting in the encrypted on-device sync queue.
final syncQueueProvider = StateProvider<int>((_) => 0);

/// When set, Profile opens this tab (0 trees, 1 stats, 2 settings) then clears.
final profileTabRequestProvider = StateProvider<int?>((_) => null);

/// When true, Profile opens the Followers sheet once then clears.
final profileOpenFollowersRequestProvider = StateProvider<bool>((_) => false);
