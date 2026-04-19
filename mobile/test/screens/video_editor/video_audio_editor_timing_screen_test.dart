// ABOUTME: Tests for VideoAudioEditorTimingScreen widget
// ABOUTME: Validates rendering, navigation results, top bar controls,
// ABOUTME: and the AudioTimingResult sealed class hierarchy.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/video_editor/video_audio_editor_timing_screen.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Mock ProVideoEditor to prevent calls to native platform.
class _MockProVideoEditor extends ProVideoEditor {
  @override
  void initializeStream() {
    // Intentional no-op: testing stub for ProVideoEditor.
  }

  @override
  Future<bool> hasAudioTrack(EditorVideo value) async {
    return true;
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
  }) async {
    return VideoMetadata(
      duration: const Duration(seconds: 10),
      extension: 'mp4',
      fileSize: 1024000,
      resolution: const Size(1920, 1080),
      rotation: 0,
      bitrate: 3000000,
    );
  }

  @override
  Future<WaveformData> getWaveform(WaveformConfigs value) async {
    return WaveformData(
      leftChannel: Float32List(100),
      rightChannel: Float32List(100),
      sampleRate: 44100,
      duration: const Duration(seconds: 10),
      samplesPerSecond: 10,
    );
  }

  @override
  Future<String> extractAudioToFile(
    String filePath,
    AudioExtractConfigs value,
  ) async {
    return filePath;
  }
}

/// Helper to create test AudioEvent instances.
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
    duration: duration ?? 10.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioTimingResult', () {
    test('$AudioTimingConfirmed holds updated sound', () {
      final sound = _createTestAudioEvent(title: 'Test Sound');
      final result = AudioTimingConfirmed(sound);

      expect(result.sound, equals(sound));
      expect(result.sound.title, equals('Test Sound'));
    });

    test('$AudioTimingDeleted can be constructed', () {
      const result = AudioTimingDeleted();

      expect(result, isA<AudioTimingResult>());
    });

    test('$AudioTimingConfirmed is $AudioTimingResult', () {
      final sound = _createTestAudioEvent();
      final result = AudioTimingConfirmed(sound);

      expect(result, isA<AudioTimingResult>());
    });

    test('exhaustive switch works on $AudioTimingResult', () {
      final sound = _createTestAudioEvent();
      final AudioTimingResult result = AudioTimingConfirmed(sound);

      // Verify pattern matching compiles and resolves correctly
      final label = switch (result) {
        AudioTimingConfirmed(:final sound) => 'confirmed: ${sound.id}',
        AudioTimingDeleted() => 'deleted',
      };

      expect(label, contains('confirmed'));
      expect(label, contains('test-sound-id'));
    });

    test('exhaustive switch resolves $AudioTimingDeleted', () {
      const AudioTimingResult result = AudioTimingDeleted();

      final label = switch (result) {
        AudioTimingConfirmed(:final sound) => 'confirmed: ${sound.id}',
        AudioTimingDeleted() => 'deleted',
      };

      expect(label, equals('deleted'));
    });
  });

  group(VideoAudioEditorTimingScreen, () {
    late _MockProVideoEditor mockEditor;

    setUp(() {
      mockEditor = _MockProVideoEditor();
      ProVideoEditor.instance = mockEditor;
    });

    Widget buildWidget({AudioEvent? sound}) {
      final testSound =
          sound ??
          _createTestAudioEvent(
            title: 'Test Audio',
            duration: 10.0,
          );

      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoAudioEditorTimingScreen(sound: testSound),
        ),
      );
    }

    testWidgets('renders $VideoAudioEditorTimingScreen', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(
        find.byType(VideoAudioEditorTimingScreen),
        findsOneWidget,
      );
    });

    testWidgets('renders instruction text', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(
        find.text('Select the audio segment for your video'),
        findsOneWidget,
      );
    });

    testWidgets('renders $VideoEditorAudioChip in top bar', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.byType(VideoEditorAudioChip), findsOneWidget);
    });

    testWidgets('renders with bundled sound', (tester) async {
      const bundledSound = AudioEvent(
        id: 'bundled__lofi-beat',
        pubkey: 'bundled_',
        createdAt: 0,
        url: 'asset://assets/sounds/lofi-beat.mp3',
        title: 'Lo-Fi Beat',
        duration: 5.0,
      );

      await tester.pumpWidget(buildWidget(sound: bundledSound));
      await tester.pump();

      expect(
        find.byType(VideoAudioEditorTimingScreen),
        findsOneWidget,
      );
    });

    testWidgets('renders with short audio (< maxDuration)', (tester) async {
      final shortSound = _createTestAudioEvent(
        title: 'Short Clip',
        duration: 3.0,
      );

      await tester.pumpWidget(buildWidget(sound: shortSound));
      await tester.pump();

      expect(
        find.byType(VideoAudioEditorTimingScreen),
        findsOneWidget,
      );
    });

    testWidgets('renders with long audio (> maxDuration)', (tester) async {
      final longSound = _createTestAudioEvent(
        title: 'Long Track',
        duration: 30.0,
      );

      await tester.pumpWidget(buildWidget(sound: longSound));
      await tester.pump();

      expect(
        find.byType(VideoAudioEditorTimingScreen),
        findsOneWidget,
      );
    });

    testWidgets('has route name and path constants', (tester) async {
      expect(
        VideoAudioEditorTimingScreen.routeName,
        equals('video-audio-timing'),
      );
      expect(
        VideoAudioEditorTimingScreen.path,
        equals('/video-audio-timing'),
      );
    });
  });
}
