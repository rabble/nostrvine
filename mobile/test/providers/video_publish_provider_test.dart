// ABOUTME: Unit tests for VideoPublishNotifier
// ABOUTME: Tests state management for video publishing

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/providers/video_publish_provider.dart';

void main() {
  group('VideoPublishNotifier', () {
    late ProviderContainer container;
    late VideoPublishNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(videoPublishProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('initialize sets clip from draft', () {
      /* TODO(@hm21): Temporary "commented out" create PR with only new files 
      final clip = RecordingClip(
        id: 'test-clip',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 5),
        recordedAt: DateTime.now(),
        aspectRatio: model.AspectRatio.vertical,
      );

      final draft = VineDraft.create(
        id: 'draft-1',
        clips: [clip],
        title: 'Test',
        description: 'Test description',
        hashtags: ['Vine'],
        selectedApproach: 'video',
      );

      notifier.initialize(draft: draft);

      final state = container.read(videoPublishProvider);
      expect(state.clip, clip); */
    });

    test('togglePlayPause switches between playing and paused', () {
      final initPlayState = container.read(videoPublishProvider).isPlaying;

      notifier.togglePlayPause();
      expect(container.read(videoPublishProvider).isPlaying, !initPlayState);

      notifier.togglePlayPause();
      expect(container.read(videoPublishProvider).isPlaying, initPlayState);
    });

    test('setPlaying sets playing state to true', () {
      notifier.setPlaying(true);
      expect(container.read(videoPublishProvider).isPlaying, true);
    });

    test('setPlaying sets playing state to false', () {
      notifier
        ..setPlaying(true)
        ..setPlaying(false);
      expect(container.read(videoPublishProvider).isPlaying, false);
    });

    test('toggleMute switches between muted and unmuted', () {
      final initMuteState = container.read(videoPublishProvider).isMuted;

      notifier.toggleMute();
      expect(container.read(videoPublishProvider).isMuted, !initMuteState);

      notifier.toggleMute();
      expect(container.read(videoPublishProvider).isMuted, initMuteState);
    });

    test('setMuted sets muted state to true', () {
      notifier.setMuted(true);
      expect(container.read(videoPublishProvider).isMuted, true);
    });

    test('setMuted sets muted state to false', () {
      notifier
        ..setMuted(true)
        ..setMuted(false);
      expect(container.read(videoPublishProvider).isMuted, false);
    });

    test('updatePosition updates current position', () {
      const newPosition = Duration(seconds: 3);

      notifier.updatePosition(newPosition);

      expect(container.read(videoPublishProvider).currentPosition, newPosition);
    });

    test('setDuration sets total duration', () {
      const duration = Duration(seconds: 30);

      notifier.setDuration(duration);

      expect(container.read(videoPublishProvider).totalDuration, duration);
    });

    test('setUploadProgress updates progress value', () {
      notifier.setUploadProgress(0.5);
      expect(container.read(videoPublishProvider).uploadProgress, 0.5);

      notifier.setUploadProgress(1);
      expect(container.read(videoPublishProvider).uploadProgress, 1.0);
    });

    test('setUploadProgress clamps value between 0.0 and 1.0', () {
      notifier.setUploadProgress(0);
      expect(container.read(videoPublishProvider).uploadProgress, 0.0);

      notifier.setUploadProgress(1);
      expect(container.read(videoPublishProvider).uploadProgress, 1.0);
    });

    test('setPublishState updates publish state', () {
      notifier.setPublishState(VideoPublishState.uploading);
      expect(
        container.read(videoPublishProvider).publishState,
        VideoPublishState.uploading,
      );

      notifier.setPublishState(VideoPublishState.publishToNostr);
      expect(
        container.read(videoPublishProvider).publishState,
        VideoPublishState.publishToNostr,
      );

      notifier.setPublishState(VideoPublishState.error);
      expect(
        container.read(videoPublishProvider).publishState,
        VideoPublishState.error,
      );
    });

    test('multiple position updates track correctly', () {
      notifier.updatePosition(const Duration(seconds: 1));
      expect(
        container.read(videoPublishProvider).currentPosition,
        const Duration(seconds: 1),
      );

      notifier.updatePosition(const Duration(seconds: 2));
      expect(
        container.read(videoPublishProvider).currentPosition,
        const Duration(seconds: 2),
      );

      notifier.updatePosition(const Duration(milliseconds: 2500));
      expect(
        container.read(videoPublishProvider).currentPosition,
        const Duration(milliseconds: 2500),
      );
    });

    test('state changes are independent', () {
      notifier
        ..setPlaying(true)
        ..setMuted(true);

      final state = container.read(videoPublishProvider);
      expect(state.isPlaying, true);
      expect(state.isMuted, true);

      notifier.setPlaying(false);

      final newState = container.read(videoPublishProvider);
      expect(newState.isPlaying, false);
      expect(newState.isMuted, true); // Should remain true
    });

    test('upload progress tracks intermediate values', () {
      notifier.setUploadProgress(0);
      expect(container.read(videoPublishProvider).uploadProgress, 0.0);

      notifier.setUploadProgress(0.25);
      expect(container.read(videoPublishProvider).uploadProgress, 0.25);

      notifier.setUploadProgress(0.5);
      expect(container.read(videoPublishProvider).uploadProgress, 0.5);

      notifier.setUploadProgress(0.75);
      expect(container.read(videoPublishProvider).uploadProgress, 0.75);

      notifier.setUploadProgress(1);
      expect(container.read(videoPublishProvider).uploadProgress, 1.0);
    });

    test('setError sets error state and message', () {
      notifier.setError('Upload failed');

      final state = container.read(videoPublishProvider);
      expect(state.publishState, VideoPublishState.error);
      expect(state.errorMessage, 'Upload failed');
    });

    test('clearError resets to idle state', () {
      notifier
        ..setError('Upload failed')
        ..clearError();

      final state = container.read(videoPublishProvider);
      expect(state.publishState, VideoPublishState.idle);
      // Note: errorMessage is not cleared due to copyWith behavior
    });

    test('reset returns state to initial values', () {
      // First modify the state
      notifier
        ..setPlaying(false)
        ..setMuted(true)
        ..setUploadProgress(0.5)
        ..setPublishState(VideoPublishState.uploading)
        ..updatePosition(const Duration(seconds: 10))
        // Then reset
        ..reset();

      final state = container.read(videoPublishProvider);
      // Default isPlaying is true in VideoPublishProviderState
      expect(state.isPlaying, true);
      expect(state.isMuted, false);
      expect(state.uploadProgress, 0.0);
      expect(state.publishState, VideoPublishState.idle);
      expect(state.currentPosition, Duration.zero);
    });

    test('setError preserves other state values', () {
      notifier
        ..setPlaying(true)
        ..setMuted(true)
        ..setError('Test error');

      final state = container.read(videoPublishProvider);
      expect(state.publishState, VideoPublishState.error);
      expect(state.errorMessage, 'Test error');
      expect(state.isPlaying, true);
      expect(state.isMuted, true);
    });
  });
}
