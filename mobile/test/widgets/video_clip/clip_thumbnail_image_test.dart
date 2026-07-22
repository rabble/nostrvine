// ABOUTME: Regression tests for #5796 — a missing clip thumbnail/ghost file
// ABOUTME: must render a placeholder instead of crashing with
// ABOUTME: PathNotFoundException from FileImage._loadAsync.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';

void main() {
  group(ClipThumbnailImage, () {
    Future<Image> pumpAndGetImage(
      WidgetTester tester, {
      Widget? placeholder,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClipThumbnailImage(
              path: '/nonexistent/container/thumbnail_123.jpg',
              placeholder: placeholder,
            ),
          ),
        ),
      );
      return tester.widget<Image>(find.byType(Image));
    }

    testWidgets('wires an errorBuilder so a missing file cannot crash', (
      tester,
    ) async {
      final image = await pumpAndGetImage(tester);

      expect(
        image.errorBuilder,
        isNotNull,
        reason:
            'without an errorBuilder a missing thumbnail file surfaces '
            'PathNotFoundException as a fatal crash (#5796)',
      );
    });

    testWidgets('errorBuilder renders the neutral placeholder', (
      tester,
    ) async {
      final image = await pumpAndGetImage(tester);

      final fallback = image.errorBuilder!(
        tester.element(find.byType(Image)),
        Exception('PathNotFoundException'),
        StackTrace.current,
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: fallback)));

      expect(find.byType(DivineIcon), findsOneWidget);
      expect(find.byType(ColoredBox), findsWidgets);
    });

    testWidgets('errorBuilder renders a custom placeholder when given', (
      tester,
    ) async {
      const marker = Key('custom-placeholder');
      final image = await pumpAndGetImage(
        tester,
        placeholder: const SizedBox.shrink(key: marker),
      );

      final fallback = image.errorBuilder!(
        tester.element(find.byType(Image)),
        Exception('PathNotFoundException'),
        StackTrace.current,
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: fallback)));

      expect(find.byKey(marker), findsOneWidget);
      expect(find.byType(DivineIcon), findsNothing);
    });
  });
}
