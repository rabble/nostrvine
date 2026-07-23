// ABOUTME: Regression tests for #5796 — a missing clip thumbnail/ghost file
// ABOUTME: must render a placeholder instead of surfacing PathNotFoundException.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';

void main() {
  group(ClipThumbnailImage, () {
    Future<void> pumpMissingThumbnail(
      WidgetTester tester, {
      Widget? placeholder,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 120,
              child: ClipThumbnailImage(
                path: '/nonexistent/container/thumbnail_123.jpg',
                placeholder: placeholder,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    testWidgets('renders the neutral placeholder for a missing file', (
      tester,
    ) async {
      await pumpMissingThumbnail(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(DivineIcon), findsOneWidget);
      expect(find.byType(ColoredBox), findsWidgets);
    });

    testWidgets('renders a custom placeholder for a missing file', (
      tester,
    ) async {
      const marker = Key('custom-placeholder');

      await pumpMissingThumbnail(
        tester,
        placeholder: const SizedBox.shrink(key: marker),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(marker), findsOneWidget);
      expect(find.byType(DivineIcon), findsNothing);
    });
  });
}
