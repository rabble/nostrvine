// ABOUTME: Regression coverage for the sticker export round-trip
// ABOUTME: shipped in PR #3666. Builds a [WidgetLayer] the way
// ABOUTME: VideoEditorScreen._addStickers does, exports it through the same
// ABOUTME: state-history map shape that pro_image_editor's ExportStateHistory
// ABOUTME: produces, then re-imports it through ImportStateHistory.fromMap
// ABOUTME: with the production widgetLoader — the exact path
// ABOUTME: VideoEditorCanvas wires into ProImageEditorConfigs.stateHistory.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show StickerData, StickerPackData;
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show
        ImportEditorConfigs,
        ImportStateHistory,
        WidgetLayer,
        WidgetLayerExportConfigs;

void main() {
  group('sticker export round-trip', () {
    /// Mirrors how `VideoEditorScreen._addStickers` builds the layer that
    /// the editor later serializes via `editor.exportStateHistory()`.
    WidgetLayer buildAddedStickerLayer(
      StickerData sticker, {
      Offset offset = Offset.zero,
      double rotation = 0,
      double scale = 1,
    }) {
      return WidgetLayer(
        width: 120,
        widget: VideoEditorSticker(
          sticker: sticker,
          enableLimitCacheSize: false,
        ),
        meta: sticker.toJson(),
        exportConfigs: WidgetLayerExportConfigs(
          id: 'sticker-${sticker.description}',
          meta: sticker.toJson(),
        ),
        offset: offset,
        rotation: rotation,
        scale: scale,
      );
    }

    /// Wraps a layer map in the same shape `ExportStateHistory.toMap`
    /// produces. This is the JSON we save into
    /// `DivineVideoDraft.editorStateHistory` after the user adds a sticker
    /// and the editor exports its history.
    Map<String, dynamic> exportedHistoryFor(WidgetLayer layer) {
      return {
        'position': 0,
        'history': [
          {
            'layers': [layer.toMap()],
          },
        ],
      };
    }

    /// Re-imports the exported history through the same factory that
    /// `VideoEditorCanvas` passes to
    /// `ProImageEditorConfigs.stateHistory.initStateHistory`, using the
    /// production sticker `widgetLoader`. Returns the rebuilt layers from
    /// the first history entry.
    List<Object?> reopenLayers(Map<String, dynamic> exportedHistory) {
      final imported = ImportStateHistory.fromMap(
        exportedHistory,
        configs: const ImportEditorConfigs(
          widgetLoader: videoEditorStickerWidgetLoader,
        ),
      );
      expect(imported.stateHistory, hasLength(1));
      return imported.stateHistory.first.layers;
    }

    test(
      'network sticker added → exported → reopened as VideoEditorSticker',
      () {
        const sticker = StickerData.network(
          'https://stickers.example.com/heart.png',
          description: 'Red heart',
          tags: ['heart', 'love'],
          packData: StickerPackData(
            packId: 'reactions',
            packName: 'Reactions',
          ),
        );

        final layers = reopenLayers(
          exportedHistoryFor(buildAddedStickerLayer(sticker)),
        );

        expect(layers, hasLength(1));
        final restored = layers.single;
        expect(restored, isA<WidgetLayer>());
        final widgetLayer = restored! as WidgetLayer;
        expect(widgetLayer.exportConfigs.id, equals('sticker-Red heart'));
        expect(widgetLayer.exportConfigs.meta, equals(sticker.toJson()));

        expect(widgetLayer.widget, isA<VideoEditorSticker>());
        expect(
          (widgetLayer.widget as VideoEditorSticker).sticker.props,
          equals(sticker.props),
        );
      },
    );

    test('asset sticker added → exported → reopened as VideoEditorSticker', () {
      const sticker = StickerData.asset(
        'assets/stickers/star.svg',
        description: 'Gold star',
        tags: ['star', 'rating'],
        packData: StickerPackData.fallback,
      );

      final layers = reopenLayers(
        exportedHistoryFor(buildAddedStickerLayer(sticker)),
      );

      expect(layers, hasLength(1));
      final widgetLayer = layers.single! as WidgetLayer;
      expect(widgetLayer.widget, isA<VideoEditorSticker>());
      expect(
        (widgetLayer.widget as VideoEditorSticker).sticker.props,
        equals(sticker.props),
      );
    });

    test(
      'transform fields (offset, rotation, scale, width) survive the '
      'round-trip',
      () {
        const sticker = StickerData.asset(
          'assets/stickers/smile.svg',
          description: 'Smile',
          tags: ['smile'],
          packData: StickerPackData.fallback,
        );

        final layers = reopenLayers(
          exportedHistoryFor(
            buildAddedStickerLayer(
              sticker,
              offset: const Offset(42, 84),
              rotation: 1.25,
              scale: 1.75,
            ),
          ),
        );

        final widgetLayer = layers.single! as WidgetLayer;
        expect(widgetLayer.offset, equals(const Offset(42, 84)));
        expect(widgetLayer.rotation, closeTo(1.25, 1e-6));
        expect(widgetLayer.scale, closeTo(1.75, 1e-6));
        expect(widgetLayer.width, equals(120));
      },
    );

    test(
      'legacy drafts that serialized stickers as type:"sticker" still '
      'rehydrate via the production widgetLoader',
      () {
        const sticker = StickerData.asset(
          'assets/stickers/legacy.svg',
          description: 'Legacy sticker',
          tags: ['legacy'],
          packData: StickerPackData.fallback,
        );

        final layerMap = buildAddedStickerLayer(sticker).toMap()
          ..['type'] = 'sticker';
        final exported = {
          'position': 0,
          'history': [
            {
              'layers': [layerMap],
            },
          ],
        };

        final layers = reopenLayers(exported);

        expect(layers.single, isA<WidgetLayer>());
        expect(
          ((layers.single! as WidgetLayer).widget as VideoEditorSticker)
              .sticker
              .props,
          equals(sticker.props),
        );
      },
    );

    test(
      'widgetLoader returns SizedBox.shrink when meta is missing '
      '(legacy widget layers without sticker payload)',
      () {
        final widget = videoEditorStickerWidgetLoader('any-id');

        expect(widget, isA<SizedBox>());
      },
    );
  });
}
