import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the access + refresh tokens in the platform keystore
/// (Keychain / Keystore) — never in plaintext prefs.
class TokenStore {
  const TokenStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  static const _access = 'mwavuli.access';
  static const _refresh = 'mwavuli.refresh';

  Future<String?> accessToken() => _storage.read(key: _access);
  Future<String?> refreshToken() => _storage.read(key: _refresh);

  /// True if we have any stored session (used to auto-login on launch).
  Future<bool> hasSession() async =>
      (await accessToken()) != null || (await refreshToken()) != null;

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _access, value: access);
    await _storage.write(key: _refresh, value: refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}

final tokenStoreProvider = Provider((_) => const TokenStore());
