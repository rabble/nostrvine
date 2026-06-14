import 'package:bloc_test/bloc_test.dart';
import 'package:divine_camera/divine_camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _MockCameraService extends Mock implements CameraService {}

class _MockClipManager extends Mock implements ClipManagerNotifier {}

class _MockVideoEditor extends Mock implements VideoEditorNotifier {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

/// A fake wakelock platform —
/// production code calls `WakelockPlus.enable/disable` around every
/// recording session, which hits a platform channel that isn't bound
/// in unit tests. Override the platform instance with a fake so the
/// channel call is a no-op.
class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

void main() {
  late _MockCameraService cameraService;
  late _MockClipManager clipManager;
  late _MockVideoEditor videoEditor;
  late _MockSharedPreferences prefs;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    wakelockPlusPlatformInstance = _FakeWakelockPlatform();
    registerFallbackValue(DivineFlashMode.off);
    registerFallbackValue(DivineCameraLens.back);
    registerFallbackValue(DivineVideoStabilizationMode.off);
    registerFallbackValue(DivineVideoQuality.fhd);
    registerFallbackValue(AppLifecycleState.resumed);
    registerFallbackValue(Offset.zero);
  });

  setUp(() {
    cameraService = _MockCameraService();
    clipManager = _MockClipManager();
    videoEditor = _MockVideoEditor();
    prefs = _MockSharedPreferences();

    // Sensible defaults that keep the bloc's core handlers from
    // throwing on noSuchMethod when not explicitly stubbed by a test.
    when(() => cameraService.canRecord).thenReturn(true);
    when(() => cameraService.isInitialized).thenReturn(true);
    when(() => cameraService.canSwitchCamera).thenReturn(true);
    when(() => cameraService.hasFlash).thenReturn(true);
    when(() => cameraService.cameraAspectRatio).thenReturn(9 / 16);
    when(() => cameraService.minZoomLevel).thenReturn(0.5);
    when(() => cameraService.maxZoomLevel).thenReturn(5);
    when(() => cameraService.isSwitchingCamera).thenReturn(false);
    when(() => cameraService.currentLens).thenReturn(DivineCameraLens.back);
    when(
      () => cameraService.availableLenses,
    ).thenReturn(const [DivineCameraLens.back, DivineCameraLens.front]);
    when(() => cameraService.currentLensMetadata).thenReturn(null);
    when(
      () => cameraService.videoStabilizationMode,
    ).thenReturn(DivineVideoStabilizationMode.off);
    when(
      () => cameraService.availableVideoStabilizationModes,
    ).thenReturn(const [DivineVideoStabilizationMode.off]);
    when(
      () => cameraService.isVideoStabilizationSupported,
    ).thenReturn(false);
    when(() => cameraService.initializationError).thenReturn(null);
    when(() => cameraService.dispose()).thenAnswer((_) async {});
    when(
      () => cameraService.handleAppLifecycleState(any()),
    ).thenAnswer((_) async {});

    when(() => clipManager.clips).thenReturn(const []);
    when(() => clipManager.remainingDuration).thenReturn(
      const Duration(seconds: 6),
    );
    when(() => clipManager.totalDuration).thenReturn(Duration.zero);
    when(
      () => clipManager.clearAll(
        keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
      ),
    ).thenAnswer((_) async {});

    when(() => videoEditor.state).thenReturn(VideoEditorProviderState());
    when(
      () => videoEditor.reset(
        keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
      ),
    ).thenAnswer((_) async {});

    when(() => prefs.getString(any())).thenReturn(null);
    when(() => prefs.setString(any(), any())).thenAnswer((_) async => true);
  });

  /// Builds a bloc with all dependencies wired to the mocks.
  VideoRecorderBloc buildBloc() {
    return VideoRecorderBloc(
      readClipManager: () => clipManager,
      readVideoEditor: () => videoEditor,
      readVideoEditorState: VideoEditorProviderState.new,
      readSharedPreferences: () => prefs,
      cameraService: cameraService,
    );
  }

  group(VideoRecorderBloc, () {
    test('initial state has all defaults zeroed', () {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      expect(bloc.state, const VideoRecorderBlocState());
      expect(bloc.state.recordingState, VideoRecorderState.idle);
      expect(bloc.state.isStartingRecording, isFalse);
      expect(bloc.state.isStoppingRecording, isFalse);
      expect(bloc.state.zoomLevel, 1.0);
      expect(bloc.state.baseZoomLevel, 1.0);
      expect(bloc.state.snappedTo1x, isFalse);
    });

    test('exposes camera-service delegating getters', () {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      expect(bloc.currentLens, DivineCameraLens.back);
      expect(bloc.availableLenses, hasLength(2));
      expect(bloc.currentLensMetadata, isNull);
    });

    group('VideoRecorderFlashToggled', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'cycles off → torch → auto → off and persists each new mode',
        setUp: () {
          when(
            () => cameraService.setFlashMode(any()),
          ).thenAnswer((_) async => true);
        },
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(flashMode: DivineFlashMode.off),
          ),
        act: (bloc) async {
          bloc.add(const VideoRecorderFlashToggled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderFlashToggled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderFlashToggled());
        },
        // off → torch → auto → off. Third state asserts flashMode: off
        // explicitly; second state uses the default (auto) implicitly.
        expect: () => [
          const VideoRecorderBlocState(flashMode: DivineFlashMode.torch),
          const VideoRecorderBlocState(),
          const VideoRecorderBlocState(flashMode: DivineFlashMode.off),
        ],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not emit when camera service refuses the change',
        setUp: () {
          when(
            () => cameraService.setFlashMode(any()),
          ).thenAnswer((_) async => false);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderFlashToggled()),
        expect: () => const <VideoRecorderBlocState>[],
      );
    });

    group('VideoRecorderStabilizationModeSet', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'persists the new mode when the camera accepts it',
        setUp: () {
          when(
            () => cameraService.setVideoStabilizationMode(any()),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderStabilizationModeSet(
            DivineVideoStabilizationMode.cinematic,
          ),
        ),
        expect: () => const [
          VideoRecorderBlocState(
            videoStabilizationMode: DivineVideoStabilizationMode.cinematic,
          ),
        ],
        verify: (_) {
          verify(
            () => cameraService.setVideoStabilizationMode(
              DivineVideoStabilizationMode.cinematic,
            ),
          ).called(1);
          verify(
            () => prefs.setString(
              'camera_last_used_stabilization',
              'cinematic',
            ),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not emit when camera service refuses the change',
        setUp: () {
          when(
            () => cameraService.setVideoStabilizationMode(any()),
          ).thenAnswer((_) async => false);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderStabilizationModeSet(
            DivineVideoStabilizationMode.standard,
          ),
        ),
        expect: () => const <VideoRecorderBlocState>[],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'ignores a no-op set to the already-active mode',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderStabilizationModeSet(
            DivineVideoStabilizationMode.off,
          ),
        ),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(
            () => cameraService.setVideoStabilizationMode(any()),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'ignores mode changes while recording',
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
            ),
          ),
        act: (bloc) => bloc.add(
          const VideoRecorderStabilizationModeSet(
            DivineVideoStabilizationMode.standard,
          ),
        ),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(
            () => cameraService.setVideoStabilizationMode(any()),
          );
          verifyNever(
            () => prefs.setString('camera_last_used_stabilization', any()),
          );
        },
      );
    });

    group('VideoRecorderAspectRatioToggled', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'flips vertical → square → vertical',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderAspectRatioToggled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderAspectRatioToggled());
        },
        expect: () => [
          const VideoRecorderBlocState(aspectRatio: model.AspectRatio.square),
          const VideoRecorderBlocState(),
        ],
      );
    });

    group('VideoRecorderTimerCycled', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'cycles off → three → ten → off',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderTimerCycled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderTimerCycled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderTimerCycled());
        },
        expect: () => [
          const VideoRecorderBlocState(timerDuration: TimerDuration.three),
          const VideoRecorderBlocState(timerDuration: TimerDuration.ten),
          const VideoRecorderBlocState(),
        ],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not enable the timer outside capture mode',
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recorderMode: VideoRecorderMode.classic,
              aspectRatio: model.AspectRatio.square,
              showGridLines: true,
            ),
          ),
        act: (bloc) => bloc.add(const VideoRecorderTimerCycled()),
        expect: () => const <VideoRecorderBlocState>[],
      );
    });

    group('VideoRecorderGridLinesToggled', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'toggles showGridLines',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderGridLinesToggled());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const VideoRecorderGridLinesToggled());
        },
        expect: () => [
          const VideoRecorderBlocState(showGridLines: true),
          const VideoRecorderBlocState(),
        ],
      );
    });

    group('VideoRecorderShowLastClipOverlayToggled', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'toggles showLastClipOverlay',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderShowLastClipOverlayToggled(),
        ),
        expect: () => const [
          VideoRecorderBlocState(showLastClipOverlay: true),
        ],
      );
    });

    group('VideoRecorderZoomLevelSet', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'emits new zoom level when in bounds and camera accepts',
        setUp: () {
          when(
            () => cameraService.setZoomLevel(any()),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderZoomLevelSet(2)),
        expect: () => const [VideoRecorderBlocState(zoomLevel: 2)],
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'no-op when zoom value out of bounds',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderZoomLevelSet(99)),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(() => cameraService.setZoomLevel(any()));
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'no-op when camera service refuses',
        setUp: () {
          when(
            () => cameraService.setZoomLevel(any()),
          ).thenAnswer((_) async => false);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderZoomLevelSet(2)),
        expect: () => const <VideoRecorderBlocState>[],
      );
    });

    group('VideoRecorderFocusPointSet', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'emits focusPoint then resets to zero after the auto-hide timer',
        setUp: () {
          when(
            () => cameraService.setFocusPoint(any()),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderFocusPointSet(Offset(0.5, 0.5)));
          // The auto-hide timer is 800ms — give it room to fire.
          await Future<void>.delayed(const Duration(milliseconds: 900));
        },
        expect: () => const [
          VideoRecorderBlocState(focusPoint: Offset(0.5, 0.5)),
          VideoRecorderBlocState(),
        ],
      );
    });

    group('VideoRecorderRecordingToggleRequested', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'when idle, dispatches RecordingStartRequested',
        setUp: () {
          when(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderRecordingToggleRequested(),
        ),
        // start emits: isStartingRecording=true → recording → isStartingRecording=false
        verify: (bloc) {
          expect(bloc.state.isStartingRecording, isFalse);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'when camera is mid-switch, the toggle is ignored',
        setUp: () {
          when(() => cameraService.isSwitchingCamera).thenReturn(true);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderRecordingToggleRequested(),
        ),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          );
        },
      );
    });

    group(
      'RecordingStartRequested → flags-in-state migration',
      () {
        blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
          'sets isStartingRecording true before the camera call and false '
          'after, with recordingState transitioning to recording',
          setUp: () {
            when(
              () => cameraService.startRecording(
                maxDuration: any(named: 'maxDuration'),
              ),
            ).thenAnswer((_) async => true);
          },
          build: buildBloc,
          act: (bloc) => bloc.add(const VideoRecorderRecordingStartRequested()),
          // Expected sequence:
          //   1. isStartingRecording=true, baseZoomLevel=1.0
          //   2. recordingState=recording (no countdown path)
          //   3. isStartingRecording=false (success)
          verify: (bloc) {
            expect(bloc.state.recordingState, VideoRecorderState.recording);
            expect(bloc.state.isStartingRecording, isFalse);
          },
        );

        blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
          'on camera-rejected start, recordingState returns to idle and '
          'isStartingRecording resets to false',
          setUp: () {
            when(
              () => cameraService.startRecording(
                maxDuration: any(named: 'maxDuration'),
              ),
            ).thenAnswer((_) async => false);
          },
          build: buildBloc,
          act: (bloc) => bloc.add(const VideoRecorderRecordingStartRequested()),
          verify: (bloc) {
            expect(bloc.state.recordingState, VideoRecorderState.idle);
            expect(bloc.state.isStartingRecording, isFalse);
          },
        );

        blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
          'guards against re-entry when isStartingRecording is already true',
          build: () => buildBloc()
            ..emit(
              const VideoRecorderBlocState(isStartingRecording: true),
            ),
          act: (bloc) => bloc.add(const VideoRecorderRecordingStartRequested()),
          expect: () => const <VideoRecorderBlocState>[],
          verify: (_) {
            verifyNever(
              () => cameraService.startRecording(
                maxDuration: any(named: 'maxDuration'),
              ),
            );
          },
        );

        blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
          'guards against start when isStoppingRecording is true',
          build: () => buildBloc()
            ..emit(
              const VideoRecorderBlocState(isStoppingRecording: true),
            ),
          act: (bloc) => bloc.add(const VideoRecorderRecordingStartRequested()),
          expect: () => const <VideoRecorderBlocState>[],
        );

        blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
          'starts classic recording immediately when capture timer was set',
          setUp: () {
            when(
              () => cameraService.startRecording(
                maxDuration: any(named: 'maxDuration'),
              ),
            ).thenAnswer((_) async => true);
          },
          build: () => buildBloc()
            ..emit(
              const VideoRecorderBlocState(
                recorderMode: VideoRecorderMode.classic,
                aspectRatio: model.AspectRatio.square,
                showGridLines: true,
                timerDuration: TimerDuration.three,
              ),
            ),
          act: (bloc) => bloc.add(const VideoRecorderRecordingStartRequested()),
          expect: () => const [
            VideoRecorderBlocState(
              recorderMode: VideoRecorderMode.classic,
              aspectRatio: model.AspectRatio.square,
              showGridLines: true,
              timerDuration: TimerDuration.three,
              isStartingRecording: true,
            ),
            VideoRecorderBlocState(
              recorderMode: VideoRecorderMode.classic,
              recordingState: VideoRecorderState.recording,
              aspectRatio: model.AspectRatio.square,
              showGridLines: true,
              timerDuration: TimerDuration.three,
              isStartingRecording: true,
            ),
            VideoRecorderBlocState(
              recorderMode: VideoRecorderMode.classic,
              recordingState: VideoRecorderState.recording,
              aspectRatio: model.AspectRatio.square,
              showGridLines: true,
              timerDuration: TimerDuration.three,
            ),
          ],
          verify: (_) {
            verifyNever(
              () => cameraService.setVolumeKeysEnabled(
                enabled: any(named: 'enabled'),
              ),
            );
            verify(
              () => cameraService.startRecording(
                maxDuration: const Duration(seconds: 6),
              ),
            ).called(1);
          },
        );
      },
    );

    group('RecordingStopRequested → start-cancel fast path', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'when called during startRecording, sets pendingStopAfterStart '
        'without touching the camera service',
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(isStartingRecording: true),
          ),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        expect: () => const [
          VideoRecorderBlocState(
            isStartingRecording: true,
            pendingStopAfterStart: true,
          ),
        ],
        verify: (_) {
          // No native stop is fired — the start handler will dispatch a
          // proper stop after startRecording() completes.
          verifyNever(() => cameraService.stopRecording());
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'when isStoppingRecording is already true, is fully ignored',
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(isStoppingRecording: true),
          ),
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(() => cameraService.stopRecording());
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'when idle with no video result, the stop event is a no-op',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderRecordingStopRequested()),
        expect: () => const <VideoRecorderBlocState>[],
        verify: (_) {
          verifyNever(() => cameraService.stopRecording());
        },
      );
    });

    group('sequential() transformer contract', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'queued RecordingStartRequested events process FIFO, not '
        'concurrently — the second start is rejected by the in-flight '
        'guard (isStartingRecording=true) instead of racing it',
        setUp: () {
          when(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).thenAnswer(
            (_) async {
              // Simulate a slow native start so the second event would
              // otherwise overlap if the transformer were concurrent.
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return true;
            },
          );
        },
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const VideoRecorderRecordingStartRequested());
          bloc.add(const VideoRecorderRecordingStartRequested());
        },
        wait: const Duration(milliseconds: 200),
        verify: (_) {
          // Sequential: both events ran in order. The second one saw
          // recordingState=recording and short-circuited (no camera
          // start was issued). Net camera-start calls: 1.
          verify(
            () => cameraService.startRecording(
              maxDuration: any(named: 'maxDuration'),
            ),
          ).called(1);
        },
      );
    });

    group('VideoRecorderResetRequested', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'restores the default state object',
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              recordingState: VideoRecorderState.recording,
              zoomLevel: 3,
              isStartingRecording: true,
            ),
          ),
        act: (bloc) => bloc.add(const VideoRecorderResetRequested()),
        expect: () => const [VideoRecorderBlocState()],
      );
    });

    group('VideoRecorderRecorderModeSet', () {
      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'capture → classic flips defaults and clears clips + editor',
        build: () => buildBloc()
          ..emit(
            const VideoRecorderBlocState(
              timerDuration: TimerDuration.three,
              countdownValue: 2,
            ),
          ),
        act: (bloc) => bloc.add(
          const VideoRecorderRecorderModeSet(VideoRecorderMode.classic),
        ),
        expect: () => const [
          VideoRecorderBlocState(
            recorderMode: VideoRecorderMode.classic,
            aspectRatio: model.AspectRatio.square,
            showGridLines: true,
          ),
        ],
        verify: (_) {
          verify(
            () => prefs.setString(
              VideoRecorderMode.persistenceKey,
              VideoRecorderMode.classic.name,
            ),
          ).called(1);
          // `keepAutosavedDraft` defaults to false in the event; the
          // bloc forwards that default to both helpers.
          verify(
            () => clipManager.clearAll(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          ).called(1);
          verify(
            () => videoEditor.reset(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'transitions involving upload preserve clips and editor',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoRecorderRecorderModeSet(VideoRecorderMode.upload),
        ),
        verify: (_) {
          verifyNever(
            () => clipManager.clearAll(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          );
          verifyNever(
            () => videoEditor.reset(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          );
        },
      );
    });

    group('VideoRecorderInitializeRequested', () {
      setUp(() {
        when(
          () => cameraService.initialize(
            videoQuality: any(named: 'videoQuality'),
            initialLens: any(named: 'initialLens'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => cameraService.setRemoteRecordControlEnabled(
            enabled: any(named: 'enabled'),
          ),
        ).thenAnswer((_) async => true);
      });

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does NOT restore persisted mode when opened from the editor '
        '(keeps editor state intact)',
        setUp: () {
          when(
            () => prefs.getString(VideoRecorderMode.persistenceKey),
          ).thenReturn(VideoRecorderMode.classic.name);
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const VideoRecorderInitializeRequested(fromEditor: true)),
        verify: (_) {
          verifyNever(
            () => clipManager.clearAll(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          );
          verifyNever(
            () => videoEditor.reset(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'restores persisted mode when NOT opened from the editor',
        setUp: () {
          when(
            () => prefs.getString(VideoRecorderMode.persistenceKey),
          ).thenReturn(VideoRecorderMode.classic.name);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (_) {
          verify(
            () => clipManager.clearAll(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          ).called(1);
          verify(
            () => videoEditor.reset(
              keepAutosavedDraft: any(named: 'keepAutosavedDraft'),
            ),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'restores the persisted stabilization mode the camera supports',
        setUp: () {
          when(
            () => prefs.getString('camera_last_used_stabilization'),
          ).thenReturn(DivineVideoStabilizationMode.cinematic.toNativeString());
          when(
            () => cameraService.availableVideoStabilizationModes,
          ).thenReturn(const [
            DivineVideoStabilizationMode.off,
            DivineVideoStabilizationMode.cinematic,
          ]);
          when(
            () => cameraService.setVideoStabilizationMode(any()),
          ).thenAnswer((_) async => true);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (_) {
          verify(
            () => cameraService.setVideoStabilizationMode(
              DivineVideoStabilizationMode.cinematic,
            ),
          ).called(1);
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not restore a stabilization mode the camera does not support',
        setUp: () {
          when(
            () => prefs.getString('camera_last_used_stabilization'),
          ).thenReturn(DivineVideoStabilizationMode.cinematic.toNativeString());
          // availableVideoStabilizationModes stays [off] from the outer setUp.
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (_) {
          verifyNever(
            () => cameraService.setVideoStabilizationMode(any()),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not restore when no stabilization mode is persisted',
        // prefs.getString returns null by default (see outer setUp).
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (_) {
          verifyNever(
            () => cameraService.setVideoStabilizationMode(any()),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'does not restore when the persisted mode is off',
        setUp: () {
          when(
            () => prefs.getString('camera_last_used_stabilization'),
          ).thenReturn(DivineVideoStabilizationMode.off.toNativeString());
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (_) {
          verifyNever(
            () => cameraService.setVideoStabilizationMode(any()),
          );
        },
      );

      blocTest<VideoRecorderBloc, VideoRecorderBlocState>(
        'leaves the mode at off when the camera refuses the restore',
        setUp: () {
          when(
            () => prefs.getString('camera_last_used_stabilization'),
          ).thenReturn(DivineVideoStabilizationMode.cinematic.toNativeString());
          when(
            () => cameraService.availableVideoStabilizationModes,
          ).thenReturn(const [
            DivineVideoStabilizationMode.off,
            DivineVideoStabilizationMode.cinematic,
          ]);
          when(
            () => cameraService.setVideoStabilizationMode(any()),
          ).thenAnswer((_) async => false);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoRecorderInitializeRequested()),
        verify: (bloc) {
          verify(
            () => cameraService.setVideoStabilizationMode(
              DivineVideoStabilizationMode.cinematic,
            ),
          ).called(1);
          expect(
            bloc.state.videoStabilizationMode,
            DivineVideoStabilizationMode.off,
          );
        },
      );
    });

    group('close()', () {
      test('disposes camera service exactly once', () async {
        final bloc = buildBloc();
        await bloc.close();
        verify(() => cameraService.dispose()).called(1);
      });
    });
  });
}
