// ABOUTME: Tests for ClipsLibraryState and related classes
// ABOUTME: Verifies equality, copyWith, and helper properties

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(ClipsLibraryState, () {
    final clip1 = DivineVideoClip(
      id: 'clip1',
      video: EditorVideo.file('/path/to/clip1.mp4'),
      thumbnailPath: '/path/to/thumb1.jpg',
      duration: const Duration(seconds: 5),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    test('supports value equality', () {
      expect(
        const ClipsLibraryState(),
        equals(const ClipsLibraryState()),
      );
    });

    test('initial state has correct defaults', () {
      const state = ClipsLibraryState();
      expect(state.status, ClipsLibraryStatus.initial);
      expect(state.clips, isEmpty);
      expect(state.selectedClipIds, isEmpty);
      expect(state.selectedDuration, Duration.zero);
      expect(state.errorMessage, isNull);
      expect(state.lastGallerySaveResult, isNull);
      expect(state.lastDeletedCount, isNull);
    });

    group('helper getters', () {
      test('isLoading returns true when loading', () {
        const state = ClipsLibraryState(status: ClipsLibraryStatus.loading);
        expect(state.isLoading, isTrue);
        expect(state.isDeleting, isFalse);
        expect(state.isSavingToGallery, isFalse);
      });

      test('isDeleting returns true when deleting', () {
        const state = ClipsLibraryState(status: ClipsLibraryStatus.deleting);
        expect(state.isDeleting, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isSavingToGallery, isFalse);
      });

      test('isSavingToGallery returns true when saving', () {
        const state = ClipsLibraryState(
          status: ClipsLibraryStatus.savingToGallery,
        );
        expect(state.isSavingToGallery, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isDeleting, isFalse);
      });
    });

    group('copyWith', () {
      test('returns same state when no parameters', () {
        final state = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        );

        expect(state.copyWith(), equals(state));
      });

      test('updates status', () {
        const state = ClipsLibraryState();
        final updated = state.copyWith(status: ClipsLibraryStatus.loading);
        expect(updated.status, ClipsLibraryStatus.loading);
      });

      test('updates clips', () {
        const state = ClipsLibraryState();
        final updated = state.copyWith(clips: [clip1]);
        expect(updated.clips, [clip1]);
      });

      test('updates selectedClipIds', () {
        const state = ClipsLibraryState();
        final updated = state.copyWith(selectedClipIds: const {'clip1'});
        expect(updated.selectedClipIds, {'clip1'});
      });

      test('updates selectedDuration', () {
        const state = ClipsLibraryState();
        final updated = state.copyWith(
          selectedDuration: const Duration(seconds: 10),
        );
        expect(updated.selectedDuration, const Duration(seconds: 10));
      });

      test('clears error when clearError is true', () {
        const state = ClipsLibraryState(errorMessage: 'Some error');
        final updated = state.copyWith(clearError: true);
        expect(updated.errorMessage, isNull);
      });

      test(
        'clears gallery save result when clearGallerySaveResult is true',
        () {
          const state = ClipsLibraryState(
            lastGallerySaveResult: GallerySaveResultSuccess(
              successCount: 1,
              failureCount: 0,
            ),
          );
          final updated = state.copyWith(clearGallerySaveResult: true);
          expect(updated.lastGallerySaveResult, isNull);
        },
      );

      test('clears deleted count when clearDeletedCount is true', () {
        const state = ClipsLibraryState(lastDeletedCount: 5);
        final updated = state.copyWith(clearDeletedCount: true);
        expect(updated.lastDeletedCount, isNull);
      });
    });

    test('props are correct', () {
      final state = ClipsLibraryState(
        status: ClipsLibraryStatus.loaded,
        clips: [clip1],
        selectedClipIds: const {'clip1'},
        selectedDuration: const Duration(seconds: 5),
        errorMessage: 'error',
        lastGallerySaveResult: const GallerySaveResultSuccess(
          successCount: 1,
          failureCount: 0,
        ),
        lastDeletedCount: 1,
      );

      expect(state.props, [
        ClipsLibraryStatus.loaded,
        [clip1],
        {'clip1'},
        const Duration(seconds: 5),
        'error',
        const GallerySaveResultSuccess(successCount: 1, failureCount: 0),
        1,
      ]);
    });
  });

  group('GallerySaveResult', () {
    group(GallerySaveResultSuccess, () {
      test('supports value equality', () {
        expect(
          const GallerySaveResultSuccess(successCount: 1, failureCount: 0),
          equals(
            const GallerySaveResultSuccess(successCount: 1, failureCount: 0),
          ),
        );
      });

      test('props are correct', () {
        const result = GallerySaveResultSuccess(
          successCount: 2,
          failureCount: 1,
        );
        expect(result.props, [2, 1]);
      });
    });

    group(GallerySaveResultPermissionDenied, () {
      test('supports value equality', () {
        expect(
          const GallerySaveResultPermissionDenied(),
          equals(const GallerySaveResultPermissionDenied()),
        );
      });

      test('props are empty', () {
        expect(const GallerySaveResultPermissionDenied().props, isEmpty);
      });
    });

    group(GallerySaveResultError, () {
      test('supports value equality', () {
        expect(
          const GallerySaveResultError('error message'),
          equals(const GallerySaveResultError('error message')),
        );
      });

      test('different messages are not equal', () {
        expect(
          const GallerySaveResultError('error 1'),
          isNot(equals(const GallerySaveResultError('error 2'))),
        );
      });

      test('props contains message', () {
        expect(const GallerySaveResultError('error').props, ['error']);
      });
    });
  });

  group(ClipsLibraryStatus, () {
    test('has all expected values', () {
      expect(
        ClipsLibraryStatus.values,
        containsAll([
          ClipsLibraryStatus.initial,
          ClipsLibraryStatus.loading,
          ClipsLibraryStatus.loaded,
          ClipsLibraryStatus.deleting,
          ClipsLibraryStatus.savingToGallery,
          ClipsLibraryStatus.error,
        ]),
      );
    });
  });
}
