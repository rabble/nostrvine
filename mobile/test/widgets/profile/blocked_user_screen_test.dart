// ABOUTME: Tests for BlockedUserScreen widget
// ABOUTME: Verifies blocked user placeholder screen displays correctly

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/blocked_user_screen.dart';

void main() {
  group('BlockedUserScreen', () {
    testWidgets('displays unavailable message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BlockedUserScreen(onBack: () {})),
      );

      expect(find.text('This account is not available'), findsOneWidget);
    });

    testWidgets('displays back button in app bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BlockedUserScreen(onBack: () {})),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('calls onBack when back button tapped', (tester) async {
      var backCalled = false;

      await tester.pumpWidget(
        MaterialApp(home: BlockedUserScreen(onBack: () => backCalled = true)),
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      expect(backCalled, isTrue);
    });
  });
}
