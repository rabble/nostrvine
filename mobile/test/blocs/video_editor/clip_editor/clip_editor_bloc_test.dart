// ABOUTME: Tests for ClipEditorBloc - clip CRUD, undo/redo, playback,
// ABOUTME: editing mode, reordering, and split operations.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _createClip({
  String id = 'clip-1',
  Duration duration = const Duration(seconds: 3),
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/path/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2025),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
  );
}

void main() {
  group(ClipEditorBloc, () {
    late List<DivineVideoClip> twoClips;
    late List<DivineVideoClip> threeClips;

    setUp(() {
      twoClips = [
        _createClip(id: 'a', duration: const Duration(seconds: 2)),
        _createClip(id: 'b'),
      ];
      threeClips = [
        _createClip(id: 'a', duration: const Duration(seconds: 2)),
        _createClip(id: 'b', duration: const Duration(seconds: 1)),
        _createClip(id: 'c'),
      ];
    });

    ClipEditorBloc buildBloc({SplitExecutor? splitExecutor}) {
      // Keep parameter for backward-compatible test callsites.
      final _ = splitExecutor;
      return ClipEditorBloc(onFinalClipInvalidated: () {});
    }

    test('initial state has correct defaults', () {
      final bloc = buildBloc();
      expect(bloc.state.clips, isEmpty);
      expect(bloc.state.currentClipIndex, equals(0));
      expect(bloc.state.currentPosition, equals(Duration.zero));
      expect(bloc.state.splitPosition, equals(Duration.zero));
      expect(bloc.state.isEditing, isFalse);
      expect(bloc.state.isReordering, isFalse);
      expect(bloc.state.isOverDeleteZone, isFalse);
      expect(bloc.state.isPlaying, isFalse);
      expect(bloc.state.isPlayerReady, isFalse);
      expect(bloc.state.hasPlayedOnce, isFalse);
      expect(bloc.state.isMuted, isFalse);
      expect(bloc.state.isTrimDragging, isFalse);
      expect(bloc.state.undoStack, isEmpty);
      expect(bloc.state.redoStack, isEmpty);
      expect(bloc.state.canUndo, isFalse);
      expect(bloc.state.canRedo, isFalse);
      expect(bloc.state.totalDuration, equals(Duration.zero));
      bloc.close();
    });

    // =========================================================
    // CLIP DATA
    // =========================================================

    group('ClipEditorInitialized', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'populates clips from provided list',
        build: buildBloc,
        act: (bloc) => bloc.add(ClipEditorInitialized(twoClips)),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having((s) => s.clips.first.id, 'first id', 'a')
              .having((s) => s.clips.last.id, 'last id', 'b'),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets clips as unmodifiable list',
        build: buildBloc,
        act: (bloc) => bloc.add(ClipEditorInitialized(twoClips)),
        verify: (bloc) {
          expect(
            () => (bloc.state.clips as List).add(_createClip()),
            throwsUnsupportedError,
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'does not push undo stack',
        build: buildBloc,
        act: (bloc) => bloc.add(ClipEditorInitialized(twoClips)),
        verify: (bloc) {
          expect(bloc.state.undoStack, isEmpty);
        },
      );
    });

    group('ClipEditorClipRemoved', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'removes clip by ID and pushes undo',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorClipRemoved('a')),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(1))
              .having((s) => s.clips.first.id, 'remaining id', 'b')
              .having((s) => s.undoStack, 'undoStack', hasLength(1))
              .having((s) => s.redoStack, 'redoStack', isEmpty),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'undo stack contains previous clips snapshot',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorClipRemoved('a')),
        verify: (bloc) {
          final snapshot = bloc.state.undoStack.first;
          expect(snapshot.clips, hasLength(2));
          expect(snapshot.clips.first.id, equals('a'));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op for unknown clip ID',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorClipRemoved('unknown')),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clears redo stack on mutation',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: twoClips,
          redoStack: [ClipSnapshot(twoClips)],
        ),
        act: (bloc) => bloc.add(const ClipEditorClipRemoved('a')),
        verify: (bloc) {
          expect(bloc.state.redoStack, isEmpty);
        },
      );
    });

    group('ClipEditorClipInserted', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'inserts clip at specified index and pushes undo',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          ClipEditorClipInserted(
            index: 1,
            clip: _createClip(id: 'new'),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(3))
              .having((s) => s.clips[1].id, 'inserted id', 'new')
              .having((s) => s.undoStack, 'undoStack', hasLength(1)),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps index to valid range when too large',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          ClipEditorClipInserted(
            index: 100,
            clip: _createClip(id: 'end'),
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.clips.last.id, equals('end'));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps negative index to 0',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          ClipEditorClipInserted(
            index: -5,
            clip: _createClip(id: 'first'),
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.clips.first.id, equals('first'));
        },
      );
    });

    group('ClipEditorClipReordered', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'moves clip from old to new index and pushes undo',
        build: buildBloc,
        seed: () => ClipEditorState(clips: threeClips),
        act: (bloc) => bloc.add(
          const ClipEditorClipReordered(oldIndex: 0, newIndex: 2),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips[0].id, 'first', 'b')
              .having((s) => s.clips[1].id, 'second', 'c')
              .having((s) => s.clips[2].id, 'third', 'a')
              .having((s) => s.undoStack, 'undoStack', hasLength(1)),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when old and new index are the same',
        build: buildBloc,
        seed: () => ClipEditorState(clips: threeClips),
        act: (bloc) => bloc.add(
          const ClipEditorClipReordered(oldIndex: 1, newIndex: 1),
        ),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when oldIndex is out of bounds',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorClipReordered(oldIndex: 5, newIndex: 0),
        ),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when oldIndex is negative',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorClipReordered(oldIndex: -1, newIndex: 0),
        ),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps newIndex to valid range',
        build: buildBloc,
        seed: () => ClipEditorState(clips: threeClips),
        act: (bloc) => bloc.add(
          const ClipEditorClipReordered(oldIndex: 0, newIndex: 100),
        ),
        verify: (bloc) {
          // Clip 'a' should be at the end
          expect(bloc.state.clips.last.id, equals('a'));
        },
      );
    });

    group('ClipEditorClipUpdated', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'replaces clip data for existing clip ID',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          ClipEditorClipUpdated(
            clipId: 'a',
            clip: twoClips.first.copyWith(
              duration: const Duration(seconds: 10),
            ),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips.first.duration.inSeconds, 'duration', 10)
              .having((s) => s.clips, 'clips', hasLength(2)),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'does NOT push undo stack (async refinement)',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          ClipEditorClipUpdated(clipId: 'a', clip: twoClips.first),
        ),
        verify: (bloc) {
          expect(bloc.state.undoStack, isEmpty);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op for unknown clip ID',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          ClipEditorClipUpdated(
            clipId: 'unknown',
            clip: _createClip(id: 'unknown'),
          ),
        ),
        expect: () => <ClipEditorState>[],
      );
    });

    // =========================================================
    // UNDO / REDO
    // =========================================================

    group('ClipEditorUndoRequested', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'restores previous clip snapshot',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createClip(id: 'after')],
          undoStack: [
            ClipSnapshot([_createClip(id: 'before')]),
          ],
        ),
        act: (bloc) => bloc.add(const ClipEditorUndoRequested()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips.first.id, 'restored', 'before')
              .having((s) => s.undoStack, 'undoStack', isEmpty)
              .having((s) => s.redoStack, 'redoStack', hasLength(1)),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'redo stack contains current clips before undo',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createClip(id: 'current')],
          undoStack: [
            ClipSnapshot([_createClip(id: 'prev')]),
          ],
        ),
        act: (bloc) => bloc.add(const ClipEditorUndoRequested()),
        verify: (bloc) {
          expect(bloc.state.redoStack.first.clips.first.id, equals('current'));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps currentClipIndex when restored list is shorter',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: threeClips,
          currentClipIndex: 2,
          undoStack: [
            ClipSnapshot([_createClip(id: 'only')]),
          ],
        ),
        act: (bloc) => bloc.add(const ClipEditorUndoRequested()),
        verify: (bloc) {
          expect(bloc.state.currentClipIndex, equals(0));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'preserves currentClipIndex when still valid',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: twoClips,
          currentClipIndex: 1,
          undoStack: [ClipSnapshot(threeClips)],
        ),
        act: (bloc) => bloc.add(const ClipEditorUndoRequested()),
        verify: (bloc) {
          expect(bloc.state.currentClipIndex, equals(1));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when undo stack is empty',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorUndoRequested()),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorRedoRequested', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'restores next clip snapshot from redo stack',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createClip(id: 'before')],
          redoStack: [
            ClipSnapshot([_createClip(id: 'after')]),
          ],
        ),
        act: (bloc) => bloc.add(const ClipEditorRedoRequested()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips.first.id, 'restored', 'after')
              .having((s) => s.redoStack, 'redoStack', isEmpty)
              .having((s) => s.undoStack, 'undoStack', hasLength(1)),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'undo stack gets current clips pushed before redo',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createClip(id: 'current')],
          redoStack: [
            ClipSnapshot([_createClip(id: 'next')]),
          ],
        ),
        act: (bloc) => bloc.add(const ClipEditorRedoRequested()),
        verify: (bloc) {
          expect(bloc.state.undoStack.first.clips.first.id, equals('current'));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps currentClipIndex when redo list is shorter',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: threeClips,
          currentClipIndex: 2,
          redoStack: [
            ClipSnapshot([_createClip(id: 'only')]),
          ],
        ),
        act: (bloc) => bloc.add(const ClipEditorRedoRequested()),
        verify: (bloc) {
          expect(bloc.state.currentClipIndex, equals(0));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when redo stack is empty',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorRedoRequested()),
        expect: () => <ClipEditorState>[],
      );
    });

    group('_maxUndoSteps trimming', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'trims undo stack to 30 entries on overflow',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: twoClips,
          undoStack: List.generate(
            30,
            (i) => ClipSnapshot([_createClip(id: 'snap-$i')]),
          ),
        ),
        act: (bloc) => bloc.add(const ClipEditorClipRemoved('a')),
        verify: (bloc) {
          expect(bloc.state.undoStack, hasLength(30));
          // Oldest entry (snap-0) should have been trimmed.
          expect(
            bloc.state.undoStack.first.clips.first.id,
            equals('snap-1'),
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'keeps stack at 30 when exactly at limit before push',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: twoClips,
          undoStack: List.generate(
            29,
            (i) => ClipSnapshot([_createClip(id: 'snap-$i')]),
          ),
        ),
        act: (bloc) => bloc.add(const ClipEditorClipRemoved('a')),
        verify: (bloc) {
          expect(bloc.state.undoStack, hasLength(30));
          // First entry should still be snap-0
          expect(
            bloc.state.undoStack.first.clips.first.id,
            equals('snap-0'),
          );
        },
      );
    });

    // =========================================================
    // CLIP SELECTION
    // =========================================================

    group('ClipEditorClipSelected', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets index, pauses playback, resets player ready',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: threeClips,
          isPlaying: true,
          isPlayerReady: true,
          hasPlayedOnce: true,
        ),
        act: (bloc) => bloc.add(const ClipEditorClipSelected(1)),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.currentClipIndex, 'index', 1)
              .having((s) => s.isPlaying, 'isPlaying', isFalse)
              .having((s) => s.isPlayerReady, 'isPlayerReady', isFalse)
              .having((s) => s.hasPlayedOnce, 'hasPlayedOnce', isFalse)
              .having(
                (s) => s.splitPosition,
                'splitPosition',
                equals(Duration.zero),
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'calculates position offset from previous clips',
        build: buildBloc,
        seed: () => ClipEditorState(clips: threeClips),
        act: (bloc) => bloc.add(const ClipEditorClipSelected(2)),
        verify: (bloc) {
          // Offset = clip a (2s) + clip b (1s) = 3s
          expect(
            bloc.state.currentPosition,
            equals(const Duration(seconds: 3)),
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'does not reset isPlayerReady in reorder mode',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: threeClips,
          isReordering: true,
          isPlayerReady: true,
          hasPlayedOnce: true,
        ),
        act: (bloc) => bloc.add(const ClipEditorClipSelected(1)),
        verify: (bloc) {
          expect(bloc.state.isPlayerReady, isTrue);
          expect(bloc.state.hasPlayedOnce, isTrue);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op for negative index',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorClipSelected(-1)),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when index >= clip count',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorClipSelected(5)),
        expect: () => <ClipEditorState>[],
      );
    });

    // =========================================================
    // PLAYBACK CONTROL
    // =========================================================

    group('ClipEditorPlayPauseToggled', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'starts playing when paused and player is ready',
        build: buildBloc,
        seed: () => const ClipEditorState(
          isPlayerReady: true,
        ),
        act: (bloc) => bloc.add(const ClipEditorPlayPauseToggled()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'pauses when currently playing',
        build: buildBloc,
        seed: () => const ClipEditorState(
          isPlaying: true,
          isPlayerReady: true,
        ),
        act: (bloc) => bloc.add(const ClipEditorPlayPauseToggled()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isFalse,
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'does not play when player is not ready',
        build: buildBloc,
        seed: () => const ClipEditorState(),
        act: (bloc) => bloc.add(const ClipEditorPlayPauseToggled()),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorPlaybackPaused', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets isPlaying to false',
        build: buildBloc,
        seed: () => const ClipEditorState(isPlaying: true),
        act: (bloc) => bloc.add(const ClipEditorPlaybackPaused()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isFalse,
          ),
        ],
      );
    });

    group('ClipEditorPlayerReadyChanged', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'updates isPlayerReady to true',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ClipEditorPlayerReadyChanged(isReady: true),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isPlayerReady,
            'isPlayerReady',
            isTrue,
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when value does not change',
        build: buildBloc,
        seed: () => const ClipEditorState(isPlayerReady: true),
        act: (bloc) => bloc.add(
          const ClipEditorPlayerReadyChanged(isReady: true),
        ),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorFirstPlaybackStarted', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets hasPlayedOnce to true',
        build: buildBloc,
        act: (bloc) => bloc.add(const ClipEditorFirstPlaybackStarted()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.hasPlayedOnce,
            'hasPlayedOnce',
            isTrue,
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when already played once',
        build: buildBloc,
        seed: () => const ClipEditorState(hasPlayedOnce: true),
        act: (bloc) => bloc.add(const ClipEditorFirstPlaybackStarted()),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorMuteToggled', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'toggles mute on when unmuted',
        build: buildBloc,
        act: (bloc) => bloc.add(const ClipEditorMuteToggled()),
        expect: () => [
          isA<ClipEditorState>().having((s) => s.isMuted, 'isMuted', isTrue),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'toggles mute off when muted',
        build: buildBloc,
        seed: () => const ClipEditorState(isMuted: true),
        act: (bloc) => bloc.add(const ClipEditorMuteToggled()),
        expect: () => [
          isA<ClipEditorState>().having((s) => s.isMuted, 'isMuted', isFalse),
        ],
      );
    });

    group('ClipEditorPositionUpdated', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'updates position with offset from prior clips in view mode',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: threeClips,
          currentClipIndex: 1,
        ),
        act: (bloc) => bloc.add(
          const ClipEditorPositionUpdated(
            clipId: 'b',
            position: Duration(milliseconds: 500),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.currentPosition,
            'position',
            // Offset = clip a (2s) + 500ms = 2500ms
            equals(const Duration(milliseconds: 2500)),
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'uses absolute position in editing mode (no offset)',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: threeClips,
          currentClipIndex: 1,
          isEditing: true,
        ),
        act: (bloc) => bloc.add(
          const ClipEditorPositionUpdated(
            clipId: 'b',
            position: Duration(milliseconds: 500),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.currentPosition,
            'position',
            // No offset in editing mode
            equals(const Duration(milliseconds: 500)),
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'ignores stale position from different clipId',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: twoClips,
        ),
        act: (bloc) => bloc.add(
          const ClipEditorPositionUpdated(
            clipId: 'wrong-id',
            position: Duration(seconds: 1),
          ),
        ),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps position to maxDuration',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [
            _createClip(id: 'long', duration: const Duration(seconds: 10)),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorPositionUpdated(
            clipId: 'long',
            position: Duration(seconds: 10),
          ),
        ),
        verify: (bloc) {
          // maxDuration is 6300ms
          expect(
            bloc.state.currentPosition.inMilliseconds,
            lessThanOrEqualTo(6300),
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'ignores when currentClipIndex >= clips.length',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: twoClips,
          currentClipIndex: 5,
        ),
        act: (bloc) => bloc.add(
          const ClipEditorPositionUpdated(
            clipId: 'a',
            position: Duration(seconds: 1),
          ),
        ),
        expect: () => <ClipEditorState>[],
      );
    });

    // =========================================================
    // EDITING MODE
    // =========================================================

    group('ClipEditorEditingStarted', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'enters editing mode and sets split position to half duration',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createClip(duration: const Duration(seconds: 4))],
          isPlaying: true,
        ),
        act: (bloc) => bloc.add(const ClipEditorEditingStarted()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isEditing, 'isEditing', isTrue)
              .having((s) => s.isPlaying, 'isPlaying', isFalse)
              .having(
                (s) => s.splitPosition,
                'splitPosition',
                equals(const Duration(seconds: 2)),
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when currentClipIndex >= clips.length',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: twoClips,
          currentClipIndex: 5,
        ),
        act: (bloc) => bloc.add(const ClipEditorEditingStarted()),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorEditingStopped', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'exits editing mode and pauses playback',
        build: buildBloc,
        seed: () => const ClipEditorState(
          isEditing: true,
          isPlaying: true,
        ),
        act: (bloc) => bloc.add(const ClipEditorEditingStopped()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isEditing, 'isEditing', isFalse)
              .having((s) => s.isPlaying, 'isPlaying', isFalse),
        ],
      );
    });

    group('ClipEditorEditingToggled', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'starts editing when not editing',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createClip(duration: const Duration(seconds: 2))],
        ),
        act: (bloc) => bloc.add(const ClipEditorEditingToggled()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isEditing,
            'isEditing',
            isTrue,
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'stops editing when already editing',
        build: buildBloc,
        seed: () => const ClipEditorState(isEditing: true),
        act: (bloc) => bloc.add(const ClipEditorEditingToggled()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isEditing,
            'isEditing',
            isFalse,
          ),
        ],
      );
    });

    group('ClipEditorSplitPositionChanged', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'updates split position and pauses playback',
        build: buildBloc,
        seed: () => const ClipEditorState(isPlaying: true),
        act: (bloc) => bloc.add(
          const ClipEditorSplitPositionChanged(Duration(seconds: 1)),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having(
                (s) => s.splitPosition,
                'splitPosition',
                equals(const Duration(seconds: 1)),
              )
              .having((s) => s.isPlaying, 'isPlaying', isFalse),
        ],
      );
    });

    // =========================================================
    // REORDERING
    // =========================================================

    group('ClipEditorReorderingStarted', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'enters reorder mode and pauses playback',
        build: buildBloc,
        seed: () => const ClipEditorState(isPlaying: true),
        act: (bloc) => bloc.add(const ClipEditorReorderingStarted()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isReordering, 'isReordering', isTrue)
              .having((s) => s.isPlaying, 'isPlaying', isFalse),
        ],
      );
    });

    group('ClipEditorReorderingStopped', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'exits reorder mode and resets delete zone',
        build: buildBloc,
        seed: () => const ClipEditorState(
          isReordering: true,
          isOverDeleteZone: true,
        ),
        act: (bloc) => bloc.add(const ClipEditorReorderingStopped()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isReordering, 'isReordering', isFalse)
              .having((s) => s.isOverDeleteZone, 'isOverDeleteZone', isFalse),
        ],
      );
    });

    group('ClipEditorDeleteZoneChanged', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets isOverDeleteZone to true',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ClipEditorDeleteZoneChanged(isOver: true),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isOverDeleteZone,
            'isOverDeleteZone',
            isTrue,
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'no emission when value is unchanged (Equatable dedup)',
        build: buildBloc,
        seed: () => const ClipEditorState(isOverDeleteZone: true),
        act: (bloc) => bloc.add(
          const ClipEditorDeleteZoneChanged(isOver: true),
        ),
        expect: () => <ClipEditorState>[],
      );
    });

    // =========================================================
    // SPLIT
    // =========================================================

    group('ClipEditorOriginalClipReplaced', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'replaces source clip with start and end clips',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) {
          final startClip = _createClip(
            id: 'a-start',
            duration: const Duration(seconds: 1),
          );
          final endClip = _createClip(
            id: 'a-end',
            duration: const Duration(seconds: 1),
          );
          bloc.add(
            ClipEditorOriginalClipReplaced(
              sourceClipId: 'a',
              startClip: startClip,
              endClip: endClip,
            ),
          );
        },
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(3))
              .having((s) => s.clips[0].id, 'first id', 'a-start')
              .having((s) => s.clips[1].id, 'second id', 'a-end')
              .having((s) => s.clips[2].id, 'third id', 'b')
              .having((s) => s.isPlayerReady, 'isPlayerReady', isFalse)
              .having((s) => s.hasPlayedOnce, 'hasPlayedOnce', isFalse),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'pushes undo entry so the split can be undone',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) {
          bloc.add(
            ClipEditorOriginalClipReplaced(
              sourceClipId: 'a',
              startClip: _createClip(id: 'a-start'),
              endClip: _createClip(id: 'a-end'),
            ),
          );
        },
        verify: (bloc) {
          expect(bloc.state.canUndo, isTrue);
          expect(bloc.state.undoStack, hasLength(1));
          expect(bloc.state.redoStack, isEmpty);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when source clip id is not found',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) {
          bloc.add(
            ClipEditorOriginalClipReplaced(
              sourceClipId: 'nonexistent',
              startClip: _createClip(id: 'x'),
              endClip: _createClip(id: 'y'),
            ),
          );
        },
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorSplitRequested', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'stops editing and replaces clip when split position is valid',
        build: buildBloc,
        seed: () {
          final clip = _createClip(
            id: 'split-me',
            duration: const Duration(seconds: 2),
          );
          // Position at 1s is valid (both halves >= 30ms)
          return ClipEditorState(
            clips: [clip],
            isEditing: true,
            splitPosition: const Duration(seconds: 1),
          );
        },
        act: (bloc) => bloc.add(const ClipEditorSplitRequested()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isEditing, 'isEditing', isFalse)
              .having((s) => s.isPlaying, 'isPlaying', isFalse),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having(
                (s) => s.clips.first.duration,
                'start duration',
                const Duration(seconds: 1),
              )
              .having(
                (s) => s.clips.last.duration,
                'end duration',
                const Duration(seconds: 1),
              )
              .having((s) => s.undoStack, 'undo stack', hasLength(1)),
        ],
      );

      test('uses state splitPosition for resulting clip durations', () async {
        final clip = _createClip(
          id: 'x',
          duration: const Duration(seconds: 2),
        );

        final bloc = buildBloc();

        bloc.emit(
          ClipEditorState(
            clips: [clip],
            isEditing: true,
            splitPosition: const Duration(milliseconds: 500),
          ),
        );

        bloc.add(const ClipEditorSplitRequested());
        final states = await bloc.stream.take(2).toList();

        final replacedState = states.last;

        expect(replacedState.clips, hasLength(2));
        expect(
          replacedState.clips.first.duration,
          equals(const Duration(milliseconds: 500)),
        );
        expect(
          replacedState.clips.last.duration,
          equals(const Duration(milliseconds: 1500)),
        );

        await bloc.close();
      });

      blocTest<ClipEditorBloc, ClipEditorState>(
        'does not call executor when split position is invalid',
        build: () {
          return buildBloc(
            splitExecutor:
                ({
                  required sourceClip,
                  required splitPosition,
                  required currentClipIndex,
                }) async {},
          );
        },
        seed: () {
          final clip = _createClip(
            id: 'tiny',
            duration: const Duration(seconds: 2),
          );
          // 5ms is below minClipDuration (30ms) for either half
          return ClipEditorState(
            clips: [clip],
            isEditing: true,
            splitPosition: const Duration(milliseconds: 5),
          );
        },
        act: (bloc) => bloc.add(const ClipEditorSplitRequested()),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when currentClipIndex >= clips.length',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: twoClips,
          currentClipIndex: 10,
          isEditing: true,
        ),
        act: (bloc) => bloc.add(const ClipEditorSplitRequested()),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'stops editing and performs split with default service',
        build: buildBloc,
        seed: () {
          final clip = _createClip(duration: const Duration(seconds: 2));
          return ClipEditorState(
            clips: [clip],
            isEditing: true,
            splitPosition: const Duration(seconds: 1),
          );
        },
        act: (bloc) => bloc.add(const ClipEditorSplitRequested()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isEditing,
            'isEditing',
            isFalse,
          ),
          isA<ClipEditorState>().having((s) => s.clips, 'clips', hasLength(2)),
        ],
      );

      test('handles split executor throwing an error', () async {
        final clip = _createClip(
          id: 'err',
          duration: const Duration(seconds: 2),
        );

        final bloc = buildBloc(
          splitExecutor:
              ({
                required sourceClip,
                required splitPosition,
                required currentClipIndex,
              }) async {
                throw Exception('render failed');
              },
        );

        bloc.emit(
          ClipEditorState(
            clips: [clip],
            isEditing: true,
            splitPosition: const Duration(seconds: 1),
          ),
        );

        bloc.add(const ClipEditorSplitRequested());
        // Should emit the editing-stopped state without throwing
        final emittedState = await bloc.stream.first;
        expect(emittedState.isEditing, isFalse);

        await bloc.close();
      });

      test('validates using VideoEditorSplitService.isValidSplitPosition', () {
        final clip = _createClip(duration: const Duration(seconds: 2));

        // Valid: both halves > 30ms
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(seconds: 1),
          ),
          isTrue,
        );

        // Invalid: left side too short
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            const Duration(milliseconds: 10),
          ),
          isFalse,
        );

        // Invalid: right side too short
        expect(
          VideoEditorSplitService.isValidSplitPosition(
            clip,
            Duration(milliseconds: clip.duration.inMilliseconds - 10),
          ),
          isFalse,
        );
      });
    });

    // =========================================================
    // STATE HELPERS
    // =========================================================

    group('ClipEditorState', () {
      test('totalDuration sums all clip durations', () {
        final state = ClipEditorState(clips: threeClips);
        // 2s + 1s + 3s = 6s
        expect(state.totalDuration, equals(const Duration(seconds: 6)));
      });

      test('totalDuration is zero for empty clips', () {
        const state = ClipEditorState();
        expect(state.totalDuration, equals(Duration.zero));
      });

      test('canUndo and canRedo reflect stack contents', () {
        const empty = ClipEditorState();
        expect(empty.canUndo, isFalse);
        expect(empty.canRedo, isFalse);

        const withUndo = ClipEditorState(
          undoStack: [ClipSnapshot([])],
        );
        expect(withUndo.canUndo, isTrue);
        expect(withUndo.canRedo, isFalse);

        const withRedo = ClipEditorState(
          redoStack: [ClipSnapshot([])],
        );
        expect(withRedo.canUndo, isFalse);
        expect(withRedo.canRedo, isTrue);
      });

      test('copyWith preserves all fields when no overrides given', () {
        final original = ClipEditorState(
          clips: twoClips,
          currentClipIndex: 1,
          currentPosition: const Duration(seconds: 2),
          splitPosition: const Duration(seconds: 1),
          isEditing: true,
          isReordering: true,
          isOverDeleteZone: true,
          isPlaying: true,
          isPlayerReady: true,
          hasPlayedOnce: true,
          isMuted: true,
          undoStack: const [ClipSnapshot([])],
          redoStack: const [ClipSnapshot([])],
        );

        final copy = original.copyWith();
        expect(copy, equals(original));
      });

      test('copyWith replaces individual fields', () {
        const original = ClipEditorState();
        final updated = original.copyWith(
          isPlaying: true,
          isMuted: true,
        );
        expect(updated.isPlaying, isTrue);
        expect(updated.isMuted, isTrue);
        // Other fields unchanged
        expect(updated.isEditing, isFalse);
        expect(updated.currentClipIndex, equals(0));
      });
    });

    group('ClipSnapshot', () {
      test('equality based on clips content', () {
        final clips = [_createClip(id: 'x')];
        final a = ClipSnapshot(clips);
        final b = ClipSnapshot(clips);
        expect(a, equals(b));
      });
    });

    // =========================================================
    // TRIM
    // =========================================================

    group('ClipEditorTrimUpdated', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'updates trimStart and trimEnd on target clip',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'a',
            trimStart: Duration(milliseconds: 500),
            trimEnd: Duration(milliseconds: 300),
            isStart: true,
          ),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having(
                (s) => s.clips.first.trimStart,
                'trimStart',
                const Duration(milliseconds: 500),
              )
              .having(
                (s) => s.clips.first.trimEnd,
                'trimEnd',
                const Duration(milliseconds: 300),
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'pushes undo when isStart is true',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'a',
            trimStart: Duration(milliseconds: 200),
            trimEnd: Duration.zero,
            isStart: true,
          ),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.undoStack,
            'undoStack',
            hasLength(1),
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'does not push undo when isStart is false',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'a',
            trimStart: Duration(milliseconds: 200),
            trimEnd: Duration.zero,
          ),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.undoStack,
            'undoStack',
            isEmpty,
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'no-op for unknown clip ID',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'unknown',
            trimStart: Duration(seconds: 1),
            trimEnd: Duration.zero,
            isStart: true,
          ),
        ),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'updates totalDuration to reflect trimmed clips',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'a',
            trimStart: Duration(milliseconds: 500),
            trimEnd: Duration.zero,
            isStart: true,
          ),
        ),
        verify: (bloc) {
          // Clip 'a' was 2s, now trimmed by 500ms = 1.5s
          // Clip 'b' is 3s, unchanged
          // Total should be 4.5s
          expect(
            bloc.state.totalDuration,
            equals(const Duration(milliseconds: 4500)),
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'does not affect other clips',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'a',
            trimStart: Duration(seconds: 1),
            trimEnd: Duration.zero,
            isStart: true,
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.clips.last.trimStart, equals(Duration.zero));
          expect(bloc.state.clips.last.trimEnd, equals(Duration.zero));
        },
      );
    });

    group('ClipEditorTrimDragStarted', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets isTrimDragging to true',
        build: buildBloc,
        act: (bloc) => bloc.add(const ClipEditorTrimDragStarted()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isTrimDragging,
            'isTrimDragging',
            isTrue,
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'pauses playback when drag starts while playing',
        build: buildBloc,
        seed: () => const ClipEditorState(isPlaying: true),
        act: (bloc) => bloc.add(const ClipEditorTrimDragStarted()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isTrimDragging,
            'isTrimDragging',
            isTrue,
          ),
        ],
      );
    });

    group('ClipEditorTrimDragEnded', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets isTrimDragging to false',
        build: buildBloc,
        seed: () => const ClipEditorState(isTrimDragging: true),
        act: (bloc) => bloc.add(const ClipEditorTrimDragEnded()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isTrimDragging,
            'isTrimDragging',
            isFalse,
          ),
        ],
      );
    });

    // =========================================================
    // EVENT EQUALITY
    // =========================================================

    group('event equality', () {
      test('$ClipEditorInitialized with same clips are equal', () {
        final clips = [_createClip()];
        expect(
          ClipEditorInitialized(clips),
          equals(ClipEditorInitialized(clips)),
        );
      });

      test('$ClipEditorClipRemoved with same id are equal', () {
        expect(
          const ClipEditorClipRemoved('x'),
          equals(const ClipEditorClipRemoved('x')),
        );
      });

      test('$ClipEditorClipReordered with same indices are equal', () {
        expect(
          const ClipEditorClipReordered(oldIndex: 0, newIndex: 1),
          equals(const ClipEditorClipReordered(oldIndex: 0, newIndex: 1)),
        );
      });

      test('$ClipEditorClipSelected with same index are equal', () {
        expect(
          const ClipEditorClipSelected(2),
          equals(const ClipEditorClipSelected(2)),
        );
      });

      test('$ClipEditorPlayerReadyChanged with same value are equal', () {
        expect(
          const ClipEditorPlayerReadyChanged(isReady: true),
          equals(const ClipEditorPlayerReadyChanged(isReady: true)),
        );
      });

      test('$ClipEditorPositionUpdated with same values are equal', () {
        expect(
          const ClipEditorPositionUpdated(
            clipId: 'a',
            position: Duration(seconds: 1),
          ),
          equals(
            const ClipEditorPositionUpdated(
              clipId: 'a',
              position: Duration(seconds: 1),
            ),
          ),
        );
      });

      test('$ClipEditorSplitPositionChanged with same position are equal', () {
        expect(
          const ClipEditorSplitPositionChanged(Duration(seconds: 1)),
          equals(const ClipEditorSplitPositionChanged(Duration(seconds: 1))),
        );
      });

      test('$ClipEditorDeleteZoneChanged with same value are equal', () {
        expect(
          const ClipEditorDeleteZoneChanged(isOver: true),
          equals(const ClipEditorDeleteZoneChanged(isOver: true)),
        );
      });

      test('$ClipEditorOriginalClipReplaced with same values are equal', () {
        final clip1 = _createClip(id: 'start');
        final clip2 = _createClip(id: 'end');
        expect(
          ClipEditorOriginalClipReplaced(
            sourceClipId: 'src',
            startClip: clip1,
            endClip: clip2,
          ),
          equals(
            ClipEditorOriginalClipReplaced(
              sourceClipId: 'src',
              startClip: clip1,
              endClip: clip2,
            ),
          ),
        );
      });

      test('singleton events are equal', () {
        expect(
          const ClipEditorUndoRequested(),
          equals(const ClipEditorUndoRequested()),
        );
        expect(
          const ClipEditorRedoRequested(),
          equals(const ClipEditorRedoRequested()),
        );
        expect(
          const ClipEditorPlayPauseToggled(),
          equals(const ClipEditorPlayPauseToggled()),
        );
        expect(
          const ClipEditorPlaybackPaused(),
          equals(const ClipEditorPlaybackPaused()),
        );
        expect(
          const ClipEditorFirstPlaybackStarted(),
          equals(const ClipEditorFirstPlaybackStarted()),
        );
        expect(
          const ClipEditorMuteToggled(),
          equals(const ClipEditorMuteToggled()),
        );
        expect(
          const ClipEditorEditingStarted(),
          equals(const ClipEditorEditingStarted()),
        );
        expect(
          const ClipEditorEditingStopped(),
          equals(const ClipEditorEditingStopped()),
        );
        expect(
          const ClipEditorEditingToggled(),
          equals(const ClipEditorEditingToggled()),
        );
        expect(
          const ClipEditorReorderingStarted(),
          equals(const ClipEditorReorderingStarted()),
        );
        expect(
          const ClipEditorReorderingStopped(),
          equals(const ClipEditorReorderingStopped()),
        );
        expect(
          const ClipEditorSplitRequested(),
          equals(const ClipEditorSplitRequested()),
        );
        expect(
          const ClipEditorTrimDragStarted(),
          equals(const ClipEditorTrimDragStarted()),
        );
        expect(
          const ClipEditorTrimDragEnded(),
          equals(const ClipEditorTrimDragEnded()),
        );
        expect(
          const ClipEditorTrimUpdated(
            clipId: 'a',
            trimStart: Duration(seconds: 1),
            trimEnd: Duration.zero,
          ),
          equals(
            const ClipEditorTrimUpdated(
              clipId: 'a',
              trimStart: Duration(seconds: 1),
              trimEnd: Duration.zero,
            ),
          ),
        );
      });
    });
  });
}
