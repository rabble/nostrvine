// ABOUTME: Unit tests for VideoEditorTimelineBody.
// ABOUTME: Verifies constructor wiring for core timeline body dependencies.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strips.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_body.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

DivineVideoClip _createClip({
  required String id,
  required Duration duration,
  double? playbackSpeed,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('video.mp4'),
    duration: duration,
    recordedAt: DateTime(2025),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    playbackSpeed: playbackSpeed,
  );
}

void main() {
  group(VideoEditorTimelineBody, () {
    late _MockVideoEditorMainBloc mainBloc;
    late _MockTimelineOverlayBloc overlayBloc;

    setUp(() {
      mainBloc = _MockVideoEditorMainBloc();
      overlayBloc = _MockTimelineOverlayBloc();

      when(
        () => mainBloc.stream,
      ).thenAnswer((_) => const Stream<VideoEditorMainState>.empty());
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
    });

    Future<void> pumpBody(
      WidgetTester tester, {
      bool isReordering = false,
      Duration totalDuration = const Duration(seconds: 12),
      List<DivineVideoClip> clips = const <DivineVideoClip>[],
    }) async {
      when(
        () => mainBloc.state,
      ).thenReturn(VideoEditorMainState(isReordering: isReordering));

      final scrollController = ScrollController();
      final overlayStripsScrollController = ScrollController();
      final playhead = ValueNotifier(Duration.zero);
      addTearDown(scrollController.dispose);
      addTearDown(overlayStripsScrollController.dispose);
      addTearDown(playhead.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
              BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
            ],
            child: SizedBox(
              height: 120000,
              child: VideoEditorTimelineBody(
                totalDuration: totalDuration,
                pixelsPerSecond: 80,
                scrollController: scrollController,
                overlayStripsScrollController: overlayStripsScrollController,
                scrollPadding: 16,
                clips: clips,
                totalWidth: 960,
                isInteracting: false,
                onReorder: (_) {},
                onReorderChanged: (_) {},
                playheadPosition: playhead,
              ),
            ),
          ),
        ),
      );
    }

    test('stores constructor parameters', () {
      final scrollController = ScrollController();
      final overlayStripsScrollController = ScrollController();
      final playhead = ValueNotifier(Duration.zero);
      final clips = <DivineVideoClip>[];

      final widget = VideoEditorTimelineBody(
        totalDuration: const Duration(seconds: 12),
        pixelsPerSecond: 80,
        scrollController: scrollController,
        overlayStripsScrollController: overlayStripsScrollController,
        scrollPadding: 16,
        clips: clips,
        totalWidth: 960,
        isInteracting: false,
        onReorder: (_) {},
        onReorderChanged: (_) {},
        playheadPosition: playhead,
      );

      expect(widget.totalDuration, equals(const Duration(seconds: 12)));
      expect(widget.pixelsPerSecond, equals(80));
      expect(widget.scrollController, same(scrollController));
      expect(
        widget.overlayStripsScrollController,
        same(overlayStripsScrollController),
      );
      expect(widget.scrollPadding, equals(16));
      expect(widget.clips, same(clips));
      expect(widget.totalWidth, equals(960));
      expect(widget.playheadPosition, same(playhead));

      scrollController.dispose();
      overlayStripsScrollController.dispose();
      playhead.dispose();
    });

    testWidgets('shows outside-area overlays when not reordering', (
      tester,
    ) async {
      await pumpBody(tester);

      final dimOverlayFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color ==
                VineTheme.surfaceContainerHigh.withValues(alpha: 0.3),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_TimelineOutsideAreaPainter',
        ),
        findsOneWidget,
      );
      expect(dimOverlayFinder, findsOneWidget);
    });

    testWidgets('hides outside-area overlays when reordering', (tester) async {
      await pumpBody(tester, isReordering: true);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_TimelineOutsideAreaPainter',
        ),
        findsNothing,
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox &&
              widget.color ==
                  VineTheme.surfaceContainerHigh.withValues(alpha: 0.3),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'hides outside-area overlays when duration does not exceed max',
      (tester) async {
        await pumpBody(tester, totalDuration: VideoEditorConstants.maxDuration);

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.painter.runtimeType.toString() ==
                    '_TimelineOutsideAreaPainter',
          ),
          findsNothing,
        );

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox &&
                widget.color ==
                    VineTheme.surfaceContainerHigh.withValues(alpha: 0.3),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('extends overlay by half screen width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpBody(tester);

      final expectedLeft =
          VideoEditorConstants.maxDuration.inMilliseconds / 1000 * 80;
      const expectedRight = -500.0;

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Positioned &&
              widget.top == 0 &&
              widget.bottom == 0 &&
              widget.left == expectedLeft &&
              widget.right == expectedRight,
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('renders dim overlay with updated alpha', (tester) async {
      await pumpBody(tester);

      final expectedColor = VineTheme.surfaceContainerHigh.withValues(
        alpha: 0.3,
      );
      final unexpectedColor = VineTheme.surfaceContainerHigh.withValues(
        alpha: 0.6,
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == expectedColor,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == unexpectedColor,
        ),
        findsNothing,
      );
    });

    testWidgets('uses playback-duration clip edges for overlay snap points', (
      tester,
    ) async {
      await pumpBody(
        tester,
        clips: [
          _createClip(
            id: 'slow',
            duration: const Duration(seconds: 4),
            playbackSpeed: 0.5,
          ),
          _createClip(
            id: 'fast',
            duration: const Duration(seconds: 3),
            playbackSpeed: 2.0,
          ),
        ],
      );

      final overlayStrips = tester.widget<TimelineOverlayStrips>(
        find.byType(TimelineOverlayStrips),
      );
      expect(overlayStrips.clipEdgesMs, equals([0, 8000, 9500]));
    });
  });
}
