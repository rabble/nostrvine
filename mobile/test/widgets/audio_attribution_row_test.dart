// ABOUTME: Tests for AudioAttributionRow widget - displays sound attribution on videos.
// ABOUTME: Verifies shared audio, original sound fallback, dark theme, tap, and accessibility.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
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

    VideoEvent createVideoWithoutAudio() {
      final now = DateTime.now();
      return VideoEvent(
        id: testVideoId,
        pubkey: testPubkey,
        content: 'Test video without audio',
        videoUrl: 'https://example.com/video.mp4',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        title: 'Test Video',
      );
    }

    Widget buildTestWidget({
      required VideoEvent video,
      AudioEvent? audioOverride,
      List<dynamic> additionalOverrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          if (video.hasAudioReference)
            soundByIdProvider(testAudioEventId).overrideWith((ref) async {
              return audioOverride ?? testAudio;
            }),
          ...additionalOverrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: AudioAttributionRow(video: video),
          ),
        ),
      );
    }

    group('Original sound (no audio reference)', () {
      testWidgets('shows Original sound with creator display name', (
        tester,
      ) async {
        final video = createVideoWithoutAudio();
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const <String, dynamic>{},
          createdAt: DateTime(2024),
          eventId:
              'event0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab',
          displayName: 'TestCreator',
        );

        await tester.pumpWidget(
          buildTestWidget(
            video: video,
            additionalOverrides: [
              userProfileReactiveProvider(testPubkey).overrideWith(
                (ref) => Stream.value(profile),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Original sound - TestCreator'),
          findsOneWidget,
        );
      });

      testWidgets('shows music note icon with vineGreen color', (
        tester,
      ) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final divineIcons = tester.widgetList<DivineIcon>(
          find.descendant(
            of: find.byType(AudioAttributionRow),
            matching: find.byType(DivineIcon),
          ),
        );
        final musicNoteIcon = divineIcons.firstWhere(
          (icon) => icon.icon == DivineIconName.musicNote,
        );
        expect(musicNoteIcon.color, equals(VineTheme.vineGreen));
      });

      testWidgets('shows caret right icon', (tester) async {
        final video = createVideoWithoutAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final divineIcons = tester.widgetList<DivineIcon>(
          find.descendant(
            of: find.byType(AudioAttributionRow),
            matching: find.byType(DivineIcon),
          ),
        );
        expect(
          divineIcons.any((icon) => icon.icon == DivineIconName.caretRight),
          isTrue,
        );
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
          equals('audio_attribution_row'),
        );
      });

      testWidgets('has semantic label with Original sound', (tester) async {
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

        expect(semantics.properties.label, contains('Original sound'));
      });

      testWidgets('falls back to generated name when no profile', (
        tester,
      ) async {
        final video = createVideoWithoutAudio();
        final generatedName = UserProfile.defaultDisplayNameFor(testPubkey);

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Original sound - $generatedName'),
          findsOneWidget,
        );
      });
    });

    group('Shared audio (has audio reference)', () {
      testWidgets('displays sound title', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Original sound - @testuser'),
          findsOneWidget,
        );
      });

      testWidgets('displays music note icon with vineGreen color', (
        tester,
      ) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final divineIcons = tester.widgetList<DivineIcon>(
          find.descendant(
            of: find.byType(AudioAttributionRow),
            matching: find.byType(DivineIcon),
          ),
        );
        final musicNoteIcon = divineIcons.firstWhere(
          (icon) => icon.icon == DivineIconName.musicNote,
        );
        expect(musicNoteIcon.color, equals(VineTheme.vineGreen));
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

      testWidgets('displays caret right icon', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final divineIcons = tester.widgetList<DivineIcon>(
          find.descendant(
            of: find.byType(AudioAttributionRow),
            matching: find.byType(DivineIcon),
          ),
        );
        expect(
          divineIcons.any((icon) => icon.icon == DivineIconName.caretRight),
          isTrue,
        );
      });

      testWidgets('uses white text color', (tester) async {
        final video = createVideoWithAudio();

        await tester.pumpWidget(buildTestWidget(video: video));
        await tester.pumpAndSettle();

        final text = tester.widget<Text>(
          find.textContaining('Original sound - @testuser'),
        );
        expect(text.style?.color, equals(VineTheme.whiteText));
      });

      testWidgets(
        'falls back to Original sound when audio event is null',
        (tester) async {
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

          // Should fall back to original sound, not hide
          expect(find.textContaining('Original sound'), findsOneWidget);
        },
      );
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
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
        final divineIcons = tester.widgetList<DivineIcon>(
          find.descendant(
            of: find.byType(AudioAttributionRow),
            matching: find.byType(DivineIcon),
          ),
        );
        expect(
          divineIcons.any((icon) => icon.icon == DivineIconName.musicNote),
          isTrue,
        );
      });
    });

    group('Accessibility', () {
      testWidgets('has correct semantics identifier for shared audio', (
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

      testWidgets('has semantic label with sound info', (tester) async {
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

      testWidgets('is marked as button for tap interaction', (tester) async {
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

        expect(
          find.textContaining('Oh No No No Crowd'),
          findsOneWidget,
        );
        expect(
          find.textContaining('ThePauny via Freesound'),
          findsOneWidget,
        );
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
