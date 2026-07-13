import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwavuli/widgets/pill.dart';

void main() {
  testWidgets('Pill renders its label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: Pill('Verified')))),
    );
    expect(find.text('Verified'), findsOneWidget);
  });
}
