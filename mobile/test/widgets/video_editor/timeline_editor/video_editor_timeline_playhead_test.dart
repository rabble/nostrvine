// ABOUTME: Widget tests for VideoEditorTimelinePlayhead.
// ABOUTME: Validates visibility animation and layout properties.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_playhead.dart';

void main() {
  group(VideoEditorTimelinePlayhead, () {
    group('renders', () {
      testWidgets('renders $VideoEditorTimelinePlayhead when visible', (
        tester,
      ) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: VideoEditorTimelinePlayhead(isVisible: true),
          ),
        );

        expect(
          find.byType(VideoEditorTimelinePlayhead),
          findsOneWidget,
        );
      });

      testWidgets('renders playhead line with correct width', (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 400,
              height: 200,
              child: VideoEditorTimelinePlayhead(isVisible: true),
            ),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(
          find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == TimelineConstants.playheadWidth,
          ),
        );
        expect(sizedBox.width, equals(TimelineConstants.playheadWidth));
      });

      testWidgets('renders with $VineTheme onSurface color', (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 400,
              height: 200,
              child: VideoEditorTimelinePlayhead(isVisible: true),
            ),
          ),
        );

        final coloredBox = tester.widget<ColoredBox>(
          find.byType(ColoredBox),
        );
        expect(coloredBox.color, equals(VineTheme.onSurface));
      });
    });

    group('visibility', () {
      testWidgets('has full opacity when isVisible is true', (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: VideoEditorTimelinePlayhead(isVisible: true),
          ),
        );

        final animated = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animated.opacity, equals(1.0));
      });

      testWidgets('has zero opacity when isVisible is false', (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: VideoEditorTimelinePlayhead(isVisible: false),
          ),
        );

        final animated = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animated.opacity, equals(0.0));
      });

      testWidgets('animates opacity over 200ms', (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: VideoEditorTimelinePlayhead(isVisible: true),
          ),
        );

        final animated = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(
          animated.duration,
          equals(const Duration(milliseconds: 200)),
        );
      });
    });

    group('interaction', () {
      testWidgets('ignores pointer events', (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: VideoEditorTimelinePlayhead(isVisible: true),
          ),
        );

        expect(find.byType(IgnorePointer), findsOneWidget);
      });
    });
  });
}
