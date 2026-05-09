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
  });
}
