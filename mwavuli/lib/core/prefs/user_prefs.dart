import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persisted user preferences (on-device only).
class UserPrefs {
  UserPrefs(this._storage);
  final FlutterSecureStorage _storage;

  static const _defaultFuzzyKey = 'mwavuli.prefs.default_fuzzy';

  Future<bool> defaultFuzzyLocation() async {
    final v = await _storage.read(key: _defaultFuzzyKey);
    if (v == null) return true;
    return v == 'true';
  }

  Future<void> setDefaultFuzzyLocation(bool value) =>
      _storage.write(key: _defaultFuzzyKey, value: value.toString());
}

final userPrefsProvider = Provider(
  (ref) => UserPrefs(const FlutterSecureStorage()),
);

final defaultFuzzyLocationProvider =
    AsyncNotifierProvider<DefaultFuzzyNotifier, bool>(DefaultFuzzyNotifier.new);

class DefaultFuzzyNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(userPrefsProvider).defaultFuzzyLocation();

  Future<void> set(bool value) async {
    await ref.read(userPrefsProvider).setDefaultFuzzyLocation(value);
    state = AsyncData(value);
  }
}
