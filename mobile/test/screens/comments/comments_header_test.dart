// ABOUTME: Widget tests for CommentsHeader component
// ABOUTME: Tests title display, close button, and callback functionality

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/comments/comments.dart';

void main() {
  group('CommentsHeader', () {
    testWidgets('displays "Comments" title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentsHeader(onClose: () {})),
        ),
      );

      expect(find.text('Comments'), findsOneWidget);

      // Verify title styling
      final textWidget = tester.widget<Text>(find.text('Comments'));
      expect(textWidget.style?.color, equals(Colors.white));
      expect(textWidget.style?.fontSize, equals(18));
      expect(textWidget.style?.fontWeight, equals(FontWeight.bold));
    });

    testWidgets('displays close button with correct icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentsHeader(onClose: () {})),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);

      // Verify icon color
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.close));
      expect(iconWidget.color, equals(Colors.white));
    });

    testWidgets('calls onClose when close button is tapped', (tester) async {
      var closeCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentsHeader(onClose: () => closeCallCount++)),
        ),
      );

      // Tap the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(closeCallCount, equals(1));
    });

    testWidgets('has correct layout structure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentsHeader(onClose: () {})),
        ),
      );

      // Should have a Row containing Text and IconButton
      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(Spacer), findsOneWidget);
    });
  });
}
