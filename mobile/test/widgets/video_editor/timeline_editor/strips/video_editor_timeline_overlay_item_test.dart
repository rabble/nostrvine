// ABOUTME: Widget tests for TimelineOverlayItemTile.
// ABOUTME: Verifies label rendering and drag visual state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show StickerData, StickerPackData;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_item.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show WidgetLayer;

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

    group('_StickerPreview', () {
      WidgetLayer buildStickerLayer({Map<String, dynamic>? meta}) {
        return WidgetLayer(
          width: 40,
          widget: const SizedBox(width: 40, height: 40),
          meta: meta,
        );
      }

      testWidgets('shows layerName from valid sticker meta', (tester) async {
        const sticker = StickerData.asset(
          'assets/stickers/test.png',
          description: 'Test sticker',
          tags: ['test'],
          packData: StickerPackData.fallback,
        );
        final stickerItem = TimelineOverlayItem(
          id: 'sticker-1',
          type: TimelineOverlayType.layer,
          startTime: Duration.zero,
          endTime: const Duration(seconds: 3),
          label: 'Fallback Label',
          layer: buildStickerLayer(meta: sticker.toJson()),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TimelineOverlayItemTile(
                item: stickerItem,
                width: 120,
                height: 40,
                color: Colors.blue,
              ),
            ),
          ),
        );

        expect(find.text(sticker.layerName), findsOneWidget);
        expect(find.text('Fallback Label'), findsNothing);
      });

      testWidgets(
        'falls back to item.label when WidgetLayer meta is malformed',
        (tester) async {
          final stickerItem = TimelineOverlayItem(
            id: 'sticker-2',
            type: TimelineOverlayType.layer,
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
            label: 'Fallback Label',
            layer: buildStickerLayer(
              meta: {'not': 'sticker', 'shaped': true},
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: TimelineOverlayItemTile(
                  item: stickerItem,
                  width: 120,
                  height: 40,
                  color: Colors.blue,
                ),
              ),
            ),
          );

          expect(find.text('Fallback Label'), findsOneWidget);
        },
      );
    });
  });
}
