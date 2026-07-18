// ABOUTME: Tests for ClipsLibraryBloc - managing saved video clips
// ABOUTME: Tests loading, selection, deletion, and gallery export

import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _FakeEditorVideo extends Fake implements EditorVideo {}

class _CapturingObserver extends BlocObserver {
  final List<Object> errors = [];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEditorVideo());
  });

  group(ClipsLibraryBloc, () {
    late _MockClipLibraryService mockClipLibraryService;
    late _MockGallerySaveService mockGallerySaveService;
    late SharedPreferences sharedPreferences;

    DivineVideoClip createClip({
      String? id,
      Duration duration = const Duration(seconds: 5),
      DateTime? deletedAt,
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
        deletedAt: deletedAt,
      );
    }

    setUp(() async {
      mockClipLibraryService = _MockClipLibraryService();
      mockGallerySaveService = _MockGallerySaveService();
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      // Stub recoverMissingAssets to mirror the real no-op: return the SAME
      // list instance when nothing is recovered. Returning a fresh list would
      // fail the `identical` check in `_recoverAndReload` and re-dispatch load
      // forever for clips with a null ghostFramePath (e.g. stop-motion stills).
      when(() => mockClipLibraryService.recoverMissingAssets(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as List<DivineVideoClip>,
      );
    });

    tearDown(() {
      StopMotionRenderService.assembleOverride = null;
      StopMotionRenderService.probeDurationOverride = null;
    });

    DivineVideoClip createStopMotionClip({
      String? id,
      Duration duration = const Duration(seconds: 1),
    }) {
      return DivineVideoClip(
        id: id ?? 'sm-${DateTime.now().millisecondsSinceEpoch}',
        stopMotionFrames: const [
          StopMotionClipFrame(
            path: '/frames/f0.jpg',
            duration: Duration(milliseconds: 83),
          ),
        ],
        thumbnailPath: '/frames/f0.jpg',
        duration: duration,
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
    }

    ClipsLibraryBloc createBloc({
      LibraryClipTypeFilter clipTypeFilter = LibraryClipTypeFilter.all,
    }) => ClipsLibraryBloc(
      clipLibraryService: mockClipLibraryService,
      gallerySaveService: mockGallerySaveService,
      sharedPreferences: sharedPreferences,
      clipTypeFilter: clipTypeFilter,
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

      test(
        'does not addError after close when _recoverAndReload completes '
        'post-close (regression #4605)',
        () async {
          // Clip with a missing ghost frame triggers the unawaited
          // _recoverAndReload background path. The recovery future is
          // held open via a Completer so we can close the bloc before
          // it resolves, then fail it — exercising the post-close race.
          final clipMissingGhost = DivineVideoClip(
            id: 'clip-missing-ghost',
            video: EditorVideo.file('/path/to/clip.mp4'),
            thumbnailPath: '/path/to/thumb.jpg',
            duration: const Duration(seconds: 5),
            recordedAt: DateTime(2026),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          final completer = Completer<List<DivineVideoClip>>();
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [clipMissingGhost]);
          when(
            () => mockClipLibraryService.recoverMissingAssets(any()),
          ).thenAnswer((_) => completer.future);

          final observer = _CapturingObserver();
          final priorObserver = Bloc.observer;
          Bloc.observer = observer;
          addTearDown(() => Bloc.observer = priorObserver);

          final bloc = createBloc()..add(const ClipsLibraryLoadRequested());
          // Let the handler reach unawaited(_recoverAndReload).
          await Future<void>.delayed(Duration.zero);

          await bloc.close();

          completer.completeError(Exception('Recovery failed'));
          await Future<void>.delayed(Duration.zero);

          expect(observer.errors, isEmpty);
        },
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

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'ignores a clip of a different type than the current selection',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [
            clip1,
            createStopMotionClip(id: 'sm1'),
          ],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(
          ClipsLibraryToggleSelection(createStopMotionClip(id: 'sm1')),
        ),
        expect: () => <ClipsLibraryState>[],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'allows selecting a second clip of the same type',
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [
            createStopMotionClip(id: 'sm1'),
            createStopMotionClip(id: 'sm2'),
          ],
          selectedClipIds: const {'sm1'},
          selectedDuration: const Duration(seconds: 1),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(
          ClipsLibraryToggleSelection(createStopMotionClip(id: 'sm2')),
        ),
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.selectedClipIds,
            'selectedClipIds',
            equals({'sm1', 'sm2'}),
          ),
        ],
      );
    });

    group('clipTypeFilter', () {
      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'stopMotion filter loads only stop-motion clips',
        setUp: () {
          when(() => mockClipLibraryService.getAllClips()).thenAnswer(
            (_) async => [
              createClip(id: 'video1'),
              createStopMotionClip(id: 'sm1'),
              createClip(id: 'video2'),
            ],
          );
        },
        build: () =>
            createBloc(clipTypeFilter: LibraryClipTypeFilter.stopMotion),
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having(
                (s) => s.clips.map((c) => c.id).toList(),
                'clip ids',
                ['sm1'],
              ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'video filter loads only normal video clips',
        setUp: () {
          when(() => mockClipLibraryService.getAllClips()).thenAnswer(
            (_) async => [
              createClip(id: 'video1'),
              createStopMotionClip(id: 'sm1'),
            ],
          );
        },
        build: () => createBloc(clipTypeFilter: LibraryClipTypeFilter.video),
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>().having(
            (s) => s.clips.map((c) => c.id).toList(),
            'clip ids',
            ['video1'],
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'all filter loads both types',
        setUp: () {
          when(() => mockClipLibraryService.getAllClips()).thenAnswer(
            (_) async => [
              createClip(id: 'video1'),
              createStopMotionClip(id: 'sm1'),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
          isA<ClipsLibraryState>().having(
            (s) => s.clips.length,
            'clips.length',
            2,
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
            () => mockClipLibraryService.softDelete('clip1'),
          ).thenAnswer((_) async => true);
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
          verify(() => mockClipLibraryService.softDelete('clip1')).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error state when deletion fails',
        setUp: () {
          when(
            () => mockClipLibraryService.softDelete(any()),
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
            () => mockClipLibraryService.softDelete('clip1'),
          ).thenAnswer((_) async => true);
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
          verify(() => mockClipLibraryService.softDelete('clip1')).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'clears stale deleted count so repeated single-delete results still emit',
        setUp: () {
          when(
            () => mockClipLibraryService.softDelete(any()),
          ).thenAnswer((_) async => true);
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => []);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          lastDeletedCount: 1,
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryDeleteClip(clip1)),
        expect: () => [
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.deleting)
              .having((s) => s.lastDeletedCount, 'lastDeletedCount', isNull),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.lastDeletedCount, 'lastDeletedCount', 1),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'removes clip from selection if it was selected',
        setUp: () {
          when(
            () => mockClipLibraryService.softDelete('clip1'),
          ).thenAnswer((_) async => true);
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

    group('trash events', () {
      final activeClip = DivineVideoClip(
        id: 'active',
        video: EditorVideo.file('/path/to/active.mp4'),
        thumbnailPath: '/path/to/active.jpg',
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final trashedClip = DivineVideoClip(
        id: 'trashed',
        video: EditorVideo.file('/path/to/trashed.mp4'),
        thumbnailPath: '/path/to/trashed.jpg',
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        deletedAt: DateTime(2026, 5),
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'loads trashed clips',
        setUp: () {
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenAnswer((_) async => [trashedClip]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryTrashLoadRequested()),
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.trashLoading),
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.trashLoaded)
              .having((s) => s.trashedClips, 'trashedClips', [trashedClip]),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error when trash load fails',
        setUp: () {
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenThrow(Exception('Trash load failed'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryTrashLoadRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const ClipsLibraryState(status: ClipsLibraryStatus.trashLoading),
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.error,
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'restores clips and reloads active + trash lists from loaded state',
        setUp: () {
          when(
            () => mockClipLibraryService.restore('trashed'),
          ).thenAnswer((_) async => true);
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [activeClip, trashedClip]);
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenAnswer((_) async => []);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          trashedClips: [trashedClip],
          lastDeletedClipIds: const {'trashed'},
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryRestoreClips({'trashed'})),
        expect: () => [
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.loaded)
              .having((s) => s.clips, 'clips', [activeClip, trashedClip])
              .having((s) => s.trashedClips, 'trashedClips', isEmpty)
              .having(
                (s) => s.lastDeletedClipIds,
                'lastDeletedClipIds',
                isEmpty,
              ),
        ],
        verify: (_) {
          verify(() => mockClipLibraryService.restore('trashed')).called(1);
          verify(() => mockClipLibraryService.getAllClips()).called(1);
          verify(() => mockClipLibraryService.getTrashedClips()).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error when restore fails',
        setUp: () {
          when(
            () => mockClipLibraryService.restore(any()),
          ).thenThrow(Exception('Restore failed'));
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          trashedClips: [trashedClip],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryRestoreClips({'trashed'})),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.error,
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'hard-deletes a trashed clip and reloads trash list',
        setUp: () {
          when(
            () => mockClipLibraryService.hardDelete('trashed'),
          ).thenAnswer((_) async {});
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenAnswer((_) async => []);
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: [trashedClip],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryHardDeleteClip(trashedClip)),
        expect: () => [
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.trashLoaded)
              .having((s) => s.trashedClips, 'trashedClips', isEmpty),
        ],
        verify: (_) {
          verify(() => mockClipLibraryService.hardDelete('trashed')).called(1);
          verify(() => mockClipLibraryService.getTrashedClips()).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error when hard delete fails',
        setUp: () {
          when(
            () => mockClipLibraryService.hardDelete(any()),
          ).thenThrow(Exception('Hard delete failed'));
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: [trashedClip],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(ClipsLibraryHardDeleteClip(trashedClip)),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.error,
          ),
        ],
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'empties trash and emits empty trashLoaded state',
        setUp: () {
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenAnswer((_) async => [trashedClip]);
          when(
            () => mockClipLibraryService.hardDelete('trashed'),
          ).thenAnswer((_) async {});
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: [trashedClip],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryEmptyTrash()),
        expect: () => [
          isA<ClipsLibraryState>()
              .having((s) => s.status, 'status', ClipsLibraryStatus.trashLoaded)
              .having((s) => s.trashedClips, 'trashedClips', isEmpty),
        ],
        verify: (_) {
          verify(() => mockClipLibraryService.getTrashedClips()).called(1);
          verify(() => mockClipLibraryService.hardDelete('trashed')).called(1);
        },
      );

      blocTest<ClipsLibraryBloc, ClipsLibraryState>(
        'emits error when empty trash fails',
        setUp: () {
          when(
            () => mockClipLibraryService.getTrashedClips(),
          ).thenThrow(Exception('Empty trash failed'));
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.trashLoaded,
          trashedClips: [trashedClip],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibraryEmptyTrash()),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<ClipsLibraryState>().having(
            (s) => s.status,
            'status',
            ClipsLibraryStatus.error,
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
        'cleans up the transient mp4 after saving a stop-motion clip',
        setUp: () {
          final tempDir = Directory.systemTemp.createTempSync(
            'clips_library_stop_motion_gallery_test',
          );
          addTearDown(() async {
            if (tempDir.existsSync()) await tempDir.delete(recursive: true);
          });
          final output = File('${tempDir.path}/rendered.mp4')
            ..writeAsStringSync('rendered');
          StopMotionRenderService.assembleOverride =
              ({
                required frames,
                required aspectRatio,
                frameRate = StopMotionRenderService.defaultFrameRate,
                String? taskId,
              }) async => output.path;
          StopMotionRenderService.probeDurationOverride = (_) async => null;
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());
        },
        seed: () => ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [createStopMotionClip(id: 'sm1')],
          selectedClipIds: const {'sm1'},
          selectedDuration: const Duration(seconds: 1),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ClipsLibrarySaveToGallery()),
        verify: (_) {
          final captured =
              verify(
                    () =>
                        mockGallerySaveService.saveVideoToGallery(captureAny()),
                  ).captured.single
                  as EditorVideo;
          expect(File(captured.file!.path).existsSync(), isFalse);
        },
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
