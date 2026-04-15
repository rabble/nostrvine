// ABOUTME: Tests for MetadataSoundsSection - audio info in metadata sheet.
// ABOUTME: Tests both shared audio and original sound display modes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_sounds_section.dart';

void main() {
  group(MetadataSoundsSection, () {
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
        title: 'Cool Beat',
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
          soundByIdProvider(testAudioEventId).overrideWith((ref) async {
            return audioOverride ?? testAudio;
          }),
        ],
        child: MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: MetadataSoundsSection(video: video),
          ),
        ),
      );
    }

    group('Shared audio', () {
      testWidgets('shows sound title for video with audio reference', (
        tester,
      ) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.text('Cool Beat'), findsOneWidget);
      });

      testWidgets('shows Sounds label', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.text('Sounds'), findsOneWidget);
      });

      testWidgets('shows chevron for tappable shared audio', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });
    });

    group('Original sound', () {
      testWidgets('shows "Original sound" for video without audio reference', (
        tester,
      ) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.text('Original sound'), findsOneWidget);
      });

      testWidgets('shows Sounds label', (tester) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.text('Sounds'), findsOneWidget);
      });

      testWidgets('shows author name when available', (tester) async {
        final video = createVideoWithoutAudio(authorName: 'Jake Lara');

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.text('Jake Lara'), findsOneWidget);
      });

      testWidgets('shows chevron (tappable to use sound)', (tester) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
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
                body: MetadataSoundsSection(video: video),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should fall back to original sound
        expect(find.text('Original sound'), findsOneWidget);
      });
    });
  });
}
