// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_matrix/main.dart';

void main() {
  testWidgets('MobileMatrixApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MobileMatrixApp());
    await tester.pump();

    // Verify that the title is rendered.
    expect(find.text('Mobile Matrix'), findsOneWidget);

    // Allow background init timers to settle
    await tester.pump(const Duration(seconds: 6));
  });
}
