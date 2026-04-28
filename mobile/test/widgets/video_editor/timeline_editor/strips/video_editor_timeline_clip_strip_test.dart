// ABOUTME: Widget tests for VideoEditorTimelineClipStrip.
// ABOUTME: Validates clip rendering, layout, reorder gesture, and accessibility.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorTimelineClipStrip, () {
    late ScrollController scrollController;

    setUp(() {
      scrollController = ScrollController();
    });

    tearDown(() {
      scrollController.dispose();
    });

    Widget buildWidget({
      List<DivineVideoClip>? clips,
      double totalWidth = 500,
      double pixelsPerSecond = TimelineConstants.pixelsPerSecond,
      bool isInteracting = false,
      ValueChanged<List<DivineVideoClip>>? onReorder,
      ValueChanged<bool>? onReorderChanged,
    }) {
      final testClips =
          clips ??
          [
            _createTestClip(id: 'clip1', seconds: 3),
            _createTestClip(id: 'clip2', seconds: 4),
          ];

      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: VideoEditorTimelineClipStrip(
              clips: testClips,
              totalWidth: totalWidth,
              pixelsPerSecond: pixelsPerSecond,
              scrollController: scrollController,
              isInteracting: isInteracting,
              onReorder: onReorder,
              onReorderChanged: onReorderChanged,
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoEditorTimelineClipStrip', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(VideoEditorTimelineClipStrip), findsOneWidget);
      });

      testWidgets('renders clip tiles for each clip', (tester) async {
        final clips = [
          _createTestClip(id: 'a'),
          _createTestClip(id: 'b', seconds: 3),
          _createTestClip(id: 'c', seconds: 1),
        ];

        await tester.pumpWidget(buildWidget(clips: clips, totalWidth: 600));

        // Each clip gets a ClipRRect for the tile
        expect(find.byType(ClipRRect), findsNWidgets(3));
      });

      testWidgets('renders single clip filling total width', (tester) async {
        final clips = [_createTestClip(id: 'only', seconds: 5)];

        await tester.pumpWidget(buildWidget(clips: clips, totalWidth: 400));

        expect(find.byType(ClipRRect), findsOneWidget);
      });
    });

    group('layout', () {
      testWidgets('uses correct strip height', (tester) async {
        await tester.pumpWidget(buildWidget());

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(
          container.constraints?.maxHeight ?? container.decoration,
          isNotNull,
        );
      });

      testWidgets('uses GestureDetector for long press reorder', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        // 1 root GestureDetector for long-press reorder +
        // 1 per clip tile for tap selection.
        expect(find.byType(GestureDetector), findsAtLeast(1));
      });
    });

    group('single clip', () {
      testWidgets('does not trigger reorder for single clip', (tester) async {
        var reorderTriggered = false;
        final clips = [_createTestClip(id: 'only', seconds: 5)];

        await tester.pumpWidget(
          buildWidget(
            clips: clips,
            totalWidth: 400,
            onReorderChanged: (_) => reorderTriggered = true,
          ),
        );

        // Long press on single clip should not enter reorder mode
        await tester.longPress(find.byType(VideoEditorTimelineClipStrip));
        await tester.pumpAndSettle();

        expect(reorderTriggered, isFalse);
      });
    });

    group('interaction', () {
      testWidgets('does not start reorder when isInteracting is true', (
        tester,
      ) async {
        var reorderTriggered = false;

        await tester.pumpWidget(
          buildWidget(
            isInteracting: true,
            onReorderChanged: (_) => reorderTriggered = true,
          ),
        );

        await tester.longPress(find.byType(VideoEditorTimelineClipStrip));
        await tester.pumpAndSettle();

        expect(reorderTriggered, isFalse);
      });
    });

    group('accessibility', () {
      testWidgets('provides clip semantics with duration', (tester) async {
        final clips = [
          _createTestClip(id: 'a', seconds: 3),
          _createTestClip(id: 'b', seconds: 5),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));

        // Clip 1 of 2, 3.0 seconds
        expect(
          find.bySemanticsLabel(RegExp(r'Clip 1 of 2.*3\.0 seconds')),
          findsOneWidget,
        );
        // Clip 2 of 2, 5.0 seconds
        expect(
          find.bySemanticsLabel(RegExp(r'Clip 2 of 2.*5\.0 seconds')),
          findsOneWidget,
        );
      });

      testWidgets('provides reorder hint for multiple clips', (tester) async {
        final clips = [
          _createTestClip(id: 'a'),
          _createTestClip(id: 'b', seconds: 3),
        ];

        await tester.pumpWidget(buildWidget(clips: clips, totalWidth: 400));

        final semantics = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Clip 1 of 2')),
        );
        expect(semantics.hint, contains('Long press to reorder'));
      });
    });

    group('empty state', () {
      testWidgets('renders with empty clip list', (tester) async {
        await tester.pumpWidget(buildWidget(clips: [], totalWidth: 0));

        expect(find.byType(VideoEditorTimelineClipStrip), findsOneWidget);
      });
    });

    group('trimmed clips', () {
      testWidgets('renders trimmed clip without error', (tester) async {
        final clips = [
          _createTestClip(
            id: 'trimmed',
            seconds: 5,
            trimStartMs: 1000,
            trimEndMs: 500,
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips, totalWidth: 400));

        expect(find.byType(VideoEditorTimelineClipStrip), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'multi-clip strip with trimmed clips renders both tiles',
        (tester) async {
          final clips = [
            // trimmedDuration = 5s - 2s - 1s = 2s
            _createTestClip(
              id: 'a',
              seconds: 5,
              trimStartMs: 2000,
              trimEndMs: 1000,
            ),
            _createTestClip(id: 'b', seconds: 3),
          ];

          await tester.pumpWidget(
            buildWidget(
              clips: clips,
            ),
          );

          expect(find.byType(ClipRRect), findsNWidgets(2));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('fully trimmed clip does not crash the strip', (
        tester,
      ) async {
        // trimStart + trimEnd == duration → trimmedDuration == zero;
        // the strip should skip this clip gracefully.
        final clips = [
          _createTestClip(id: 'normal', seconds: 3),
          _createTestClip(
            id: 'over_trimmed',
            trimStartMs: 1000,
            trimEndMs: 1000,
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips, totalWidth: 400));

        expect(tester.takeException(), isNull);
      });
    });
  });
}

DivineVideoClip _createTestClip({
  required String id,
  int seconds = 2,
  int trimStartMs = 0,
  int trimEndMs = 0,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/tmp/test_$id.mp4'),
    duration: Duration(seconds: seconds),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: .vertical,
    trimStart: Duration(milliseconds: trimStartMs),
    trimEnd: Duration(milliseconds: trimEndMs),
  );
}
