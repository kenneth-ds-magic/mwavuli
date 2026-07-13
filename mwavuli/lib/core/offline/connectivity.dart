import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` when the device has a network path, `false` otherwise.
/// Wire this into [offlineModeProvider] at app start to drive the banner
/// and to trigger the sync queue flush on reconnect.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final conn = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      !r.contains(ConnectivityResult.none) && r.isNotEmpty;

  yield online(await conn.checkConnectivity());
  yield* conn.onConnectivityChanged.map(online);
});
