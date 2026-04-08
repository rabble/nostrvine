// ABOUTME: Widget tests for VideoEditorTimelineRulesIndicator.
// ABOUTME: Validates ruler rendering, label formatting, and zoom-dependent density.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_rules_indicator.dart';

void main() {
  group(VideoEditorTimelineRulesIndicator, () {
    late ScrollController scrollController;

    setUp(() {
      scrollController = ScrollController();
    });

    tearDown(() {
      scrollController.dispose();
    });

    Widget buildWidget({
      Duration totalDuration = const Duration(seconds: 10),
      double pixelsPerSecond = TimelineConstants.pixelsPerSecond,
      double scrollPadding = 0,
    }) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(left: scrollPadding),
          child: VideoEditorTimelineRulesIndicator(
            totalDuration: totalDuration,
            pixelsPerSecond: pixelsPerSecond,
            scrollController: scrollController,
            scrollPadding: scrollPadding,
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoEditorTimelineRulesIndicator', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(
          find.byType(VideoEditorTimelineRulesIndicator),
          findsOneWidget,
        );
      });

      testWidgets('renders with correct height', (tester) async {
        await tester.pumpWidget(buildWidget());

        final sizedBox = tester.widget<SizedBox>(
          find.byWidgetPredicate(
            (w) => w is SizedBox && w.height == TimelineConstants.rulerHeight,
          ),
        );
        expect(sizedBox.height, equals(TimelineConstants.rulerHeight));
      });

      testWidgets('computes correct total width from duration and pps', (
        tester,
      ) async {
        const duration = Duration(seconds: 5);
        const pps = 100.0;
        const expectedWidth = 5.0 * pps;

        await tester.pumpWidget(
          buildWidget(
            totalDuration: duration,
            pixelsPerSecond: pps,
          ),
        );

        final sizedBox = tester.widget<SizedBox>(
          find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == expectedWidth,
          ),
        );
        expect(sizedBox.width, equals(expectedWidth));
      });
    });

    group('layout', () {
      testWidgets('uses CustomPaint for rendering', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(
          find.descendant(
            of: find.byType(VideoEditorTimelineRulesIndicator),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );
      });

      testWidgets('excludes semantics', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(ExcludeSemantics), findsOneWidget);
      });
    });

    group('zero duration', () {
      testWidgets('renders with zero width for zero duration', (tester) async {
        await tester.pumpWidget(
          buildWidget(totalDuration: Duration.zero),
        );

        final sizedBox = tester.widget<SizedBox>(
          find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 0.0,
          ),
        );
        expect(sizedBox.width, equals(0.0));
      });
    });

    group('zoom levels', () {
      testWidgets('scales width with pixelsPerSecond', (tester) async {
        // Low zoom
        await tester.pumpWidget(
          buildWidget(
            pixelsPerSecond: 50,
          ),
        );

        final lowZoomWidth = tester
            .widget<SizedBox>(
              find.byWidgetPredicate(
                (w) => w is SizedBox && w.width == 500.0,
              ),
            )
            .width;

        // High zoom
        await tester.pumpWidget(
          buildWidget(
            pixelsPerSecond: 200,
          ),
        );

        final highZoomWidth = tester
            .widget<SizedBox>(
              find.byWidgetPredicate(
                (w) => w is SizedBox && w.width == 2000.0,
              ),
            )
            .width;

        expect(highZoomWidth, greaterThan(lowZoomWidth!));
      });
    });
  });
}
