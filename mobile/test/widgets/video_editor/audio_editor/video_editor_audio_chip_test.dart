// ABOUTME: Tests for VideoEditorAudioChip widget
// ABOUTME: Validates rendering states and visual elements

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';

/// Helper to create test AudioEvent instances
AudioEvent _createTestAudioEvent({
  String id = 'test-sound-id',
  String pubkey = 'test-pubkey',
  int createdAt = 1704067200,
  String? url,
  String? title,
  String? source,
  double? duration,
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    url: url ?? 'https://example.com/audio/$id.mp3',
    title: title,
    source: source,
    duration: duration ?? 5.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorAudioChip, () {
    Widget buildWidget({
      AudioEvent? selectedSound,
      ValueChanged<AudioEvent?>? onSoundChanged,
    }) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: VideoEditorAudioChip(
                selectedSound: selectedSound,
                onSoundChanged: onSoundChanged ?? (_) {},
              ),
            ),
          ),
        ),
      );
    }

    group('No sound selected', () {
      testWidgets('renders "Add audio" text', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.text('Add audio'), findsOneWidget);
      });

      testWidgets('does not show music icon', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // When no sound selected, shows audio bars instead of music icon
        expect(find.byType(DivineIcon), findsNothing);
      });

      testWidgets('renders audio bars', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // There should be 5 audio bars (AnimatedContainer)
        expect(find.byType(AnimatedContainer), findsNWidgets(5));
      });

      testWidgets('has tappable InkWell', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(InkWell), findsOneWidget);
      });
    });

    group('Sound selected', () {
      testWidgets('renders sound title', (tester) async {
        final sound = _createTestAudioEvent(title: 'My Cool Sound');
        await tester.pumpWidget(buildWidget(selectedSound: sound));
        await tester.pumpAndSettle();

        expect(find.text('My Cool Sound'), findsOneWidget);
        expect(find.text('Add audio'), findsNothing);
      });

      testWidgets('renders "Untitled" when title is null', (tester) async {
        final sound = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(selectedSound: sound));
        await tester.pumpAndSettle();

        expect(find.text('Untitled'), findsOneWidget);
      });

      testWidgets('renders source when available', (tester) async {
        final sound = _createTestAudioEvent(
          title: 'Cool Track',
          source: 'Artist Name',
        );
        await tester.pumpWidget(buildWidget(selectedSound: sound));
        await tester.pumpAndSettle();

        // Both title and source should be rendered in rich text
        expect(find.textContaining('Cool Track'), findsOneWidget);
        expect(find.textContaining('Artist Name'), findsOneWidget);
      });

      testWidgets('shows audio bars when sound selected', (tester) async {
        final sound = _createTestAudioEvent(title: 'Test Sound');
        await tester.pumpWidget(buildWidget(selectedSound: sound));
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedContainer), findsNWidgets(5));
      });

      testWidgets('does not show music icon when sound selected', (
        tester,
      ) async {
        final sound = _createTestAudioEvent(title: 'Test Sound');
        await tester.pumpWidget(buildWidget(selectedSound: sound));
        await tester.pumpAndSettle();

        // No DivineIcon is used in sound-selected state
        expect(find.byType(DivineIcon), findsNothing);
      });
    });

    group('Visual elements', () {
      testWidgets('uses InkWell for tap feedback', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(InkWell), findsOneWidget);
      });

      testWidgets('renders chip container with proper structure', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Verify the widget renders with its main components
        expect(find.byType(VideoEditorAudioChip), findsOneWidget);
        expect(find.byType(Row), findsWidgets);
      });
    });

    group('Callback behavior', () {
      testWidgets('accepts onSoundChanged callback', (tester) async {
        AudioEvent? receivedSound;

        await tester.pumpWidget(
          buildWidget(onSoundChanged: (sound) => receivedSound = sound),
        );
        await tester.pumpAndSettle();

        // Verify widget renders with callback prop
        expect(find.byType(VideoEditorAudioChip), findsOneWidget);
        // Callback is not invoked just by rendering
        expect(receivedSound, isNull);
      });
    });
  });
}
