// ABOUTME: Widget tests for CommentsDragHandle component
// ABOUTME: Tests visual appearance and dimensions of the drag handle indicator

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/comments/comments.dart';

void main() {
  group('CommentsDragHandle', () {
    testWidgets('renders container with correct dimensions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CommentsDragHandle())),
      );

      // Find the Container
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsOneWidget);

      // Verify dimensions through the Container widget
      final container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.maxWidth, equals(40));
      expect(container.constraints?.maxHeight, equals(4));
    });

    testWidgets('has correct visual styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CommentsDragHandle())),
      );

      // Find the Container and verify its decoration
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration?;

      expect(decoration, isNotNull);
      expect(decoration!.color, equals(Colors.white54));
      expect(decoration.borderRadius, equals(BorderRadius.circular(2)));
    });

    testWidgets('has correct margin', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CommentsDragHandle())),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(
        container.margin,
        equals(const EdgeInsets.symmetric(vertical: 12)),
      );
    });
  });
}
