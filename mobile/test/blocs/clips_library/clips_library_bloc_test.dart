// ABOUTME: Tests for ClipsLibraryBloc - managing saved video clips
// ABOUTME: Tests loading, selection, deletion, and gallery export

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _FakeEditorVideo extends Fake implements EditorVideo {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEditorVideo());
  });

  group(ClipsLibraryBloc, () {
    late _MockClipLibraryService mockClipLibraryService;
    late _MockGallerySaveService mockGallerySaveService;

    DivineVideoClip createClip({
      String? id,
      Duration duration = const Duration(seconds: 5),
    }) {
      return DivineVideoClip(
        id: id ?? 'clip-${DateTime.now().millisecondsSinceEpoch}',
        video: EditorVideo.file('/path/to/clip.mp4'),
        thumbnailPath: '/path/to/thumb.jpg',
        ghostFramePath: '/path/to/ghost.jpg',
        duration: duration,
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
    }

    setUp(() {
      mockClipLibraryService = _MockClipLibraryService();
      mockGallerySaveService = _MockGallerySaveService();

      // Stub recoverMissingAssets so the unawaited background recovery
      // triggered by clips with null ghostFramePath doesn't throw.
      when(
        () => mockClipLibraryService.recoverMissingAssets(any()),
      ).thenAnswer((_) async => []);
    });

    ClipsLibraryBloc createBloc() => ClipsLibraryBloc(
      clipLibraryService: mockClipLibraryService,
      gallerySaveService: mockGallerySaveService,
    );

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state, const ClipsLibraryState());
      expect(bloc.state.status, ClipsLibraryStatus.initial);
      expect(bloc.state.clips, isEmpty);
      expect(bloc.state.selectedClipIds, isEmpty);
      bloc.close();
    });

    group('ClipsLibraryLoadRequested', () {
      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits [loading, loaded] with clips from service',
        setUp: () {
          when(() => mockClipLibraryService.getAllClips()).thenAnswer(
            (_) async => [createClip(id: 'clip1'), createClip(id: 'clip2')],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.clips.length, 'clips.length', 2),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits [loading, loaded] with empty list when no clips',
        setUp: () {
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          const ClipsLibraryState(status: ClipsLibraryStatus.loaded),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'pre-selects clips matching preSelectedIds',
        setUp: () {
          when(() => mockClipLibraryService.getAllClips()).thenAnswer(
            (_) async => [createClip(id: 'c1'), createClip(id: 'c2')],
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ClipsLibraryLoadRequested(preSelectedIds: {'c1'})),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having(
                (s) => s.selectedClipIds,
                'selectedClipIds',
                equals({'c1'}),
              )
              .having(
                (s) => s.selectedDuration,
                'selectedDuration',
                const Duration(seconds: 5),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'ignores preSelectedIds that do not exist in loaded clips',
        setUp: () {
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [createClip(id: 'c1')]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const ClipsLibraryLoadRequested(
            preSelectedIds: {'c1', 'nonexistent'},
          ),
        ),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>()
              .having(
                (s) => s.selectedClipIds,
                'selectedClipIds',
                equals({'c1'}),
              )
              .having(
                (s) => s.selectedDuration,
                'selectedDuration',
                const Duration(seconds: 5),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits [loading, error] when service throws',
        setUp: () {
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenThrow(Exception('Load failed'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.error,
          ),
        ],
      );
    });

    group('ClipsLibraryToggleSelection', () {
      final clip1 = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/path/to/clip1.mp4'),
        thumbnailPath: '/path/to/thumb1.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final clip2 = DivineVideoClip(
        id: 'clip2',
        video: EditorVideo.file('/path/to/clip2.mp4'),
        thumbnailPath: '/path/to/thumb2.jpg',
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'adds clip to selection',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryToggleSelection(clip1)),
        expect: () => [
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            selectedClipIds: const {'clip1'},
            selectedDuration: const Duration(seconds: 5),
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'removes clip from selection when already selected',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryToggleSelection(clip1)),
        expect: () => [
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'accumulates selected duration with multiple clips',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryToggleSelection(clip2)),
        expect: () => [
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            selectedClipIds: const {'clip1', 'clip2'},
            selectedDuration: const Duration(seconds: 8),
          ),
        ],
      );
    });

    group('ClipsLibraryClearSelection', () {
      final clip1 = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/path/to/clip1.mp4'),
        thumbnailPath: '/path/to/thumb1.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'clears all selections',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryClearSelection()),
        expect: () => [
          ClipsLibraryState(status: ClipsLibraryStatus.loaded, clips: [clip1]),
        ],
      );
    });

    group('ClipsLibraryDeleteSelected', () {
      final clip1 = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/path/to/clip1.mp4'),
        thumbnailPath: '/path/to/thumb1.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final clip2 = DivineVideoClip(
        id: 'clip2',
        video: EditorVideo.file('/path/to/clip2.mp4'),
        thumbnailPath: '/path/to/thumb2.jpg',
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'does nothing when no clips selected',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryDeleteSelected()),
        expect: () => [],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'deletes selected clips and clears selection',
        setUp: () {
          when(
            () => mockClipLibraryService.deleteClip('clip1'),
          ).thenAnswer((_) async {});
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [clip2]);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryDeleteSelected()),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.deleting,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.clips.length, 'clips.length', 1)
              .having((s) => s.selectedClipIds, 'selectedClipIds', isEmpty)
              .having((s) => s.lastDeletedCount, 'lastDeletedCount', 1),
        ],
        verify: (_) {
          verify(() => mockClipLibraryService.deleteClip('clip1')).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error state when deletion fails',
        setUp: () {
          when(
            () => mockClipLibraryService.deleteClip(any()),
          ).thenThrow(Exception('Delete failed'));
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryDeleteSelected()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.deleting,
          ),
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.error,
          ),
        ],
      );
    });

    group('ClipsLibraryDeleteClip', () {
      final clip1 = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/path/to/clip1.mp4'),
        thumbnailPath: '/path/to/thumb1.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'deletes single clip and reloads',
        setUp: () {
          when(
            () => mockClipLibraryService.deleteClip('clip1'),
          ).thenAnswer((_) async {});
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => []);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryDeleteClip(clip1)),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.deleting,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.clips, 'clips', isEmpty)
              .having((s) => s.lastDeletedCount, 'lastDeletedCount', 1),
        ],
        verify: (_) {
          verify(() => mockClipLibraryService.deleteClip('clip1')).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'removes clip from selection if it was selected',
        setUp: () {
          when(
            () => mockClipLibraryService.deleteClip('clip1'),
          ).thenAnswer((_) async {});
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => []);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryDeleteClip(clip1)),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.deleting,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.selectedClipIds, 'selectedClipIds', isEmpty)
              .having(
                (s) => s.selectedDuration,
                'selectedDuration',
                Duration.zero,
              ),
        ],
      );
    });

    group('ClipsLibrarySaveToGallery', () {
      final clip1 = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/path/to/clip1.mp4'),
        thumbnailPath: '/path/to/thumb1.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'does nothing when no clips selected',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibrarySaveToGallery()),
        expect: () => [],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'saves selected clips to gallery',
        setUp: () {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibrarySaveToGallery()),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.savingToGallery,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.selectedClipIds, 'selectedClipIds', isEmpty)
              .having(
                (s) => s.lastGallerySaveResult,
                'lastGallerySaveResult',
                isA<GallerySaveResultSuccess>()
                    .having((r) => r.successCount, 'successCount', 1)
                    .having((r) => r.failureCount, 'failureCount', 0),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'stops on permission denied',
        setUp: () {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySavePermissionDenied());
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibrarySaveToGallery()),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.savingToGallery,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having(
                (s) => s.lastGallerySaveResult,
                'lastGallerySaveResult',
                isA<GallerySaveResultPermissionDenied>(),
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error result when exception is thrown',
        setUp: () {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenThrow(Exception('Unexpected error'));
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibrarySaveToGallery()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.savingToGallery,
          ),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having(
                (s) => s.lastGallerySaveResult,
                'lastGallerySaveResult',
                isA<GallerySaveResultError>(),
              ),
        ],
      );
    });

    group('selectedClips', () {
      final clip1 = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('/path/to/clip1.mp4'),
        thumbnailPath: '/path/to/thumb1.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final clip2 = DivineVideoClip(
        id: 'clip2',
        video: EditorVideo.file('/path/to/clip2.mp4'),
        thumbnailPath: '/path/to/thumb2.jpg',
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      test('returns empty list when no clips selected', () {
        final bloc = createBloc()
          ..emit(
            ClipsLibraryState(
              status: ClipsLibraryStatus.loaded,
              clips: [clip1, clip2],
            ),
          );

        expect(bloc.state.selectedClips, isEmpty);
        bloc.close();
      });

      test('returns selected clips', () {
        final bloc = createBloc()
          ..emit(
            ClipsLibraryState(
              status: ClipsLibraryStatus.loaded,
              clips: [clip1, clip2],
              selectedClipIds: const {'clip1'},
            ),
          );

        expect(bloc.state.selectedClips, [clip1]);
        bloc.close();
      });

      test('returns selected clips in selection order not list order', () {
        // selectedClipIds iteration order is clip2 then clip1
        final bloc = createBloc()
          ..emit(
            ClipsLibraryState(
              status: ClipsLibraryStatus.loaded,
              clips: [clip1, clip2],
              selectedClipIds: const {'clip2', 'clip1'},
            ),
          );

        expect(bloc.state.selectedClips, [clip2, clip1]);
        bloc.close();
      });
    });
  });
}
