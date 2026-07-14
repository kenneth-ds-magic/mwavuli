import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/token_store.dart';

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
    // profileProvider watches auth — flipping state is enough to refetch.
    state = AuthStatus.authenticated;
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
  }

  Future<void> logout() async {
    await ref.read(apiClientProvider).logout();
    // Do not invalidate profileProvider here — it watches this provider, and
    // invalidate() from a dependency raises CircularDependencyError.
    state = AuthStatus.unauthenticated;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthStatus>(AuthController.new);
