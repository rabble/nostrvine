// ABOUTME: Widget tests for SubtitleEditorStage — the video preview and its
// ABOUTME: cue timeline, wired to a stubbed filmstrip.

import 'dart:async';
import 'dart:io';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/subtitle_editor/timeline_frame.dart';
import 'package:openvine/widgets/caption_pill.dart';
import 'package:openvine/widgets/subtitle_editor/subtitle_cue_timeline.dart';
import 'package:openvine/widgets/subtitle_editor/subtitle_editor_stage.dart';

/// A loader that yields no frames, so the native decoder is never touched.
Stream<List<TimelineFrame>> _noFrames({
  required String videoUrl,
  required String videoId,
  required Duration duration,
  required double devicePixelRatio,
}) => const Stream.empty();

/// A loader that gives up part-way, as an injected one is free to do.
Stream<List<TimelineFrame>> _failingFrames({
  required String videoUrl,
  required String videoId,
  required Duration duration,
  required double devicePixelRatio,
}) async* {
  yield const [TimelineFrame(path: 'frame.jpg', timestamp: Duration.zero)];
  throw StateError('decoder gave up');
}

void main() {
  group(SubtitleEditorStage, () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('subtitle_stage_frames');
    });

    tearDown(() => temp.deleteSync(recursive: true));

    Widget pump({
      required List<EditableCue> cues,
      EditableCue? selectedCue,
      TimelineFrameLoader loadFrames = _noFrames,
    }) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          height: 600,
          width: 400,
          child: SubtitleEditorStage(
            videoUrl: 'https://example.com/video.mp4',
            videoId:
                '0000000000000000000000000000000000000000000000000000000000000000',
            cues: cues,
            totalDuration: const Duration(seconds: 8),
            selectedCue: selectedCue,
            loadFrames: loadFrames,
          ),
        ),
      ),
    );

    testWidgets('shows the video above its cue timeline', (tester) async {
      await tester.pumpWidget(
        pump(cues: const [EditableCue(start: 0, end: 1000, text: 'one')]),
      );
      await tester.pump();

      final timeline = find.byType(SubtitleCueTimeline);
      expect(timeline, findsOneWidget);
      expect(
        tester.getTopLeft(timeline).dy,
        greaterThan(0),
        reason: 'the picture occupies the space above the timeline',
      );
    });

    testWidgets('the preview is a play/pause target', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        pump(cues: const [EditableCue(start: 0, end: 1000, text: 'one')]),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      final preview = tester.getSemantics(
        find
            .ancestor(
              of: find.byType(DivineVideoPlayer),
              matching: find.byType(Semantics),
            )
            .first,
      );
      // No native backend in a widget test, so the player never reports
      // playing and the preview stays on its paused label.
      expect(preview.label, l10n.subtitleEditorPlayPreview);
      expect(preview.flagsCollection.isButton, isTrue);
      semantics.dispose();
    });

    testWidgets('a filmstrip that gives up leaves the stage standing', (
      tester,
    ) async {
      await tester.pumpWidget(
        pump(
          cues: const [EditableCue(start: 0, end: 1000, text: 'one')],
          loadFrames: _failingFrames,
        ),
      );
      // Enough pumps for the loader to deliver its batch and then fail; an
      // escaping error would fail this test rather than reach Crashlytics.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(SubtitleCueTimeline), findsOneWidget);
    });

    testWidgets('the cue live at the playhead is drawn over the picture', (
      tester,
    ) async {
      await tester.pumpWidget(
        pump(
          cues: const [
            EditableCue(start: 0, end: 1000, text: 'live now'),
            EditableCue(start: 4000, end: 5000, text: 'later'),
          ],
        ),
      );
      await tester.pump();

      // The player starts at zero, so only the first cue is on screen.
      final pill = find.byType(CaptionPill);
      expect(pill, findsOneWidget);
      expect(
        find.descendant(of: pill, matching: find.text('live now')),
        findsOneWidget,
      );
    });

    test('rejects stale paused reports while a seek is pending', () {
      expect(
        SubtitleEditorStage.shouldAcceptPlayerReport(
          report: const Duration(seconds: 1),
          seekTarget: const Duration(seconds: 4),
          isPlaying: false,
        ),
        isFalse,
      );
      expect(
        SubtitleEditorStage.shouldAcceptPlayerReport(
          report: const Duration(milliseconds: 4075),
          seekTarget: const Duration(seconds: 4),
          isPlaying: false,
        ),
        isTrue,
      );
      expect(
        SubtitleEditorStage.shouldAcceptPlayerReport(
          report: const Duration(seconds: 1),
          seekTarget: const Duration(seconds: 4),
          isPlaying: true,
        ),
        isTrue,
      );
    });

    test(
      'resolves preview playback candidates in order and deduplicates',
      () async {
        final seen = <String?>[];

        final urls = await SubtitleEditorStage.resolvePreviewPlaybackUrls(
          playbackUrls: const [
            'https://media.divine.video/hash/720p.mp4',
            'https://media.divine.video/hash/hls/master.m3u8',
            'https://media.divine.video/hash/720p.mp4',
            '',
          ],
          resolvePlayableUrl: (url) async {
            seen.add(url);
            if (url?.endsWith('.m3u8') ?? false) {
              return 'https://media.divine.video/hash/720p.mp4';
            }
            return url;
          },
        );

        expect(
          seen,
          equals([
            'https://media.divine.video/hash/720p.mp4',
            'https://media.divine.video/hash/hls/master.m3u8',
            'https://media.divine.video/hash/720p.mp4',
            '',
          ]),
        );
        expect(urls, equals(['https://media.divine.video/hash/720p.mp4']));
      },
    );

    testWidgets('deletes loaded filmstrip files when disposed', (tester) async {
      final frame = File('${temp.path}/frame.jpg')..writeAsStringSync('frame');
      final controller = StreamController<List<TimelineFrame>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        pump(
          cues: const [EditableCue(start: 0, end: 1000, text: 'one')],
          loadFrames:
              ({
                required String videoUrl,
                required String videoId,
                required Duration duration,
                required double devicePixelRatio,
              }) => controller.stream,
        ),
      );
      controller.add([
        TimelineFrame(path: frame.path, timestamp: Duration.zero),
      ]);
      await tester.pump();
      expect(frame.existsSync(), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(frame.existsSync(), isFalse);
    });
  });
}
