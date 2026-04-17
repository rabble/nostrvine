// ABOUTME: Widget tests for TimelineOverlayItemTile.
// ABOUTME: Verifies label rendering and drag visual state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_item.dart';

void main() {
  group(TimelineOverlayItemTile, () {
    const item = TimelineOverlayItem(
      id: 'item-1',
      type: TimelineOverlayType.layer,
      startTime: Duration.zero,
      endTime: Duration(seconds: 3),
      label: 'Layer Label',
    );

    testWidgets('renders item label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TimelineOverlayItemTile(
              item: item,
              width: 120,
              height: 40,
              color: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Layer Label'), findsOneWidget);
    });

    testWidgets('applies foreground decoration while dragging', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TimelineOverlayItemTile(
              item: item,
              width: 120,
              height: 40,
              color: Colors.blue,
              isDragging: true,
            ),
          ),
        ),
      );

      final animated = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(animated.foregroundDecoration, isNotNull);
    });
  });
}
