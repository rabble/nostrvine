// ABOUTME: Widget tests for ScrollToHideMixin (scroll-linked header offset)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FixedScrollMetrics _fixedMetrics({
  double pixels = 80,
  double maxScrollExtent = 5000,
}) {
  return FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: maxScrollExtent,
    pixels: pixels,
    viewportDimension: 600,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 1,
  );
}

/// Test harness using [ScrollToHideMixin].
class ScrollToHideHarness extends StatefulWidget {
  const ScrollToHideHarness({
    required this.scrollController,
    this.headerSizedBoxHeight = 56,
    this.attachHeader = true,
    this.measureTwicePerBuild = false,
    super.key,
  });

  final ScrollController scrollController;
  final double headerSizedBoxHeight;
  final bool attachHeader;
  final bool measureTwicePerBuild;

  @override
  ScrollToHideHarnessState createState() => ScrollToHideHarnessState();
}

class ScrollToHideHarnessState extends State<ScrollToHideHarness>
    with ScrollToHideMixin {
  @override
  Widget build(BuildContext context) {
    measureHeaderHeight();
    if (widget.measureTwicePerBuild) {
      measureHeaderHeight();
    }
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: handleScrollNotification,
              child: ListView(
                controller: widget.scrollController,
                children: const [
                  SizedBox(height: 4000),
                ],
              ),
            ),
            if (widget.attachHeader)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SizedBox(
                  key: headerKey,
                  height: widget.headerSizedBoxHeight,
                  child: const ColoredBox(color: Color(0xFFFF0000)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _dispatchScrollUpdate(
  WidgetTester tester, {
  required double pixels,
  required double scrollDelta,
}) {
  final ctx = tester.element(find.byType(Scrollable));
  ScrollUpdateNotification(
    metrics: _fixedMetrics(pixels: pixels),
    context: ctx,
    scrollDelta: scrollDelta,
  ).dispatch(ctx);
}

void main() {
  group('ScrollToHideMixin', () {
    testWidgets('measureHeaderHeight captures header size after layout', (
      tester,
    ) async {
      final controller = ScrollController();
      final key = GlobalKey<ScrollToHideHarnessState>();
      await tester.pumpWidget(
        ScrollToHideHarness(
          key: key,
          scrollController: controller,
          headerSizedBoxHeight: 72,
        ),
      );
      await tester.pumpAndSettle();

      expect(key.currentState!.headerHeight, 72);
      expect(key.currentState!.headerOffset, 0);

      controller.dispose();
    });

    testWidgets(
      'measureHeaderHeight skips when layout reports no render box yet',
      (tester) async {
        final controller = ScrollController();
        final key = GlobalKey<ScrollToHideHarnessState>();
        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
            attachHeader: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(key.currentState!.headerHeight, 0);

        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
            headerSizedBoxHeight: 40,
          ),
        );
        await tester.pumpAndSettle();

        expect(key.currentState!.headerHeight, 40);

        controller.dispose();
      },
    );

    testWidgets(
      'measureTwicePerBuild second call is ignored until next frame',
      (tester) async {
        final controller = ScrollController();
        final key = GlobalKey<ScrollToHideHarnessState>();
        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
            measureTwicePerBuild: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(key.currentState!.headerHeight, 56);

        controller.dispose();
      },
    );

    testWidgets(
      'measureHeaderHeight post-frame callback skips when unmounted',
      (tester) async {
        final controller = ScrollController();
        await tester.pumpWidget(
          ScrollToHideHarness(scrollController: controller),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        controller.dispose();
      },
    );

    testWidgets(
      'measureHeaderHeight does not setState when height is unchanged',
      (tester) async {
        final controller = ScrollController();
        final key = GlobalKey<ScrollToHideHarnessState>();
        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
          ),
        );
        await tester.pumpAndSettle();

        expect(key.currentState!.headerHeight, 56);

        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
          ),
        );
        await tester.pumpAndSettle();

        expect(key.currentState!.headerHeight, 56);

        controller.dispose();
      },
    );

    testWidgets(
      'handleScrollNotification ignores ScrollUpdate when pixels <= 0',
      (tester) async {
        final controller = ScrollController();
        final key = GlobalKey<ScrollToHideHarnessState>();
        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
          ),
        );
        await tester.pumpAndSettle();

        final ctx = tester.element(find.byType(Scrollable));
        ScrollUpdateNotification(
          metrics: _fixedMetrics(pixels: 0),
          context: ctx,
          scrollDelta: 20,
        ).dispatch(ctx);
        await tester.pump();

        expect(key.currentState!.headerOffset, 0);

        controller.dispose();
      },
    );

    testWidgets(
      'scrolling down hides header proportionally when pixels > 0',
      (tester) async {
        final controller = ScrollController();
        final key = GlobalKey<ScrollToHideHarnessState>();
        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
          ),
        );
        await tester.pumpAndSettle();

        _dispatchScrollUpdate(tester, pixels: 120, scrollDelta: 12);
        await tester.pump();

        expect(key.currentState!.headerOffset, lessThan(0));
        expect(key.currentState!.headerFullyHidden, isFalse);

        controller.dispose();
      },
    );

    testWidgets(
      'scrollDelta null is treated as zero (no offset change)',
      (tester) async {
        final controller = ScrollController();
        final key = GlobalKey<ScrollToHideHarnessState>();
        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
          ),
        );
        await tester.pumpAndSettle();

        final ctx = tester.element(find.byType(Scrollable));
        ScrollUpdateNotification(
          metrics: _fixedMetrics(),
          context: ctx,
        ).dispatch(ctx);
        await tester.pump();

        expect(key.currentState!.headerOffset, 0);

        controller.dispose();
      },
    );

    testWidgets(
      'when header fully hidden, scrolling up snaps header visible',
      (tester) async {
        final controller = ScrollController();
        final key = GlobalKey<ScrollToHideHarnessState>();
        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
          ),
        );
        await tester.pumpAndSettle();

        final h = key.currentState!.headerHeight;

        _dispatchScrollUpdate(tester, pixels: 200, scrollDelta: h + 4);
        await tester.pump();

        expect(
          key.currentState!.headerOffset <= -h + 0.001,
          isTrue,
          reason: 'header should be fully hidden',
        );

        _dispatchScrollUpdate(tester, pixels: 200, scrollDelta: -8);
        await tester.pump();

        expect(key.currentState!.headerOffset, 0);
        expect(key.currentState!.headerFullyHidden, isTrue);

        controller.dispose();
      },
    );

    testWidgets(
      'scrolling up while header partly visible adjusts offset',
      (tester) async {
        final controller = ScrollController();
        final key = GlobalKey<ScrollToHideHarnessState>();
        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
          ),
        );
        await tester.pumpAndSettle();

        _dispatchScrollUpdate(tester, pixels: 150, scrollDelta: 20);
        await tester.pump();
        final mid = key.currentState!.headerOffset;
        expect(mid, lessThan(0));
        expect(mid, greaterThan(-key.currentState!.headerHeight));

        _dispatchScrollUpdate(tester, pixels: 150, scrollDelta: -10);
        await tester.pump();

        expect(
          key.currentState!.headerOffset,
          greaterThan(mid),
        );

        controller.dispose();
      },
    );

    testWidgets(
      'non-scroll-update notifications are ignored by mixin logic',
      (tester) async {
        final controller = ScrollController();
        final key = GlobalKey<ScrollToHideHarnessState>();
        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
          ),
        );
        await tester.pumpAndSettle();

        final ctx = tester.element(find.byType(Scrollable));
        ScrollStartNotification(
          metrics: _fixedMetrics(pixels: 40),
          context: ctx,
        ).dispatch(ctx);
        await tester.pump();

        expect(key.currentState!.headerOffset, 0);

        controller.dispose();
      },
    );

    testWidgets(
      'when measured header height shrinks, offset clamps to new bounds',
      (tester) async {
        final controller = ScrollController();
        final key = GlobalKey<ScrollToHideHarnessState>();
        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
            headerSizedBoxHeight: 100,
          ),
        );
        await tester.pumpAndSettle();

        _dispatchScrollUpdate(tester, pixels: 300, scrollDelta: 90);
        await tester.pump();

        expect(key.currentState!.headerOffset, closeTo(-90, 0.01));

        await tester.pumpWidget(
          ScrollToHideHarness(
            key: key,
            scrollController: controller,
          ),
        );
        await tester.pumpAndSettle();

        expect(key.currentState!.headerHeight, 56);
        expect(key.currentState!.headerOffset, greaterThanOrEqualTo(-56));
        expect(key.currentState!.headerOffset, lessThanOrEqualTo(0));

        controller.dispose();
      },
    );
  });
}
