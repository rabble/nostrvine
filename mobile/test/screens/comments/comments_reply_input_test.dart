// ABOUTME: Widget tests for CommentsReplyInput component
// ABOUTME: Tests inline reply input field, send button, and posting state behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/comments/comments.dart';

void main() {
  group('CommentsReplyInput', () {
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
            body: CommentsReplyInput(
              controller: controller,
              isPosting: false,
              onSubmit: () {},
            ),
          ),
        ),
      );

      expect(find.text('Write a reply...'), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('shows loading spinner when isPosting', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsReplyInput(
              controller: controller,
              isPosting: true,
              onSubmit: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
    });

    testWidgets('calls onSubmit when send tapped', (tester) async {
      var submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsReplyInput(
              controller: controller,
              isPosting: false,
              onSubmit: () => submitted = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(submitted, isTrue);
    });

    testWidgets('does not submit when isPosting', (tester) async {
      var submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsReplyInput(
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
            body: CommentsReplyInput(
              controller: controller,
              isPosting: false,
              onSubmit: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test reply');
      await tester.pump();

      expect(controller.text, equals('Test reply'));
    });
  });
}
