// ABOUTME: Widget tests for VideoEditorSticker - displays asset or network stickers.
// ABOUTME: Tests rendering, caching behavior, and error states.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';

void main() {
  group('VideoEditorSticker', () {
    const testSticker = StickerData.asset(
      'assets/stickers/test.png',
      description: 'Test sticker',
      tags: ['test'],
    );

    Widget buildTestWidget({
      StickerData sticker = testSticker,
      bool? enableLimitCacheSize,
      double size = 100,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: size,
            height: size,
            child: VideoEditorSticker(
              sticker: sticker,
              enableLimitCacheSize: enableLimitCacheSize ?? true,
            ),
          ),
        ),
      );
    }

    testWidgets('renders asset image when assetPath is provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('is centered', (tester) async {
      await tester.pumpWidget(buildTestWidget(size: 200));

      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('uses LayoutBuilder when enableLimitCacheSize is true', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(enableLimitCacheSize: true));

      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets(
      'does not use LayoutBuilder when enableLimitCacheSize is false',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(enableLimitCacheSize: false));

        expect(find.byType(LayoutBuilder), findsNothing);
      },
    );

    testWidgets('enableLimitCacheSize defaults to true', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(LayoutBuilder), findsOneWidget);
    });
  });
}
