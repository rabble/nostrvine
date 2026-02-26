// ABOUTME: Tests for VideoRecorderAudioProgressBar widget
// ABOUTME: Validates waveform rendering, visibility, and progress states

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_recorder/video_recorder_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_audio_progress_bar.dart';
import 'package:pro_video_editor/core/models/video/editor_video_model.dart';

import '../../mocks/mock_camera_service.dart';

class _MockSoundWaveformBloc
    extends MockBloc<SoundWaveformEvent, SoundWaveformState>
    implements SoundWaveformBloc {}

/// Helper to create test AudioEvent instances
AudioEvent _createTestAudioEvent({
  String id = 'test-sound-id',
  String pubkey = 'test-pubkey',
  int createdAt = 1704067200,
  String? url,
  String? title,
  double? duration,
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    url: url ?? 'https://example.com/audio/$id.mp3',
    title: title ?? 'Test Sound',
    duration: duration ?? 5.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderAudioProgressBar, () {
    late _MockSoundWaveformBloc mockBloc;
    late MockCameraService mockCamera;

    final testWaveformData = Float32List.fromList([
      0.1,
      0.3,
      0.5,
      0.8,
      0.6,
      0.4,
      0.2,
      0.9,
      0.7,
      0.5,
    ]);

    setUp(() async {
      mockBloc = _MockSoundWaveformBloc();
      mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();
    });

    Widget buildWidget({
      VideoRecorderState recordingState = VideoRecorderState.idle,
      AudioEvent? selectedSound,
      SoundWaveformState? waveformState,
      List<RecordingClip>? clips,
      Duration activeRecordingDuration = Duration.zero,
    }) {
      when(
        () => mockBloc.state,
      ).thenReturn(waveformState ?? const SoundWaveformInitial());

      return ProviderScope(
        overrides: [
          videoRecorderProvider.overrideWith(
            () => _TestVideoRecorderNotifier(
              mockCamera,
              recordingState: recordingState,
            ),
          ),
          clipManagerProvider.overrideWith(
            () => _TestClipManagerNotifier(
              clips: clips ?? [],
              activeRecordingDuration: activeRecordingDuration,
            ),
          ),
        ],
        child: Builder(
          builder: (context) {
            // Set selected sound after build if provided
            return MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    BlocProvider<SoundWaveformBloc>.value(
                      value: mockBloc,
                      child: Consumer(
                        builder: (context, ref, child) {
                          // Set the selected sound in the provider
                          if (selectedSound != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              ref
                                  .read(selectedSoundProvider.notifier)
                                  .select(selectedSound);
                            });
                          }
                          return const VideoRecorderAudioProgressBar();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    group('Visibility', () {
      testWidgets('shows SizedBox.shrink when not recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.idle,
            selectedSound: _createTestAudioEvent(),
          ),
        );
        await tester.pumpAndSettle();

        // Should show empty SizedBox with specific key
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsOneWidget,
        );
      });

      testWidgets('shows SizedBox.shrink when no sound selected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: null,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsOneWidget,
        );
      });

      testWidgets('shows SizedBox.shrink when not recording and no sound', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.idle,
            selectedSound: null,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsOneWidget,
        );
      });
    });

    group('Loading state', () {
      testWidgets('shows placeholder when waveform is loading', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: const SoundWaveformLoading(),
          ),
        );
        await tester.pumpAndSettle();

        // Should find at least one CustomPaint (the waveform placeholder)
        expect(find.byType(CustomPaint), findsWidgets);
        // And importantly NOT the empty state key
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsNothing,
        );
      });

      testWidgets('shows placeholder when waveform has error', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: const SoundWaveformError('Test error'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CustomPaint), findsWidgets);
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsNothing,
        );
      });
    });

    group('Loaded state', () {
      testWidgets('renders waveform when loaded', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: SoundWaveformLoaded(
              leftChannel: testWaveformData,
              rightChannel: testWaveformData,
              duration: const Duration(seconds: 5),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show the waveform (CustomPaint used for rendering)
        expect(find.byType(CustomPaint), findsWidgets);
        // And NOT the empty state
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsNothing,
        );
      });

      testWidgets('renders within Positioned widget', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: SoundWaveformLoaded(
              leftChannel: testWaveformData,
              duration: const Duration(seconds: 5),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Positioned), findsWidgets);
      });

      testWidgets('uses SafeArea for status bar padding', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: SoundWaveformLoaded(
              leftChannel: testWaveformData,
              duration: const Duration(seconds: 5),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SafeArea), findsOneWidget);
      });
    });

    group('Progress tracking', () {
      testWidgets('renders with existing clips progress', (tester) async {
        final clips = [
          RecordingClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ];

        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: SoundWaveformLoaded(
              leftChannel: testWaveformData,
              duration: const Duration(seconds: 5),
            ),
            clips: clips,
          ),
        );
        await tester.pumpAndSettle();

        // Should render the waveform with clip progress
        expect(find.byType(CustomPaint), findsWidgets);
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsNothing,
        );
      });

      testWidgets('renders with active recording duration', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: SoundWaveformLoaded(
              leftChannel: testWaveformData,
              duration: const Duration(seconds: 5),
            ),
            activeRecordingDuration: const Duration(seconds: 3),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CustomPaint), findsWidgets);
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsNothing,
        );
      });
    });

    group('Animation', () {
      testWidgets('uses AnimatedSwitcher for transitions', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
          ),
        );

        expect(find.byType(AnimatedSwitcher), findsOneWidget);
      });
    });

    group('Initial state', () {
      testWidgets('shows empty content when waveform is in initial state', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: _createTestAudioEvent(),
            waveformState: const SoundWaveformInitial(),
          ),
        );
        await tester.pumpAndSettle();

        // Initial state shows SizedBox.shrink (no waveform data yet)
        // but NOT the "not recording" empty state
        expect(
          find.byKey(const ValueKey('Empty-Video-Recorder-Audio-Track')),
          findsNothing,
        );
        // The VideoRecorderAudioProgressBar renders
        expect(find.byType(VideoRecorderAudioProgressBar), findsOneWidget);
      });
    });
  });
}

/// Test notifier for VideoRecorderProvider
class _TestVideoRecorderNotifier extends VideoRecorderNotifier {
  _TestVideoRecorderNotifier(
    super.cameraService, {
    this.recordingState = VideoRecorderState.idle,
  });

  final VideoRecorderState recordingState;

  @override
  VideoRecorderProviderState build() {
    return VideoRecorderProviderState(recordingState: recordingState);
  }
}

/// Test notifier for ClipManagerProvider
class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier({
    required this.clips,
    required this.activeRecordingDuration,
  });

  final List<RecordingClip> clips;
  final Duration activeRecordingDuration;

  @override
  ClipManagerState build() {
    return ClipManagerState(
      clips: clips,
      activeRecordingDuration: activeRecordingDuration,
    );
  }
}
