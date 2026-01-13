// ABOUTME: Widget tests for CommentsSkeletonLoader component
// ABOUTME: Tests skeleton loader rendering and accessibility

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/comments/widgets/comment_skeleton_loader.dart';

void main() {
  group('CommentsSkeletonLoader', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CommentsSkeletonLoader())),
      );

      expect(find.byType(CommentsSkeletonLoader), findsOneWidget);
    });

    testWidgets('has semantic identifier for accessibility', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CommentsSkeletonLoader())),
      );

      final semanticsFinder = find.bySemanticsLabel('Loading comments');
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('renders ListView with 6 skeleton items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CommentsSkeletonLoader())),
      );

      // Verify ListView is present
      expect(find.byType(ListView), findsOneWidget);

      // Verify 6 skeleton items
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.semanticChildCount, equals(6));
    });
  });
}
