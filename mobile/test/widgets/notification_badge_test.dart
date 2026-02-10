// ABOUTME: Widget tests for NotificationBadge and AnimatedNotificationBadge
// ABOUTME: Tests badge visibility based on count, text rendering, and dot for high counts

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/notification_badge.dart';

void main() {
  group(NotificationBadge, () {
    Widget buildTestWidget({required int count, bool showBadge = true}) {
      return MaterialApp(
        home: Scaffold(
          body: NotificationBadge(
            count: count,
            showBadge: showBadge,
            child: const Icon(Icons.notifications),
          ),
        ),
      );
    }

    testWidgets('shows no badge when count is 0', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(count: 0));

      // When count is 0, no Positioned badge should be rendered
      expect(
        find.descendant(
          of: find.byType(NotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('shows no badge when count is negative', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(count: -1));

      expect(
        find.descendant(
          of: find.byType(NotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('shows badge with count when count > 0', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(count: 5));

      // Should have Positioned element for badge overlay
      expect(
        find.descendant(
          of: find.byType(NotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsOneWidget,
      );
      // Should display the count
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows count text for count up to 99', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(count: 99));

      expect(find.text('99'), findsOneWidget);
    });

    testWidgets('shows dot icon instead of text when count > 99', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(count: 100));

      // Should show dot icon instead of text
      expect(find.byIcon(Icons.circle), findsOneWidget);
      // Should not show the count as text
      expect(find.text('100'), findsNothing);
    });

    testWidgets('shows no badge when showBadge is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(count: 5, showBadge: false));

      // Should not have Positioned badge
      expect(
        find.descendant(
          of: find.byType(NotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });
  });

  group(AnimatedNotificationBadge, () {
    Widget buildAnimatedTestWidget({
      required int count,
      bool showBadge = true,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AnimatedNotificationBadge(
            count: count,
            showBadge: showBadge,
            child: const Icon(Icons.notifications),
          ),
        ),
      );
    }

    testWidgets('shows no badge when count is 0', (WidgetTester tester) async {
      await tester.pumpWidget(buildAnimatedTestWidget(count: 0));

      expect(
        find.descendant(
          of: find.byType(AnimatedNotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('shows badge with count when count > 0', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildAnimatedTestWidget(count: 3));

      expect(
        find.descendant(
          of: find.byType(AnimatedNotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows dot icon when count > 99', (WidgetTester tester) async {
      await tester.pumpWidget(buildAnimatedTestWidget(count: 150));

      expect(find.byIcon(Icons.circle), findsOneWidget);
      expect(find.text('150'), findsNothing);
    });

    testWidgets('shows no badge when showBadge is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildAnimatedTestWidget(count: 5, showBadge: false),
      );

      expect(
        find.descendant(
          of: find.byType(AnimatedNotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
    });
  });
}
