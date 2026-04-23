// ABOUTME: Widget tests for TimelineOverlayPositionedItem.
// ABOUTME: Verifies base positioning and tap interaction.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_positioned_item.dart';

void main() {
  group(TimelineOverlayPositionedItem, () {
    testWidgets('uses timeline-derived position when not dragging', (
      tester,
    ) async {
      const item = TimelineOverlayItem(
        id: 'overlay-1',
        type: TimelineOverlayType.layer,
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 3),
        row: 2,
        label: 'My Overlay',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                TimelineOverlayPositionedItem(
                  item: item,
                  isDragging: false,
                  isSelected: false,
                  snappedStartMs: 0,
                  dragDeltaY: 0,
                  rowHeight: 40,
                  pixelsPerSecond: 100,
                  totalDuration: const Duration(seconds: 10),
                  color: Colors.blue,
                  isCollapsed: false,
                  trimExpansion: 0,
                  onTap: () {},
                  onLongPressStart: () {},
                  onLongPressMoveUpdate: (_) {},
                  onLongPressEnd: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.left, equals(100));
      expect(
        positioned.top,
        equals(2 * 40 + TimelineConstants.overlayRowGap / 2),
      );
      expect(find.text('My Overlay'), findsOneWidget);
    });

    testWidgets('invokes onTap callback', (tester) async {
      var tapCount = 0;
      const item = TimelineOverlayItem(
        id: 'overlay-2',
        type: TimelineOverlayType.layer,
        startTime: Duration.zero,
        endTime: Duration(seconds: 1),
        label: 'Tap Target',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                TimelineOverlayPositionedItem(
                  item: item,
                  isDragging: false,
                  isSelected: false,
                  snappedStartMs: 0,
                  dragDeltaY: 0,
                  rowHeight: 40,
                  pixelsPerSecond: 100,
                  totalDuration: const Duration(seconds: 10),
                  color: Colors.green,
                  isCollapsed: true,
                  trimExpansion: 0,
                  onTap: () => tapCount++,
                  onLongPressStart: () {},
                  onLongPressMoveUpdate: (_) {},
                  onLongPressEnd: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(tapCount, equals(1));
    });
  });
}
