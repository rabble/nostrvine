// ABOUTME: Tests for AudioEditorSelectionOverlay widget
// ABOUTME: Validates rendering of audio metadata, play/pause toggle, and done.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_editor_selection_overlay.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

AudioEvent _createTestAudio({
  String id = 'sound-id',
  String? title,
  String? source,
  double? duration = 65.0,
}) {
  return AudioEvent(
    id: id,
    pubkey: 'pubkey',
    createdAt: 1704067200,
    url: 'https://example.com/$id.mp3',
    title: title,
    source: source,
    duration: duration,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAudioPlaybackService audioService;

  setUp(() {
    audioService = _MockAudioPlaybackService();
    when(
      () => audioService.playingStream,
    ).thenAnswer((_) => const Stream<bool>.empty());
    when(
      () => audioService.durationStream,
    ).thenAnswer((_) => const Stream<Duration?>.empty());
    when(
      () => audioService.positionStream,
    ).thenAnswer((_) => const Stream<Duration>.empty());
    when(() => audioService.isPlaying).thenReturn(false);
    when(() => audioService.duration).thenReturn(null);
  });

  group(AudioEditorSelectionOverlay, () {
    Widget buildWidget({
      required AudioEvent audio,
      VoidCallback? onTogglePlayState,
      VoidCallback? onTapDone,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AudioEditorSelectionOverlay(
            audio: audio,
            audioService: audioService,
            onTogglePlayState: onTogglePlayState ?? () {},
            onTapDone: onTapDone ?? () {},
          ),
        ),
      );
    }

    group('Rendering', () {
      testWidgets('renders audio title', (tester) async {
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(title: 'My Track')),
        );
        await tester.pump();

        expect(find.text('My Track'), findsOneWidget);
      });

      testWidgets('renders untitled fallback when title is null', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(audio: _createTestAudio()));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorAudioUntitledSound), findsOneWidget);
      });

      testWidgets('renders formatted duration', (tester) async {
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(duration: 125.0)),
        );
        await tester.pump();

        expect(find.textContaining('02:05'), findsOneWidget);
      });

      testWidgets('renders source when available', (tester) async {
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(source: 'Artist X')),
        );
        await tester.pump();

        expect(find.textContaining('Artist X'), findsOneWidget);
      });
    });

    group('Callbacks', () {
      testWidgets('calls onTogglePlayState when play button is tapped', (
        tester,
      ) async {
        var toggled = false;
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudio(title: 'Track'),
            onTogglePlayState: () => toggled = true,
          ),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorAudioPlayPreviewSemanticLabel),
        );
        await tester.pump();

        expect(toggled, isTrue);
      });

      testWidgets('calls onTapDone when done button is tapped', (tester) async {
        var done = false;
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudio(title: 'Track'),
            onTapDone: () => done = true,
          ),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorDoneSemanticLabel),
        );
        await tester.pump();

        expect(done, isTrue);
      });
    });

    group('Playing state', () {
      testWidgets('shows pause semantic label when playing', (tester) async {
        when(() => audioService.isPlaying).thenReturn(true);
        when(
          () => audioService.playingStream,
        ).thenAnswer((_) => Stream<bool>.value(true));

        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(title: 'Track')),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.videoEditorAudioPausePreviewSemanticLabel),
          findsOneWidget,
        );
      });
    });
  });
}
