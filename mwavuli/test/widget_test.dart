import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwavuli/main.dart';

void main() {
  testWidgets('app boots to the welcome screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MwavuliApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('mwavuli'), findsOneWidget);
    expect(find.text('Create free account'), findsOneWidget);
    expect(find.text('Explore as guest  →'), findsOneWidget);
  });
}
