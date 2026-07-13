import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/token_store.dart';
import '../../data/repositories/profile_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Owns auth state. Bootstraps from stored tokens on launch, and exposes
/// login/register/logout that call the API and flip the status.
class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    _bootstrap();
    return AuthStatus.unknown;
  }

  Future<void> _bootstrap() async {
    final has = await ref.read(tokenStoreProvider).hasSession();
    state = has ? AuthStatus.authenticated : AuthStatus.unauthenticated;
  }

  Future<void> login(String identifier, String password) async {
    await ref.read(apiClientProvider).login(identifier, password);
    state = AuthStatus.authenticated;
    ref.invalidate(profileProvider);
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String displayName,
    required int birthYear,
  }) async {
    await ref.read(apiClientProvider).register(
          email: email,
          username: username,
          password: password,
          displayName: displayName,
          birthYear: birthYear,
        );
    state = AuthStatus.authenticated;
    ref.invalidate(profileProvider);
  }

  Future<void> logout() async {
    await ref.read(apiClientProvider).logout();
    state = AuthStatus.unauthenticated;
    ref.invalidate(profileProvider);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthStatus>(AuthController.new);
