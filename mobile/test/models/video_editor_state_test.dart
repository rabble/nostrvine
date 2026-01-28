// ABOUTME: Unit tests for EditorState model validating state management and export tracking
// ABOUTME: Tests immutability, copyWith, computed properties, and state transitions

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';

void main() {
  group('EditorState', () {
    test('creates instance with default values', () {
      final state = VideoEditorProviderState();

      expect(state.currentClipIndex, 0);
      expect(state.currentPosition, Duration.zero);
      expect(state.isEditing, false);
      expect(state.isReordering, false);
      expect(state.isOverDeleteZone, false);
      expect(state.isPlaying, false);
      expect(state.isMuted, false);
      expect(state.isProcessing, false);
    });

    test('copyWith updates specified fields only', () {
      final initial = VideoEditorProviderState(
        currentClipIndex: 1,
        isPlaying: true,
      );

      final updated = initial.copyWith(isEditing: true, isMuted: true);

      expect(updated.currentClipIndex, 1);
      expect(updated.isPlaying, true);
      expect(updated.isEditing, true);
      expect(updated.isMuted, true);
      expect(updated.isReordering, false);
    });

    test('copyWith preserves all fields when none specified', () {
      final state = VideoEditorProviderState(
        currentClipIndex: 2,
        currentPosition: Duration(seconds: 5),
        isEditing: true,
        isReordering: true,
        isOverDeleteZone: true,
        isPlaying: true,
        isMuted: true,
        isProcessing: true,
      );

      final copied = state.copyWith();

      expect(copied.currentClipIndex, state.currentClipIndex);
      expect(copied.currentPosition, state.currentPosition);
      expect(copied.isEditing, state.isEditing);
      expect(copied.isReordering, state.isReordering);
      expect(copied.isOverDeleteZone, state.isOverDeleteZone);
      expect(copied.isPlaying, state.isPlaying);
      expect(copied.isMuted, state.isMuted);
      expect(copied.isProcessing, state.isProcessing);
    });
  });
}
