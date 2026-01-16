// ABOUTME: Unit tests for ProfileEditorState
// ABOUTME: Tests state equality, copyWith, and property behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';

void main() {
  group('ProfileEditorState', () {
    test('supports value equality', () {
      const state1 = ProfileEditorState(status: ProfileEditorStatus.success);
      const state2 = ProfileEditorState(status: ProfileEditorStatus.success);

      expect(state1, equals(state2));
    });

    test('has correct initial values', () {
      const state = ProfileEditorState();

      expect(state.status, ProfileEditorStatus.initial);
      expect(state.error, isNull);
    });

    test('copyWith creates copy with updated status', () {
      const state = ProfileEditorState();

      final updated = state.copyWith(status: ProfileEditorStatus.loading);

      expect(updated.status, ProfileEditorStatus.loading);
      expect(updated.error, isNull);
    });

    test('copyWith creates copy with updated error', () {
      const state = ProfileEditorState();

      final updated = state.copyWith(
        status: ProfileEditorStatus.failure,
        error: ProfileEditorError.publishFailed,
      );

      expect(updated.status, ProfileEditorStatus.failure);
      expect(updated.error, ProfileEditorError.publishFailed);
    });

    test('copyWith preserves status when not specified', () {
      const state = ProfileEditorState(status: ProfileEditorStatus.success);

      final updated = state.copyWith();

      expect(updated.status, ProfileEditorStatus.success);
    });

    test('copyWith clears error when not specified', () {
      const state = ProfileEditorState(
        status: ProfileEditorStatus.failure,
        error: ProfileEditorError.publishFailed,
      );

      final updated = state.copyWith(status: ProfileEditorStatus.loading);

      expect(updated.error, isNull);
    });

    test('different statuses are not equal', () {
      const state1 = ProfileEditorState(status: ProfileEditorStatus.initial);
      const state2 = ProfileEditorState(status: ProfileEditorStatus.loading);

      expect(state1, isNot(equals(state2)));
    });

    test('different errors are not equal', () {
      const state1 = ProfileEditorState(
        status: ProfileEditorStatus.failure,
        error: ProfileEditorError.usernameTaken,
      );
      const state2 = ProfileEditorState(
        status: ProfileEditorStatus.failure,
        error: ProfileEditorError.usernameReserved,
      );

      expect(state1, isNot(equals(state2)));
    });
  });
}
