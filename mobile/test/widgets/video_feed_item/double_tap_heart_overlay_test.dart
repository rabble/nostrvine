// ABOUTME: Tests for DoubleTapHeartOverlay animation widget.
// ABOUTME: Verifies trigger starts animation, resets after completion,
// ABOUTME: handles rapid triggers, and renders heart SVG.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_feed_item/double_tap_heart_overlay.dart';

void main() {
  group(DoubleTapHeartOverlay, () {
    late ValueNotifier<int> trigger;

    setUp(() {
      trigger = ValueNotifier<int>(0);
    });

    tearDown(() {
      trigger.dispose();
    });

    Widget buildWidget({ValueNotifier<int>? customTrigger}) {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              DoubleTapHeartOverlay(trigger: customTrigger ?? trigger),
            ],
          ),
        ),
      );
    }

    testWidgets('renders nothing before trigger', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('renders heart SVG after trigger', (tester) async {
      await tester.pumpWidget(buildWidget());

      trigger.value++;
      await tester.pump();
      // Pump a few frames to let the animation start
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('heart disappears after animation completes', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      trigger.value++;
      await tester.pump();
      // Advance past the full 1000ms animation
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('rapid triggers restart animation without crash', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      // Fire multiple rapid triggers
      trigger.value++;
      await tester.pump(const Duration(milliseconds: 100));
      trigger.value++;
      await tester.pump(const Duration(milliseconds: 100));
      trigger.value++;
      await tester.pump(const Duration(milliseconds: 100));

      // Should still show heart (animation restarted)
      expect(find.byType(SvgPicture), findsOneWidget);

      // Let it complete
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('is wrapped in IgnorePointer', (tester) async {
      await tester.pumpWidget(buildWidget());

      final overlay = find.byType(DoubleTapHeartOverlay);
      expect(overlay, findsOneWidget);

      // The overlay's direct child should be IgnorePointer
      expect(
        find.descendant(
          of: overlay,
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('respects trigger swap via didUpdateWidget', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final newTrigger = ValueNotifier<int>(0);
      addTearDown(newTrigger.dispose);

      // Swap to new trigger
      await tester.pumpWidget(buildWidget(customTrigger: newTrigger));

      // Old trigger should not animate
      trigger.value++;
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SvgPicture), findsNothing);

      // New trigger should animate
      newTrigger.value++;
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });
}
