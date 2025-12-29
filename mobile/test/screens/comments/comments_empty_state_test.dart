// ABOUTME: Widget tests for CommentsEmptyState component
// ABOUTME: Tests empty state display and Classic Vine notice functionality

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/comments/comments.dart';

void main() {
  group('CommentsEmptyState', () {
    group('standard empty state', () {
      testWidgets('displays "No comments yet" message', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: CommentsEmptyState(isClassicVine: false)),
          ),
        );

        expect(
          find.text('No comments yet.\nBe the first to comment!'),
          findsOneWidget,
        );
      });

      testWidgets(
        'does NOT show Classic Vine notice when isClassicVine is false',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(body: CommentsEmptyState(isClassicVine: false)),
            ),
          );

          expect(find.text('Classic Vine'), findsNothing);
          expect(find.byIcon(Icons.history), findsNothing);
        },
      );

      testWidgets('is centered on screen', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: CommentsEmptyState(isClassicVine: false)),
          ),
        );

        expect(find.byType(Center), findsOneWidget);
      });
    });

    group('Classic Vine state', () {
      testWidgets('shows Classic Vine notice when isClassicVine is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: CommentsEmptyState(isClassicVine: true)),
          ),
        );

        expect(find.text('Classic Vine'), findsOneWidget);
        expect(find.byIcon(Icons.history), findsOneWidget);
      });

      testWidgets('shows archive import message for Classic Vine', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: CommentsEmptyState(isClassicVine: true)),
          ),
        );

        expect(
          find.text(
            "We're still working on importing old comments "
            "from the archive. They're not ready yet.",
          ),
          findsOneWidget,
        );
      });

      testWidgets('still shows "No comments yet" with Classic Vine notice', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: CommentsEmptyState(isClassicVine: true)),
          ),
        );

        // Should show both the Classic Vine notice AND the empty state message
        expect(find.text('Classic Vine'), findsOneWidget);
        expect(
          find.text('No comments yet.\nBe the first to comment!'),
          findsOneWidget,
        );
      });

      testWidgets('has styled container for Classic Vine notice', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: CommentsEmptyState(isClassicVine: true)),
          ),
        );

        // Find the decorated container (the one with orange styling)
        final containers = tester.widgetList<Container>(find.byType(Container));
        final decoratedContainer = containers.firstWhere(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).borderRadius != null,
          orElse: () => throw StateError('No decorated container found'),
        );

        final decoration = decoratedContainer.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(12)));
        expect(decoration.border, isNotNull);
      });
    });
  });
}
