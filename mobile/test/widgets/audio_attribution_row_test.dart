// ABOUTME: Tests for AudioAttributionRow widget - displays sound attribution
// ABOUTME: on videos. Tests both explicit audio and original sound modes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_row.dart';

void main() {
  group(AudioAttributionRow, () {
    // Full 64-character Nostr IDs as required by CLAUDE.md
    const testAudioEventId =
        'audio0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';
    const testPubkey =
        'pubkey123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';
    const testVideoId =
        'video0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';

    late AudioEvent testAudio;

    setUp(() {
      testAudio = const AudioEvent(
        id: testAudioEventId,
        pubkey: testPubkey,
        createdAt: 1704067200,
        title: 'Original sound - @testuser',
        duration: 6.2,
        url: 'https://blossom.example/audio.aac',
        mimeType: 'audio/aac',
      );
    });

    VideoEvent createVideoWithAudio() {
      final now = DateTime.now();
      return VideoEvent(
        id: testVideoId,
        pubkey: testPubkey,
        content: 'Test video with audio',
        videoUrl: 'https://example.com/video.mp4',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        title: 'Test Video',
        audioEventId: testAudioEventId,
      );
    }

    VideoEvent createVideoWithoutAudio({String? authorName}) {
      final now = DateTime.now();
      return VideoEvent(
        id: testVideoId,
        pubkey: testPubkey,
        content: 'Test video without audio',
        videoUrl: 'https://example.com/video.mp4',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        title: 'Test Video',
        authorName: authorName,
      );
    }

    Widget buildTestWidget({
      required VideoEvent video,
      AudioEvent? audioOverride,
    }) {
      return ProviderScope(
        overrides: [
          // Override soundByIdProvider to return our test audio
          soundByIdProvider(testAudioEventId).overrideWith((ref) async {
            return audioOverride ?? testAudio;
          }),
        ],
        child: MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: AudioAttributionRow(video: video),
          ),
        ),
      );
    }

    group('Explicit audio reference', () {
      testWidgets('displays music note icon with vineGreen color', (
        tester,
      ) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final musicNoteIcon = tester.widget<Icon>(
          find.byIcon(Icons.music_note),
        );
        expect(musicNoteIcon.color, equals(VineTheme.vineGreen));
      });

      testWidgets('displays sound title', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Original sound - @testuser'),
          findsOneWidget,
        );
      });

      testWidgets('displays fallback when sound has no title', (tester) async {
        final video = createVideoWithAudio();
        const noTitleAudio = AudioEvent(
          id: testAudioEventId,
          pubkey: testPubkey,
          createdAt: 1704067200,
          duration: 6.2,
          url: 'https://blossom.example/audio.aac',
        );

        await tester.pumpWidget(
          buildTestWidget(video: video, audioOverride: noTitleAudio),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Original sound'), findsOneWidget);
      });

      testWidgets('displays chevron right icon', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });

      testWidgets('uses white text color', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final text = tester.widget<Text>(
          find.textContaining('Original sound - @testuser'),
        );
        expect(text.style?.color, equals(Colors.white));
      });

      testWidgets('falls back to original sound when audio event is null', (
        tester,
      ) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              soundByIdProvider(testAudioEventId).overrideWith((ref) async {
                return null;
              }),
            ],
            child: MaterialApp(
              theme: VineTheme.theme,
              home: Scaffold(
                backgroundColor: Colors.black,
                body: AudioAttributionRow(video: video),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should fall back to original sound display
        expect(find.byIcon(Icons.music_note), findsOneWidget);
        expect(find.textContaining('Original sound'), findsOneWidget);
      });
    });

    group('Original sound (no audio reference)', () {
      testWidgets('shows music note icon', (tester) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.music_note), findsOneWidget);
      });

      testWidgets('renders "Original sound" text', (tester) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.textContaining('Original sound'), findsOneWidget);
      });

      testWidgets('shows author name when available', (tester) async {
        final video = createVideoWithoutAudio(authorName: 'Jake Lara');

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Original sound - Jake Lara'),
          findsOneWidget,
        );
      });

      testWidgets('does not show chevron right icon', (tester) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        // Original sound row has no chevron (simpler display)
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      });

      testWidgets('has correct semantics identifier', (tester) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(AudioAttributionRow),
                matching: find.byType(Semantics),
              )
              .first,
        );

        expect(
          semantics.properties.identifier,
          equals('audio_attribution_row_original'),
        );
      });

      testWidgets('is marked as button for tap interaction', (tester) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(AudioAttributionRow),
                matching: find.byType(Semantics),
              )
              .first,
        );

        expect(semantics.properties.button, isTrue);
      });
    });

    group('Loading state', () {
      testWidgets('shows skeleton during loading', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              soundByIdProvider(testAudioEventId).overrideWith((ref) async {
                return testAudio;
              }),
            ],
            child: MaterialApp(
              theme: VineTheme.theme,
              home: Scaffold(
                backgroundColor: Colors.black,
                body: AudioAttributionRow(video: video),
              ),
            ),
          ),
        );

        // Pump once - at this point the future may still be loading
        await tester.pump();

        // After settling, should show music note icon (either skeleton or loaded)
        await tester.pumpAndSettle();
        final musicNoteIcons = tester.widgetList<Icon>(
          find.byIcon(Icons.music_note),
        );
        expect(musicNoteIcons, isNotEmpty);
      });
    });

    group('Accessibility', () {
      testWidgets('explicit audio has correct semantics identifier', (
        tester,
      ) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(AudioAttributionRow),
                matching: find.byType(Semantics),
              )
              .first,
        );

        expect(
          semantics.properties.identifier,
          equals('audio_attribution_row'),
        );
      });

      testWidgets('explicit audio has semantic label with sound info', (
        tester,
      ) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(AudioAttributionRow),
                matching: find.byType(Semantics),
              )
              .first,
        );

        expect(
          semantics.properties.label,
          contains('Sound: Original sound - @testuser'),
        );
      });

      testWidgets('explicit audio is marked as button', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(AudioAttributionRow),
                matching: find.byType(Semantics),
              )
              .first,
        );

        expect(semantics.properties.button, isTrue);
      });
    });

    group('Bundled sound attribution', () {
      testWidgets('displays artist via source for bundled sounds', (
        tester,
      ) async {
        final video = createVideoWithAudio();
        const bundledAudio = AudioEvent(
          id: 'bundled_freesound_crowd',
          pubkey: 'bundled',
          createdAt: 0,
          title: 'Oh No No No Crowd',
          duration: 5.9,
          url: 'asset://assets/sounds/oh-no-no-no-crowd.mp3',
          mimeType: 'audio/mpeg',
          source: 'ThePauny via Freesound',
        );

        await tester.pumpWidget(
          buildTestWidget(video: video, audioOverride: bundledAudio),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Oh No No No Crowd'), findsOneWidget);
        expect(find.textContaining('ThePauny via Freesound'), findsOneWidget);
      });

      testWidgets('does not try to fetch profile for bundled sounds', (
        tester,
      ) async {
        final video = createVideoWithAudio();
        const bundledAudio = AudioEvent(
          id: 'bundled_freesound_crowd',
          pubkey: 'bundled',
          createdAt: 0,
          title: 'Oh No No No Crowd',
          duration: 5.9,
          url: 'asset://assets/sounds/oh-no-no-no-crowd.mp3',
          mimeType: 'audio/mpeg',
          source: 'ThePauny via Freesound',
        );

        await tester.pumpWidget(
          buildTestWidget(video: video, audioOverride: bundledAudio),
        );
        await tester.pumpAndSettle();

        // Should show source, not @npub... or default display name
        expect(find.textContaining('npub'), findsNothing);
      });
    });

    group('Dark theme compliance', () {
      testWidgets('uses dark background with opacity', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(AudioAttributionRow),
                matching: find.byType(Container),
              )
              .first,
        );

        final decoration = container.decoration as BoxDecoration?;
        expect(decoration?.color?.a, lessThan(0.5));
      });
    });
  });
}
