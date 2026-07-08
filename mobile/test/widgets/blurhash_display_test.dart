import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/blurhash_display.dart';

void main() {
  group(BlurhashDisplay, () {
    // Real blurhash already used elsewhere in the test suite
    // (test/goldens/widgets/video_thumbnail_golden_test.dart).
    const validBlurhash = 'L5H2EC=PM+yV0g-mq.wG9c010J}I';

    testWidgets('keeps decode future stable across parent rebuilds', (
      tester,
    ) async {
      late StateSetter rebuildParent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuildParent = setState;
                // Non-const so each parent rebuild produces a new
                // BlurhashDisplay instance and forces its build() to run —
                // mirroring how the profile grid hosts the widget.
                // ignore: prefer_const_constructors
                return BlurhashDisplay(blurhash: validBlurhash);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final futureBuilderFinder = find.byType(FutureBuilder<ui.Image?>);
      expect(futureBuilderFinder, findsOneWidget);
      final firstFuture = tester
          .widget<FutureBuilder<ui.Image?>>(futureBuilderFinder)
          .future;
      expect(firstFuture, isNotNull);

      rebuildParent(() {});
      await tester.pump();

      final secondFuture = tester
          .widget<FutureBuilder<ui.Image?>>(futureBuilderFinder)
          .future;
      expect(secondFuture, same(firstFuture));
    });

    testWidgets('applies opacity to the gradient fallback colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BlurhashDisplay(
              blurhash: validBlurhash,
              width: 100,
              height: 100,
              opacity: 0.5,
            ),
          ),
        ),
      );
      // First frame after decode: the image future is still pending, so the
      // gradient fallback renders — its colors must carry the alpha instead
      // of a saveLayer-costing Opacity widget.
      final container = tester.widget<Container>(find.byType(Container));
      final gradient =
          (container.decoration! as BoxDecoration).gradient! as LinearGradient;
      for (final color in gradient.colors) {
        expect(color.a, lessThanOrEqualTo(0.5 + 0.01));
      }
      expect(gradient.colors.first.a, closeTo(0.5, 0.01));
      expect(find.byType(Opacity), findsNothing);
    });
  });
}
