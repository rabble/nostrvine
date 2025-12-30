// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openvine/main.dart';

void main() {
  testWidgets('divine app UI validation test', (tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DivineApp());

    // Give it one pump to start the initialization
    await tester.pump();

    // Verify the app loads with proper Flutter structure
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);

    // During initialization, we should see a loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Verify initialization status text is displayed
    expect(find.text('Checking authentication...'), findsOneWidget);

    // Verify the app shows at least one text widget (initialization status)
    expect(find.byType(Text), findsAtLeastNWidgets(1));
    // TODO(any): Fix and re-enable this test
  }, skip: true);
}
