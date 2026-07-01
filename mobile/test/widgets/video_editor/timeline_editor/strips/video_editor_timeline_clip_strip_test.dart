// ABOUTME: Widget tests for VideoEditorTimelineClipStrip.
// ABOUTME: Validates clip rendering, layout, reorder gesture, and accessibility.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorTimelineClipStrip, () {
    late ScrollController scrollController;
    late VideoEditorMainBloc mainBloc;

    setUp(() {
      scrollController = ScrollController();
      mainBloc = VideoEditorMainBloc();
    });

    tearDown(() {
      scrollController.dispose();
      mainBloc.close();
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
          body: BlocProvider<VideoEditorMainBloc>.value(
            value: mainBloc,
            child: SingleChildScrollView(
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

    group('thumbnail fallback', () {
      // Regression: the fallback must be a plain FileImage (not a
      // cacheHeight-keyed ResizeImage) so it hits the warm poster cache entry
      // instead of a cold decode that flashes black on first open.
      testWidgets(
        'poster fallback reuses the plain FileImage key (no resize)',
        (tester) async {
          final clips = [
            _createTestClip(
              id: 'a',
              thumbnailPath: '/tmp/nonexistent_thumb_a.jpg',
            ),
          ];

          await tester.pumpWidget(buildWidget(clips: clips, totalWidth: 400));

          // Before strip thumbnails stream in, every slot renders the poster
          // fallback. Each must be a plain FileImage on the thumbnail path.
          final images = tester.widgetList<Image>(find.byType(Image)).toList();
          expect(images, isNotEmpty);
          for (final image in images) {
            expect(
              image.image,
              isA<FileImage>().having(
                (provider) => provider.file.path,
                'file.path',
                '/tmp/nonexistent_thumb_a.jpg',
              ),
              reason:
                  'Fallback must use a plain FileImage (not a cacheHeight-keyed '
                  'ResizeImage) so it hits the warm poster cache entry and '
                  'paints instantly instead of flashing black.',
            );
          }
        },
      );
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

    group('playbackSpeed scaling', () {
      // Regression: slow clips (speed < 1) used to render thumbnails over the
      // source-time pixel width, so the inner slot Row only spanned half the
      // visible playback-time tile and the strip stretched a smaller set of
      // wider slots — leaving the trailing region looking empty/black while
      // thumbnails streamed in. The underlying source-time strip
      // (_ClipTile.fullWidth) must be scaled by 1/playbackSpeed so the
      // generated thumbnail-slot count matches the visible tile.
      //
      // With the fix the inner Row renders `ceil(playbackWidth /
      // thumbnailWidth)` slots, each at the natural `thumbnailWidth`.
      // Without the fix `contentWidth < displayWidth`, so the renderer
      // falls back to stretched slots (`displayWidth / count`) wider than
      // `thumbnailWidth`, producing zero slot boxes at the natural width.
      testWidgets(
        'slow clip renders thumbnail slots at the natural width',
        (tester) async {
          const pps = 50.0;
          // source duration 4s, speed 0.5 → playback duration 8s.
          // Playback-scaled width = 4 / 0.5 * 50 = 400 px.
          // Expected natural-width slot count for the slow clip:
          //   ceil(400 / TimelineConstants.thumbnailWidth (= 48)) = 9.
          final slow = _createTestClip(
            id: 'slow',
            seconds: 4,
          ).copyWith(playbackSpeed: 0.5);
          // Normal clip kept tiny so its slot count is small and stable
          // (ceil(2 * 50 / 48) = 3) — used only to keep the strip on its
          // multi-clip branch (single-clip branch overrides _clipWidth with
          // totalWidth).
          final clips = [
            slow,
            _createTestClip(id: 'normal'),
          ];

          await tester.pumpWidget(
            buildWidget(
              clips: clips,
              pixelsPerSecond: pps,
              totalWidth: 1000,
            ),
          );

          final naturalSlotCount = tester
              .widgetList<SizedBox>(find.byType(SizedBox))
              .where(
                (s) =>
                    s.height == TimelineConstants.thumbnailStripHeight &&
                    s.width == TimelineConstants.thumbnailWidth,
              )
              .length;

          // 9 (slow clip) + 3 (normal clip) = 12. Without the 1/speed
          // scaling the slow clip falls back to stretched slots wider than
          // thumbnailWidth and contributes 0, leaving only the 3 from the
          // normal clip.
          expect(
            naturalSlotCount,
            equals(12),
            reason:
                'Slow clip must render ceil(playbackWidth / thumbnailWidth) '
                'natural-width slots. Without the 1/playbackSpeed scaling '
                'of _ClipTile.fullWidth the slow clip falls back to '
                'stretched slots (width > thumbnailWidth), producing 3 '
                'instead of 12 natural-width slots.',
          );
        },
      );
    });
  });
}

DivineVideoClip _createTestClip({
  required String id,
  int seconds = 2,
  int trimStartMs = 0,
  int trimEndMs = 0,
  String? thumbnailPath,
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
    thumbnailPath: thumbnailPath,
  );
}
