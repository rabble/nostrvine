// ABOUTME: Unit tests for VideoRecorderProviderState and VideoRecorderNotifier
// ABOUTME: Tests state getters, properties, and recording lifecycle

@Tags(['skip_very_good_optimization'])
import 'dart:io';

import 'package:divine_camera/divine_camera.dart'
    show DivineCameraLens, DivineVideoQuality;
import 'package:flutter/material.dart' hide AspectRatio;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mock_camera_service.dart';

class _MockDraftStorageService extends Mock implements DraftStorageService {}

/// Helper to set up haptic feedback mock and track calls.
class HapticFeedbackTracker {
  final List<String> hapticCalls = [];

  void setUp(TestWidgetsFlutterBinding binding) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          hapticCalls.add(call.arguments as String);
        }
        return null;
      },
    );
  }

  void tearDown(TestWidgetsFlutterBinding binding) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  }

  void clear() => hapticCalls.clear();
}

/// Mock [ProVideoEditor] that returns canned metadata.
class _MockProVideoEditor extends ProVideoEditor {
  @override
  void initializeStream() {
    // Intentional no-op: testing stub.
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    return VideoMetadata(
      duration: const Duration(seconds: 3),
      extension: 'mp4',
      fileSize: 1024000,
      resolution: const Size(1920, 1080),
      rotation: 0,
      bitrate: 3000000,
    );
  }
}

/// Spy [GallerySaveService] that records whether [saveVideoToGallery] was
/// called.
class _SpyGallerySaveService implements GallerySaveService {
  bool saveVideoToGalleryCalled = false;

  @override
  Future<GallerySaveResult> saveVideoToGallery(
    EditorVideo video, {
    AspectRatio? aspectRatio,
    String albumName = 'Divine',
    VideoMetadata? metadata,
  }) async {
    saveVideoToGalleryCalled = true;
    return const GallerySaveSuccess();
  }
}

class _SpyCameraService extends MockCameraService {
  _SpyCameraService.create({
    required super.onUpdateState,
    required super.onAutoStopped,
  }) : super.create();

  int initializeCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> initialize({
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    DivineCameraLens initialLens = DivineCameraLens.front,
    bool enableAutoLensSwitch = false,
  }) async {
    initializeCalls++;
    await super.initialize(
      videoQuality: videoQuality,
      initialLens: initialLens,
      enableAutoLensSwitch: enableAutoLensSwitch,
    );
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await super.dispose();
  }
}

/// Shared test setup for VideoRecorderNotifier tests.
class NotifierTestSetup {
  late MockCameraService mockCamera;
  late ProviderContainer container;
  late SharedPreferences sharedPreferences;

  Future<void> setUp() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();

    mockCamera = MockCameraService.create(
      onUpdateState: ({forceCameraRebuild}) {},
      onAutoStopped: (_) {},
    );
    await mockCamera.initialize();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        videoRecorderProvider.overrideWith(
          () => VideoRecorderNotifier(mockCamera),
        ),
      ],
    );

    await container.read(videoRecorderProvider.notifier).initialize();
  }

  void tearDown() {
    container.dispose();
  }
}

