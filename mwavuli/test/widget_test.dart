import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwavuli/features/auth/auth_controller.dart';
import 'package:mwavuli/main.dart';

class _FakeAuthController extends AuthController {
  @override
  AuthStatus build() => AuthStatus.unauthenticated;
}

void main() {
  testWidgets('app boots to the welcome screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
        ],
        child: const MwavuliApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Mwavuli'), findsOneWidget);
    expect(find.text('Create free account'), findsOneWidget);
    expect(find.textContaining('Explore as guest'), findsOneWidget);
  });
}
