// ABOUTME: Widget tests for CommentInput component
// ABOUTME: Tests input field, send button, and posting state behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/comments/comments.dart';

void main() {
  group('CommentInput', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders with hint text and send button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentInput(
              controller: controller,
              isPosting: false,
              onSubmit: () {},
            ),
          ),
        ),
      );

      expect(find.text('Add comment...'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('shows loading spinner when isPosting', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentInput(
              controller: controller,
              isPosting: true,
              onSubmit: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
    });

    testWidgets('calls onSubmit when send tapped', (tester) async {
      var submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentInput(
              controller: controller,
              isPosting: false,
              onSubmit: () => submitted = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      expect(submitted, isTrue);
    });

    testWidgets('does not submit when isPosting', (tester) async {
      var submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentInput(
              controller: controller,
              isPosting: true,
              onSubmit: () => submitted = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(submitted, isFalse);
    });

    testWidgets('allows text input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentInput(
              controller: controller,
              isPosting: false,
              onSubmit: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test comment');
      await tester.pump();

      expect(controller.text, equals('Test comment'));
    });
  });
}
