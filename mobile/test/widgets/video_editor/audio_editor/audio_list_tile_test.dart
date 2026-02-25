// ABOUTME: Tests for AudioListTile widget
// ABOUTME: Validates rendering, play/pause, and selection callbacks

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_list_tile.dart';
import 'package:openvine/widgets/video_editor_icon_button.dart';

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
    duration: duration,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(AudioListTile, () {
    late bool playPauseCalled;
    late bool selectCalled;

    setUp(() {
      playPauseCalled = false;
      selectCalled = false;
    });

    Widget buildWidget({required AudioEvent audio, bool isPlaying = false}) {
      return MaterialApp(
        home: Scaffold(
          body: AudioListTile(
            audio: audio,
            isPlaying: isPlaying,
            onPlayPause: () => playPauseCalled = true,
            onSelect: () => selectCalled = true,
          ),
        ),
      );
    }

    group('Rendering', () {
      testWidgets('renders sound title', (tester) async {
        final audio = _createTestAudioEvent(title: 'My Cool Sound');
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.text('My Cool Sound'), findsOneWidget);
      });

      testWidgets('renders "Untitled sound" when title is null', (
        tester,
      ) async {
        final audio = _createTestAudioEvent(title: null);
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.text('Untitled sound'), findsOneWidget);
      });

      testWidgets('renders formatted duration', (tester) async {
        final audio = _createTestAudioEvent(duration: 125.0); // 2:05
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('02:05'), findsOneWidget);
      });

      testWidgets('renders "--:--" when duration is null', (tester) async {
        final audio = _createTestAudioEvent(duration: null);
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('--:--'), findsOneWidget);
      });

      testWidgets('renders source when available', (tester) async {
        final audio = _createTestAudioEvent(
          duration: 60.0,
          source: 'Artist Name',
        );
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('Artist Name'), findsOneWidget);
      });

      testWidgets('renders ListTile', (tester) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.byType(ListTile), findsOneWidget);
      });

      testWidgets('renders icon buttons', (tester) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        // Should have 2 VideoEditorIconButtons: play/pause and add
        expect(find.byType(VideoEditorIconButton), findsNWidgets(2));
      });
    });

    group('Play/Pause state', () {
      testWidgets('shows play icon when not playing', (tester) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio, isPlaying: false));
        await tester.pumpAndSettle();

        // The play icon button should have play semantics
        expect(find.bySemanticsLabel('Play preview'), findsOneWidget);
      });

      testWidgets('shows pause icon when playing', (tester) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio, isPlaying: true));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Pause preview'), findsOneWidget);
      });
    });

    group('Callbacks', () {
      testWidgets('calls onPlayPause when play button is tapped', (
        tester,
      ) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        // Find and tap the leading icon button (play/pause)
        final playButton = find.bySemanticsLabel('Play preview');
        await tester.tap(playButton);
        await tester.pumpAndSettle();

        expect(playPauseCalled, isTrue);
        expect(selectCalled, isFalse);
      });

      testWidgets('calls onSelect when select button is tapped', (
        tester,
      ) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        // Tap the selection button (trailing icon)
        await tester.tap(find.bySemanticsLabel('Select sound'));
        await tester.pumpAndSettle();

        expect(selectCalled, isTrue);
        expect(playPauseCalled, isFalse);
      });
    });

    group('Duration formatting', () {
      testWidgets('formats single digit seconds correctly', (tester) async {
        final audio = _createTestAudioEvent(duration: 5.0); // 0:05
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('00:05'), findsOneWidget);
      });

      testWidgets('formats minutes correctly', (tester) async {
        final audio = _createTestAudioEvent(duration: 90.0); // 1:30
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('01:30'), findsOneWidget);
      });

      testWidgets('truncates fractional seconds', (tester) async {
        final audio = _createTestAudioEvent(
          duration: 65.7,
        ); // 65.7s = 1 min 5.7s → 01:05
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('01:05'), findsOneWidget);
      });
    });
  });
}
