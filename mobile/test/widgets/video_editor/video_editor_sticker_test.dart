// ABOUTME: Widget tests for VideoEditorSticker - displays SVG asset or network stickers.
// ABOUTME: Tests rendering paths for local SVG assets vs network images.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';

void main() {
  group(VideoEditorSticker, () {
    const assetSticker = StickerData.asset(
      'assets/stickers/test.svg',
      description: 'Test sticker',
      tags: ['test'],
    );

    const networkSticker = StickerData.network(
      'https://example.com/sticker.png',
      description: 'Network sticker',
      tags: ['network'],
    );

    Widget buildTestWidget({
      StickerData sticker = assetSticker,
      bool? enableLimitCacheSize,
      double size = 100,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

    testWidgets('renders SvgPicture for asset stickers', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('skips LayoutBuilder for asset stickers', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(LayoutBuilder), findsNothing);
    });

    testWidgets('uses LayoutBuilder for network stickers with cache sizing', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(sticker: networkSticker, enableLimitCacheSize: true),
      );

      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets(
      'does not use LayoutBuilder for network stickers without cache sizing',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(sticker: networkSticker, enableLimitCacheSize: false),
        );

        expect(find.byType(LayoutBuilder), findsNothing);
      },
    );
  });
}
