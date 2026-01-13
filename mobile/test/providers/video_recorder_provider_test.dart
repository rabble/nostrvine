// ABOUTME: Unit tests for VideoRecorderUIState behavior
// ABOUTME: Tests state getters and properties without requiring camera

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';

void main() {
  group('VideoRecorderUIState AspectRatio', () {
    test('includes aspectRatio in state', () {
      final state = VideoRecorderProviderState(
        aspectRatio: AspectRatio.vertical,
      );

      expect(state.aspectRatio, equals(AspectRatio.vertical));
    });

    test('default aspectRatio is vertical', () {
      final state = VideoRecorderProviderState();

      expect(state.aspectRatio, equals(AspectRatio.vertical));
    });

    test('copyWith updates aspectRatio', () {
      final state = VideoRecorderProviderState(aspectRatio: AspectRatio.square);

      final updated = state.copyWith(aspectRatio: AspectRatio.vertical);
      expect(updated.aspectRatio, equals(AspectRatio.vertical));
    });

    test('copyWith preserves aspectRatio when not provided', () {
      final state = VideoRecorderProviderState(aspectRatio: AspectRatio.square);

      final updated = state.copyWith(canRecord: true);
      expect(updated.aspectRatio, equals(AspectRatio.square));
    });

    test('all AspectRatio values can be used', () {
      final squareState = VideoRecorderProviderState(
        aspectRatio: AspectRatio.square,
      );
      expect(squareState.aspectRatio, equals(AspectRatio.square));

      final verticalState = VideoRecorderProviderState(
        aspectRatio: AspectRatio.vertical,
      );
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
        recordingState: VideoRecorderState.idle,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(recordingState.isRecording, isTrue);
      expect(idleState.isRecording, isFalse);
    });

    test('isInitialized should require camera initialization', () {
      const initializedState = VideoRecorderProviderState(
        recordingState: VideoRecorderState.idle,
        isCameraInitialized: true,
        canRecord: true,
        aspectRatio: AspectRatio.square,
      );

      const uninitializedState = VideoRecorderProviderState(
        recordingState: VideoRecorderState.idle,
        isCameraInitialized: false,
        canRecord: false,
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
        recordingState: VideoRecorderState.idle,
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
        recordingState: VideoRecorderState.idle,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      expect(errorState.errorMessage, isNotNull);
      expect(idleState.errorMessage, isNull);
    });

    test('canRecord should reflect ability to start recording', () {
      const canRecordState = VideoRecorderProviderState(
        recordingState: VideoRecorderState.idle,
        canRecord: true,
        isCameraInitialized: true,
        aspectRatio: AspectRatio.square,
      );

      const cannotRecordState = VideoRecorderProviderState(
        recordingState: VideoRecorderState.recording,
        canRecord: false,
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

      const verticalState = VideoRecorderProviderState(
        aspectRatio: AspectRatio.vertical,
      );

      expect(squareState.aspectRatio, equals(AspectRatio.square));
      expect(verticalState.aspectRatio, equals(AspectRatio.vertical));
    });

    test('flashMode should be customizable', () {
      const autoFlash = VideoRecorderProviderState(
        flashMode: DivineFlashMode.auto,
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
        timerDuration: TimerDuration.off,
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
        countdownValue: 0,
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
        recordingState: VideoRecorderState.idle,
        zoomLevel: 1.0,
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
        canSwitchCamera: true,
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
      expect(state.canSwitchCamera, false);
      expect(state.countdownValue, 0);
      expect(state.aspectRatio, AspectRatio.vertical);
      expect(state.flashMode, DivineFlashMode.auto);
      expect(state.timerDuration, TimerDuration.off);
    });
  });
}
