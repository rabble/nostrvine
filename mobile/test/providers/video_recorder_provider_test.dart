// ABOUTME: Unit tests for VideoRecorderProviderState and VideoRecorderNotifier
// ABOUTME: Tests state getters, properties, and recording lifecycle

import 'package:divine_camera/divine_camera.dart' show DivineCameraLens;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mock_camera_service.dart';

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
}
