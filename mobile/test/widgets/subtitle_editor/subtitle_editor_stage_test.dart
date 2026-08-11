// ABOUTME: Widget tests for SubtitleEditorStage — the video preview and its
// ABOUTME: cue timeline, wired to a stubbed filmstrip.

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/subtitle_timeline_thumbnail_service.dart';
import 'package:openvine/widgets/caption_pill.dart';
import 'package:openvine/widgets/subtitle_editor/subtitle_cue_timeline.dart';
import 'package:openvine/widgets/subtitle_editor/subtitle_editor_stage.dart';

/// A service that resolves to no video, so no frames are extracted and the
/// native decoder is never touched.
SubtitleTimelineThumbnailService _noThumbnails() =>
    SubtitleTimelineThumbnailService(
      downloadVideo: ({required String url, required String cacheKey}) async =>
          null,
    );

void main() {
  group(SubtitleEditorStage, () {
    Widget pump({
      required List<EditableCue> cues,
      EditableCue? selectedCue,
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
            thumbnailService: _noThumbnails(),
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
  });
}
