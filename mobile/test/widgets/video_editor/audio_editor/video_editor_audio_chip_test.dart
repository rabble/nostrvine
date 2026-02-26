// ABOUTME: Tests for VideoEditorAudioChip widget
// ABOUTME: Validates rendering states, tap callbacks, and clear functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/sounds_providers.dart';
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
    late bool onTapCalled;

    setUp(() {
      onTapCalled = false;
    });

    Widget buildWidget({AudioEvent? selectedSound}) {
      return ProviderScope(
        overrides: [
          selectedSoundProvider.overrideWith(
            () => _TestSelectedSoundNotifier(initialSound: selectedSound),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: VideoEditorAudioChip(onTap: () => onTapCalled = true),
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

      testWidgets('does not show close button', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(SvgPicture), findsNothing);
      });

      testWidgets('calls onTap when tapped', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(VideoEditorAudioChip));
        await tester.pumpAndSettle();

        expect(onTapCalled, isTrue);
      });

      testWidgets('renders audio bars', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // There should be 5 audio bars (AnimatedContainer)
        expect(find.byType(AnimatedContainer), findsNWidgets(5));
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

      testWidgets('shows close button', (tester) async {
        final sound = _createTestAudioEvent(title: 'Test Sound');
        await tester.pumpWidget(buildWidget(selectedSound: sound));
        await tester.pumpAndSettle();

        expect(find.byType(SvgPicture), findsOneWidget);
      });

      testWidgets('calls onTap when chip is tapped', (tester) async {
        final sound = _createTestAudioEvent(title: 'Test Sound');
        await tester.pumpWidget(buildWidget(selectedSound: sound));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        expect(onTapCalled, isTrue);
      });
    });

    group('Clear functionality', () {
      testWidgets('clears sound when close button is tapped', (tester) async {
        final sound = _createTestAudioEvent(title: 'Test Sound');
        await tester.pumpWidget(buildWidget(selectedSound: sound));
        await tester.pumpAndSettle();

        // Find and tap the close button (GestureDetector wrapping SvgPicture)
        final closeButton = find.byType(SvgPicture);
        expect(closeButton, findsOneWidget);

        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        // After clearing, should show "Add audio" again
        expect(find.text('Add audio'), findsOneWidget);
        expect(find.text('Test Sound'), findsNothing);
      });

      testWidgets('close button does not trigger onTap', (tester) async {
        final sound = _createTestAudioEvent(title: 'Test Sound');
        await tester.pumpWidget(buildWidget(selectedSound: sound));
        await tester.pumpAndSettle();

        // Tap specifically on the close button
        await tester.tap(find.byType(SvgPicture));
        await tester.pumpAndSettle();

        // onTap should not be called when tapping close button
        expect(onTapCalled, isFalse);
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
  });
}

/// Test notifier for SelectedSoundProvider
class _TestSelectedSoundNotifier extends SelectedSound {
  _TestSelectedSoundNotifier({this.initialSound});

  final AudioEvent? initialSound;

  @override
  AudioEvent? build() => initialSound;

  // Use inherited select and clear methods - they properly set state
}
