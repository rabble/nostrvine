// ABOUTME: Tests for InboxTabToggle segmented toggle widget
// ABOUTME: Verifies tab rendering, selection, badges, and semantics

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/inbox/inbox_tab_toggle.dart';

void main() {
  Widget buildSubject({
    int selectedIndex = 0,
    ValueChanged<int>? onChanged,
    int notificationBadgeCount = 0,
    int messagesBadgeCount = 0,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: InboxTabToggle(
          selectedIndex: selectedIndex,
          onChanged: onChanged ?? (_) {},
          notificationBadgeCount: notificationBadgeCount,
          messagesBadgeCount: messagesBadgeCount,
        ),
      ),
    );
  }

  group(InboxTabToggle, () {
    group('renders', () {
      testWidgets('renders Messages and Notifications labels', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());

        expect(find.text('Messages'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
      });

      testWidgets('renders Messages tab with semantics', (tester) async {
        await tester.pumpWidget(buildSubject());

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Messages tab',
          ),
        );
        expect(semantics.properties.button, isTrue);
      });

      testWidgets('renders Notifications tab with semantics', (tester) async {
        await tester.pumpWidget(buildSubject());

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Notifications tab',
          ),
        );
        expect(semantics.properties.button, isTrue);
      });
    });

    group('badges', () {
      testWidgets('shows notification badge when count > 0', (tester) async {
        await tester.pumpWidget(
          buildSubject(notificationBadgeCount: 5),
        );

        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('shows messages badge when count > 0', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            selectedIndex: 1,
            messagesBadgeCount: 3,
          ),
        );

        expect(find.text('3'), findsOneWidget);
      });

      testWidgets('hides badges when counts are 0', (tester) async {
        await tester.pumpWidget(buildSubject());

        // Only Messages and Notifications text should be present
        expect(find.byType(Text), findsNWidgets(2));
      });

      testWidgets('caps badge display at 99+', (tester) async {
        await tester.pumpWidget(
          buildSubject(notificationBadgeCount: 150),
        );

        expect(find.text('99+'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('calls onChanged with 1 when Notifications tapped', (
        tester,
      ) async {
        int? tappedIndex;
        await tester.pumpWidget(
          buildSubject(onChanged: (index) => tappedIndex = index),
        );

        await tester.tap(find.text('Notifications'));
        expect(tappedIndex, equals(1));
      });

      testWidgets('calls onChanged with 0 when Messages tapped', (
        tester,
      ) async {
        int? tappedIndex;
        await tester.pumpWidget(
          buildSubject(
            selectedIndex: 1,
            onChanged: (index) => tappedIndex = index,
          ),
        );

        await tester.tap(find.text('Messages'));
        expect(tappedIndex, equals(0));
      });
    });
  });
}
