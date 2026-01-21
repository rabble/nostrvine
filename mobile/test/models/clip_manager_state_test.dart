// ABOUTME: Tests for ClipManagerState - UI state for clip management screen
// ABOUTME: Validates duration calculations and clip operations

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('ClipManagerState', () {
    final clip1 = RecordingClip(
      id: 'clip_001',
      video: EditorVideo.file('/path/to/video1.mp4'),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime.now(),
      aspectRatio: .vertical,
    );

    final clip2 = RecordingClip(
      id: 'clip_002',
      video: EditorVideo.file('/path/to/video2.mp4'),
      duration: const Duration(milliseconds: 1500),
      recordedAt: DateTime.now(),
      aspectRatio: .vertical,
    );

    test('totalDuration sums all clip durations', () {
      final state = ClipManagerState(clips: [clip1, clip2]);

      expect(state.totalDuration, equals(const Duration(milliseconds: 3500)));
    });

    test('remainingDuration calculates correctly', () {
      final state = ClipManagerState(clips: [clip1, clip2]);

      // Max is 6.3 seconds = 6300ms, used is 3500ms, remaining is 2800ms
      expect(
        state.remainingDuration,
        equals(const Duration(milliseconds: 2800)),
      );
    });

    test('canRecordMore is true when under limit', () {
      final state = ClipManagerState(clips: [clip1]);

      expect(state.canRecordMore, isTrue);
    });

    test('canRecordMore is false when at limit', () {
      final fullClip = RecordingClip(
        id: 'clip_full',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: VideoEditorConstants.maxDuration,
        recordedAt: DateTime.now(),
        aspectRatio: .vertical,
      );
      final state = ClipManagerState(clips: [fullClip]);

      expect(state.canRecordMore, isFalse);
    });

    test('hasClips returns correct value', () {
      expect(ClipManagerState(clips: []).hasClips, isFalse);
      expect(ClipManagerState(clips: [clip1]).hasClips, isTrue);
    });

    test('clipCount returns correct number of clips', () {
      expect(ClipManagerState(clips: []).clipCount, equals(0));
      expect(ClipManagerState(clips: [clip1]).clipCount, equals(1));
      expect(ClipManagerState(clips: [clip1, clip2]).clipCount, equals(2));
    });

    test('selectedClip returns correct clip when selectedClipId is set', () {
      final state = ClipManagerState(
        clips: [clip1, clip2],
        selectedClipId: 'clip_001',
      );

      expect(state.selectedClip, equals(clip1));
    });

    test('selectedClip returns null when selectedClipId is null', () {
      final state = ClipManagerState(clips: [clip1, clip2]);

      expect(state.selectedClip, isNull);
    });

    test('selectedClip returns null when clip not found', () {
      final state = ClipManagerState(
        clips: [clip1, clip2],
        selectedClipId: 'nonexistent',
      );

      expect(state.selectedClip, isNull);
    });

    test(
      'previewingClip returns correct clip when previewingClipId is set',
      () {
        final state = ClipManagerState(
          clips: [clip1, clip2],
          previewingClipId: 'clip_002',
        );

        expect(state.previewingClip, equals(clip2));
      },
    );

    test('previewingClip returns null when previewingClipId is null', () {
      final state = ClipManagerState(clips: [clip1, clip2]);

      expect(state.previewingClip, isNull);
    });

    test('copyWith creates new state with updated values', () {
      final state = ClipManagerState(clips: [clip1]);
      final newState = state.copyWith(
        clips: [clip1, clip2],
        selectedClipId: 'clip_001',
        isProcessing: true,
      );

      expect(newState.clips.length, equals(2));
      expect(newState.selectedClipId, equals('clip_001'));
      expect(newState.isProcessing, isTrue);
    });

    test('copyWith with clearSelection clears selectedClipId', () {
      final state = ClipManagerState(
        clips: [clip1],
        selectedClipId: 'clip_001',
      );
      final newState = state.copyWith(clearSelection: true);

      expect(newState.selectedClipId, isNull);
    });

    test('copyWith with clearPreview clears previewingClipId', () {
      final state = ClipManagerState(
        clips: [clip1],
        previewingClipId: 'clip_001',
      );
      final newState = state.copyWith(clearPreview: true);

      expect(newState.previewingClipId, isNull);
    });

    test('copyWith with clearError clears errorMessage', () {
      final state = ClipManagerState(
        clips: [clip1],
        errorMessage: 'Some error',
      );
      final newState = state.copyWith(clearError: true);

      expect(newState.errorMessage, isNull);
    });

    test('state fields are initialized correctly', () {
      final state = ClipManagerState(
        clips: [clip1],
        selectedClipId: 'clip_001',
        previewingClipId: 'clip_002',
        isReordering: true,
        isProcessing: true,
        errorMessage: 'Error',
        muteOriginalAudio: true,
        activeRecordingDuration: const Duration(seconds: 1),
      );

      expect(state.clips.length, equals(1));
      expect(state.selectedClipId, equals('clip_001'));
      expect(state.previewingClipId, equals('clip_002'));
      expect(state.isReordering, isTrue);
      expect(state.isProcessing, isTrue);
      expect(state.errorMessage, equals('Error'));
      expect(state.muteOriginalAudio, isTrue);
      expect(state.activeRecordingDuration, equals(const Duration(seconds: 1)));
    });

    test('default state has expected initial values', () {
      final state = ClipManagerState();

      expect(state.clips, isEmpty);
      expect(state.selectedClipId, isNull);
      expect(state.previewingClipId, isNull);
      expect(state.isReordering, isFalse);
      expect(state.isProcessing, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.muteOriginalAudio, isFalse);
      expect(state.activeRecordingDuration, equals(Duration.zero));
    });
  });
}