void main() {
  group('VideoRecorderUIState AspectRatio', () {
    test('includes aspectRatio in state', () {
      const state = VideoRecorderProviderState();

      expect(state.aspectRatio, equals(AspectRatio.vertical));
    });

    test('default aspectRatio is vertical', () {
      const state = VideoRecorderProviderState();

      expect(state.aspectRatio, equals(AspectRatio.vertical));
    });

    test('copyWith updates aspectRatio', () {
      const state = VideoRecorderProviderState(aspectRatio: AspectRatio.square);

      final updated = state.copyWith(aspectRatio: AspectRatio.vertical);
      expect(updated.aspectRatio, equals(AspectRatio.vertical));
    });

    test('copyWith preserves aspectRatio when not provided', () {
      const state = VideoRecorderProviderState(aspectRatio: AspectRatio.square);

      final updated = state.copyWith(canRecord: true);
      expect(updated.aspectRatio, equals(AspectRatio.square));
    });

    test('all AspectRatio values can be used', () {
      const squareState = VideoRecorderProviderState(
        aspectRatio: AspectRatio.square,
      );
      expect(squareState.aspectRatio, equals(AspectRatio.square));

      const verticalState = VideoRecorderProviderState();
      expect(verticalState.aspectRatio, equals(AspectRatio.vertical));
    });
  });

  group('VideoRecorderUIState Tests', () {
    test('isRecording getter should match recording state', () {
      const recordingState = VideoRecorderProviderState(
        recordingState: VideoRecorderState.recording,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      const idleState = VideoRecorderProviderState(
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(recordingState.isRecording, isTrue);
      expect(idleState.isRecording, isFalse);
    });

    test('isInitialized should require camera initialization', () {
      const initializedState = VideoRecorderProviderState(
        isCameraInitialized: true,
        canRecord: true,
        aspectRatio: AspectRatio.square,
      );

      const uninitializedState = VideoRecorderProviderState(
        aspectRatio: AspectRatio.square,
      );

      expect(initializedState.isInitialized, isTrue);
      expect(uninitializedState.isInitialized, isFalse);
    });

    test('isInitialized should be false during error state', () {
      const errorState = VideoRecorderProviderState(
        recordingState: VideoRecorderState.error,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(errorState.isInitialized, isFalse);
    });

    test('isError getter should detect error state', () {
      const errorState = VideoRecorderProviderState(
        recordingState: VideoRecorderState.error,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      const idleState = VideoRecorderProviderState(
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(errorState.isError, isTrue);
      expect(idleState.isError, isFalse);
    });

    test('errorMessage should be non-null only in error state', () {
      const errorState = VideoRecorderProviderState(
        recordingState: VideoRecorderState.error,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      const idleState = VideoRecorderProviderState(
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(errorState.errorMessage, isNotNull);
      expect(idleState.errorMessage, isNull);
    });

    test('canRecord should reflect ability to start recording', () {
      const canRecordState = VideoRecorderProviderState(
        canRecord: true,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      const cannotRecordState = VideoRecorderProviderState(
        recordingState: VideoRecorderState.recording,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(canRecordState.canRecord, isTrue);
      expect(cannotRecordState.canRecord, isFalse);
    });

    test('zoomLevel should be customizable', () {
      const defaultZoom = VideoRecorderProviderState(
        aspectRatio: AspectRatio.square,
      );

      const customZoom = VideoRecorderProviderState(
        zoomLevel: 2.5,
        aspectRatio: AspectRatio.square,
      );

      expect(defaultZoom.zoomLevel, equals(1.0));
      expect(customZoom.zoomLevel, equals(2.5));
    });

    test('focusPoint should be settable', () {
      const defaultFocus = VideoRecorderProviderState(
        aspectRatio: AspectRatio.square,
      );

      const customFocus = VideoRecorderProviderState(
        focusPoint: Offset(0.5, 0.5),
        aspectRatio: AspectRatio.square,
      );

      expect(defaultFocus.focusPoint, equals(Offset.zero));
      expect(customFocus.focusPoint, equals(const Offset(0.5, 0.5)));
    });

    test('aspectRatio should be customizable', () {
      const squareState = VideoRecorderProviderState(
        aspectRatio: AspectRatio.square,
      );

      const verticalState = VideoRecorderProviderState();

      expect(squareState.aspectRatio, equals(AspectRatio.square));
      expect(verticalState.aspectRatio, equals(AspectRatio.vertical));
    });

    test('flashMode should be customizable', () {
      const autoFlash = VideoRecorderProviderState(
        aspectRatio: AspectRatio.square,
      );

      const torchFlash = VideoRecorderProviderState(
        flashMode: DivineFlashMode.torch,
        aspectRatio: AspectRatio.square,
      );

      const offFlash = VideoRecorderProviderState(
        flashMode: DivineFlashMode.off,
        aspectRatio: AspectRatio.square,
      );

      expect(autoFlash.flashMode, equals(DivineFlashMode.auto));
      expect(torchFlash.flashMode, equals(DivineFlashMode.torch));
      expect(offFlash.flashMode, equals(DivineFlashMode.off));
    });

    test('timerDuration should be customizable', () {
      const offTimer = VideoRecorderProviderState(
        aspectRatio: AspectRatio.square,
      );

      const threeSecTimer = VideoRecorderProviderState(
        timerDuration: TimerDuration.three,
        aspectRatio: AspectRatio.square,
      );

      const tenSecTimer = VideoRecorderProviderState(
        timerDuration: TimerDuration.ten,
        aspectRatio: AspectRatio.square,
      );

      expect(offTimer.timerDuration, equals(TimerDuration.off));
      expect(threeSecTimer.timerDuration, equals(TimerDuration.three));
      expect(tenSecTimer.timerDuration, equals(TimerDuration.ten));
    });

    test('countdownValue should be settable', () {
      const noCountdown = VideoRecorderProviderState(
        aspectRatio: AspectRatio.square,
      );

      const countingDown = VideoRecorderProviderState(
        countdownValue: 3,
        aspectRatio: AspectRatio.square,
      );

      expect(noCountdown.countdownValue, equals(0));
      expect(countingDown.countdownValue, equals(3));
    });

    test('copyWith should update specific fields', () {
      const initialState = VideoRecorderProviderState(
        canRecord: true,
        aspectRatio: AspectRatio.square,
      );

      final updatedState = initialState.copyWith(
        recordingState: VideoRecorderState.recording,
        zoomLevel: 2.0,
      );

      expect(updatedState.recordingState, VideoRecorderState.recording);
      expect(updatedState.zoomLevel, 2.0);
      expect(updatedState.canRecord, true); // Preserved
      expect(updatedState.aspectRatio, AspectRatio.square); // Preserved
    });

    test('canSwitchCamera should be configurable', () {
      const canSwitch = VideoRecorderProviderState(
        aspectRatio: AspectRatio.square,
      );

      const cannotSwitch = VideoRecorderProviderState(
        canSwitchCamera: false,
        aspectRatio: AspectRatio.square,
      );

      expect(canSwitch.canSwitchCamera, isTrue);
      expect(cannotSwitch.canSwitchCamera, isFalse);
    });

    test('default state should have sensible values', () {
      const state = VideoRecorderProviderState();

      expect(state.recordingState, VideoRecorderState.idle);
      expect(state.zoomLevel, 1.0);
      expect(state.cameraSensorAspectRatio, 1.0);
      expect(state.focusPoint, Offset.zero);
      expect(state.canRecord, false);
      expect(state.isCameraInitialized, false);
      expect(state.canSwitchCamera, true);
      expect(state.countdownValue, 0);
      expect(state.aspectRatio, AspectRatio.vertical);
      expect(state.flashMode, DivineFlashMode.auto);
      expect(state.timerDuration, TimerDuration.off);
    });
  });

  group('VideoRecorderNotifier - Concurrent Stop Handling', () {
    final setup = NotifierTestSetup();

    setUp(setup.setUp);
    tearDown(setup.tearDown);

    test(
      'multiple simultaneous stopRecording calls do not cause errors',
      () async {
        final notifier = setup.container.read(videoRecorderProvider.notifier);

        // Start recording
        await notifier.startRecording();

        // Verify recording started
        expect(
          setup.container.read(videoRecorderProvider).recordingState,
          VideoRecorderState.recording,
        );

        // Fire multiple stop calls simultaneously
        final stopFutures = [
          notifier.stopRecording(),
          notifier.stopRecording(),
          notifier.stopRecording(),
        ];

        // All should complete without throwing
        await expectLater(Future.wait(stopFutures), completes);

        // State should be idle after stopping
        expect(
          setup.container.read(videoRecorderProvider).recordingState,
          VideoRecorderState.idle,
        );
      },
    );

    test(
      'startRecording is blocked while stopRecording is in progress',
      () async {
        final notifier = setup.container.read(videoRecorderProvider.notifier);

        // Start recording
        await notifier.startRecording();
        expect(
          setup.container.read(videoRecorderProvider).recordingState,
          VideoRecorderState.recording,
        );

        // Begin stopping (don't await yet)
        final stopFuture = notifier.stopRecording();

        // Try to start recording while stop is in progress
        // This should be blocked by _isStoppingRecording flag
        await notifier.startRecording();

        // Wait for stop to complete
        await stopFuture;

        // State should be idle (start was blocked)
        expect(
          setup.container.read(videoRecorderProvider).recordingState,
          VideoRecorderState.idle,
        );
      },
    );
  });

  group('VideoRecorderNotifier - Recording Lifecycle', () {
    final setup = NotifierTestSetup();

    setUp(setup.setUp);
    tearDown(setup.tearDown);

    test('can start and stop recording normally', () async {
      final notifier = setup.container.read(videoRecorderProvider.notifier);

      // Start recording
      await notifier.startRecording();
      expect(
        setup.container.read(videoRecorderProvider).recordingState,
        VideoRecorderState.recording,
      );

      // Stop recording
      await notifier.stopRecording();
      expect(
        setup.container.read(videoRecorderProvider).recordingState,
        VideoRecorderState.idle,
      );
    });

    test('stopRecording without starting does nothing', () async {
      final notifier = setup.container.read(videoRecorderProvider.notifier);

      // Try to stop when not recording
      await notifier.stopRecording();

      // State should remain idle
      expect(
        setup.container.read(videoRecorderProvider).recordingState,
        VideoRecorderState.idle,
      );
    });

    test('toggleRecording starts when idle and stops when recording', () async {
      final notifier = setup.container.read(videoRecorderProvider.notifier);

      // Toggle to start
      await notifier.toggleRecording();
      expect(
        setup.container.read(videoRecorderProvider).recordingState,
        VideoRecorderState.recording,
      );

      // Toggle to stop
      await notifier.toggleRecording();
      expect(
        setup.container.read(videoRecorderProvider).recordingState,
        VideoRecorderState.idle,
      );
    });
  });

  group('VideoRecorderNotifier - Haptic Feedback', () {
    late NotifierTestSetup setup;
    late HapticFeedbackTracker hapticTracker;
    late TestWidgetsFlutterBinding binding;

    setUp(() async {
      binding = TestWidgetsFlutterBinding.ensureInitialized();
      hapticTracker = HapticFeedbackTracker()..setUp(binding);
      setup = NotifierTestSetup();
      await setup.setUp();
    });

    tearDown(() {
      hapticTracker.tearDown(binding);
      setup.tearDown();
    });

    test('startRecording triggers lightImpact haptic feedback', () async {
      final notifier = setup.container.read(videoRecorderProvider.notifier);
      hapticTracker.clear();

      await notifier.startRecording();

      expect(
        hapticTracker.hapticCalls,
        contains('HapticFeedbackType.lightImpact'),
      );
    });

    test('stopRecording triggers lightImpact haptic feedback', () async {
      final notifier = setup.container.read(videoRecorderProvider.notifier);

      // First start recording
      await notifier.startRecording();
      expect(
        setup.container.read(videoRecorderProvider).recordingState,
        VideoRecorderState.recording,
      );

      hapticTracker.clear();

      // Stop recording and check haptic
      await notifier.stopRecording();

      expect(
        hapticTracker.hapticCalls,
        contains('HapticFeedbackType.lightImpact'),
      );
    });

    test('haptic feedback not triggered when recording is blocked', () async {
      final notifier = setup.container.read(videoRecorderProvider.notifier);

      // Start recording first
      await notifier.startRecording();
      hapticTracker.clear();

      // Try to start again while already recording - should be blocked
      await notifier.startRecording();

      // No additional haptic because the call was blocked
      expect(
        hapticTracker.hapticCalls
            .where((c) => c == 'HapticFeedbackType.lightImpact')
            .length,
        equals(0),
      );

      // Cleanup
      await notifier.stopRecording();
    });
  });

  group('Camera Lens Persistence', () {
    test('setLens saves lens preference to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          videoRecorderProvider.overrideWith(
            () => VideoRecorderNotifier(mockCamera),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(videoRecorderProvider.notifier).initialize();

      // Set lens to back camera
      await container
          .read(videoRecorderProvider.notifier)
          .setLens(DivineCameraLens.back);

      // Verify preference was saved
      expect(prefs.getString('camera_last_used_lens'), equals('back'));
    });

    test(
      'switchCamera saves new lens preference to SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final mockCamera = MockCameraService.create(
          onUpdateState: ({forceCameraRebuild}) {},
          onAutoStopped: (_) {},
        );
        await mockCamera.initialize();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            videoRecorderProvider.overrideWith(
              () => VideoRecorderNotifier(mockCamera),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(videoRecorderProvider.notifier).initialize();

        // Switch camera (front -> back)
        await container.read(videoRecorderProvider.notifier).switchCamera();

        // Verify preference was saved for the new lens
        expect(prefs.getString('camera_last_used_lens'), isNotNull);
      },
    );

    test('initialize restores saved lens preference', () async {
      // Pre-populate with back camera preference
      SharedPreferences.setMockInitialValues({'camera_last_used_lens': 'back'});
      final prefs = await SharedPreferences.getInstance();

      final mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          videoRecorderProvider.overrideWith(
            () => VideoRecorderNotifier(mockCamera),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(videoRecorderProvider.notifier).initialize();

      // Verify mock camera was initialized with saved lens
      expect(mockCamera.currentLens, equals(DivineCameraLens.back));
    });

    test('initialize uses front camera when no saved preference', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          videoRecorderProvider.overrideWith(
            () => VideoRecorderNotifier(mockCamera),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(videoRecorderProvider.notifier).initialize();

      // Verify mock camera was initialized with default front lens
      expect(mockCamera.currentLens, equals(DivineCameraLens.front));
    });
  });

  group('VideoRecorderNotifier - No Gallery Save on Recording', () {
    test('stopRecording does not call saveVideoToGallery', () async {
      // Regression test: saving to gallery during clip recording was
      // removed because it is not the responsibility of the recorder.
      // This test ensures it is never reintroduced.
      final mockEditor = _MockProVideoEditor();
      ProVideoEditor.instance = mockEditor;

      // Stub the divine_video_player platform channel so the preload
      // call inside stopRecording does not throw.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player'),
            (MethodCall call) async => null,
          );

      final spyGallerySave = _SpyGallerySaveService();

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          videoRecorderProvider.overrideWith(
            () => VideoRecorderNotifier(mockCamera),
          ),
          gallerySaveServiceProvider.overrideWith((ref) => spyGallerySave),
        ],
      );
      addTearDown(container.dispose);

      await container.read(videoRecorderProvider.notifier).initialize();
      final notifier = container.read(videoRecorderProvider.notifier);

      // Start recording first
      await notifier.startRecording();

      // Stop recording with a video result to exercise the full
      // post-recording code path (metadata extraction, clip creation,
      // thumbnail generation).
      // Use a real temp file so that the work-copy creation in
      // stopRecording can copy it.
      final tmpDir = await Directory.systemTemp.createTemp('rec_test');
      final tmpFile = File('${tmpDir.path}/test_video.mp4');
      await tmpFile.writeAsBytes([0]);
      addTearDown(() => tmpDir.delete(recursive: true));

      await notifier.stopRecording(EditorVideo.file(tmpFile.path));

      expect(spyGallerySave.saveVideoToGalleryCalled, isFalse);

      // Clean up the platform channel stub.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player'),
            null,
          );
    });
  });

  group('setRecorderMode', () {
    test('updates recorder mode and persists to shared preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockDraftStorage = _MockDraftStorageService();
      when(() => mockDraftStorage.deleteDraft(any())).thenAnswer((_) async {});

      final mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          videoRecorderProvider.overrideWith(
            () => VideoRecorderNotifier(mockCamera),
          ),
          draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
        ],
      );
      addTearDown(container.dispose);

      await container.read(videoRecorderProvider.notifier).initialize();
      final notifier = container.read(videoRecorderProvider.notifier);

      notifier.setRecorderMode(VideoRecorderMode.classic);

      final state = container.read(videoRecorderProvider);
      expect(state.recorderMode, equals(VideoRecorderMode.classic));

      final savedMode = prefs.getString(kLastUsedRecorderModeKey);
      expect(savedMode, equals('classic'));
    });

    test('switching to capture persists capture mode', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockDraftStorage = _MockDraftStorageService();
      when(() => mockDraftStorage.deleteDraft(any())).thenAnswer((_) async {});

      final mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          videoRecorderProvider.overrideWith(
            () => VideoRecorderNotifier(mockCamera),
          ),
          draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
        ],
      );
      addTearDown(container.dispose);

      await container.read(videoRecorderProvider.notifier).initialize();
      final notifier = container.read(videoRecorderProvider.notifier);

      // Switch to classic first, then back to capture
      notifier.setRecorderMode(VideoRecorderMode.classic);
      notifier.setRecorderMode(VideoRecorderMode.capture);

      final state = container.read(videoRecorderProvider);
      expect(state.recorderMode, equals(VideoRecorderMode.capture));

      final savedMode = prefs.getString(kLastUsedRecorderModeKey);
      expect(savedMode, equals('capture'));
    });

    test('updates aspect ratio to mode default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockDraftStorage = _MockDraftStorageService();
      when(() => mockDraftStorage.deleteDraft(any())).thenAnswer((_) async {});

      final mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          videoRecorderProvider.overrideWith(
            () => VideoRecorderNotifier(mockCamera),
          ),
          draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
        ],
      );
      addTearDown(container.dispose);

      await container.read(videoRecorderProvider.notifier).initialize();
      final notifier = container.read(videoRecorderProvider.notifier);

      notifier.setRecorderMode(VideoRecorderMode.classic);

      final state = container.read(videoRecorderProvider);
      expect(
        state.aspectRatio,
        equals(VideoRecorderMode.classic.defaultAspectRatio),
      );
    });

    test(
      'initialize restores saved mode with keepAutosavedDraft true',
      () async {
        // Simulate a previously saved "classic" mode in preferences
        SharedPreferences.setMockInitialValues({
          kLastUsedRecorderModeKey: 'classic',
        });
        final prefs = await SharedPreferences.getInstance();

        final mockCamera = MockCameraService.create(
          onUpdateState: ({forceCameraRebuild}) {},
          onAutoStopped: (_) {},
        );
        await mockCamera.initialize();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            videoRecorderProvider.overrideWith(
              () => VideoRecorderNotifier(mockCamera),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(videoRecorderProvider.notifier).initialize();

        // After initialize, the mode should be restored to classic
        final state = container.read(videoRecorderProvider);
        expect(state.recorderMode, equals(VideoRecorderMode.classic));
      },
    );
  });

  group('VideoRecorderNotifier - Work Copy Lifecycle', () {
    test('stopRecording cleans up work copy file', () async {
      final mockEditor = _MockProVideoEditor();
      ProVideoEditor.instance = mockEditor;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player'),
            (MethodCall call) async => null,
          );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          videoRecorderProvider.overrideWith(
            () => VideoRecorderNotifier(mockCamera),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(videoRecorderProvider.notifier).initialize();
      final notifier = container.read(videoRecorderProvider.notifier);

      final tmpDir = await Directory.systemTemp.createTemp('workcopy');
      final tmpFile = File('${tmpDir.path}/test_video.mp4');
      await tmpFile.writeAsBytes([0]);
      addTearDown(() => tmpDir.delete(recursive: true));

      await notifier.startRecording();
      await notifier.stopRecording(EditorVideo.file(tmpFile.path));

      // The .work.mp4 copy should be deleted after stopRecording.
      final workCopy = File('${tmpFile.path}.work.mp4');
      expect(workCopy.existsSync(), isFalse);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player'),
            null,
          );
    });

    test('stopRecording preserves original video file', () async {
      final mockEditor = _MockProVideoEditor();
      ProVideoEditor.instance = mockEditor;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player'),
            (MethodCall call) async => null,
          );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          videoRecorderProvider.overrideWith(
            () => VideoRecorderNotifier(mockCamera),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(videoRecorderProvider.notifier).initialize();
      final notifier = container.read(videoRecorderProvider.notifier);

      final tmpDir = await Directory.systemTemp.createTemp('preserve');
      final tmpFile = File('${tmpDir.path}/test_video.mp4');
      await tmpFile.writeAsBytes([0, 1, 2, 3]);
      addTearDown(() => tmpDir.delete(recursive: true));

      await notifier.startRecording();
      await notifier.stopRecording(EditorVideo.file(tmpFile.path));

      // The original file must still exist after the work copy flow.
      expect(tmpFile.existsSync(), isTrue);
      expect(tmpFile.lengthSync(), equals(4));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player'),
            null,
          );
    });
  });

  group('VideoRecorderNotifier - Library Navigation', () {
    testWidgets(
      'openLibrary navigates to clips-no-sound and reinitializes camera on return',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final spyCamera = _SpyCameraService.create(
          onUpdateState: ({forceCameraRebuild}) {},
          onAutoStopped: (_) {},
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            videoRecorderProvider.overrideWith(
              () => VideoRecorderNotifier(spyCamera),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(videoRecorderProvider.notifier).initialize();
        expect(spyCamera.initializeCalls, equals(1));
        expect(spyCamera.disposeCalls, equals(0));

        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      container
                          .read(videoRecorderProvider.notifier)
                          .openLibrary(context);
                    },
                    child: const Text('Open library'),
                  ),
                ),
              ),
            ),
            GoRoute(
              name: LibraryScreen.clipsNoSoundRouteName,
              path: LibraryScreen.clipsNoSoundPath,
              builder: (context, state) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: context.pop,
                    child: const Text('Close library'),
                  ),
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open library'));
        await tester.pumpAndSettle();

        expect(find.text('Close library'), findsOneWidget);
        expect(spyCamera.disposeCalls, equals(1));

        await tester.tap(find.text('Close library'));
        await tester.pumpAndSettle();

        expect(find.text('Open library'), findsOneWidget);
        expect(spyCamera.initializeCalls, equals(2));
      },
    );
  });
}
