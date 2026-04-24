// ABOUTME: Tests for ClipEditorBloc - clip CRUD, editing mode,
// ABOUTME: trimming, and split operations.

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

    ClipEditorBloc buildBloc() {
      return ClipEditorBloc(onFinalClipInvalidated: () {});
    }

    test('initial state has correct defaults', () {
      final bloc = buildBloc();
      expect(bloc.state.clips, isEmpty);
      expect(bloc.state.currentClipIndex, equals(0));
      expect(bloc.state.splitPosition, equals(Duration.zero));
      expect(bloc.state.isEditing, isFalse);
      expect(bloc.state.isTrimDragging, isFalse);
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
    });

    group('ClipEditorClipRemoved', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'removes clip by ID',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorClipRemoved('a')),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(1))
              .having((s) => s.clips.first.id, 'remaining id', 'b'),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op for unknown clip ID',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(const ClipEditorClipRemoved('unknown')),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorClipInserted', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'inserts clip at specified index',
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
              .having((s) => s.clips[1].id, 'inserted id', 'new'),
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
    // CLIP SELECTION
    // =========================================================

    group('ClipEditorClipSelected', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets index and resets split position',
        build: buildBloc,
        seed: () => ClipEditorState(clips: threeClips),
        act: (bloc) => bloc.add(const ClipEditorClipSelected(1)),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.currentClipIndex, 'index', 1)
              .having(
                (s) => s.splitPosition,
                'splitPosition',
                equals(Duration.zero),
              ),
        ],
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
    // EDITING MODE
    // =========================================================

    group('ClipEditorEditingStarted', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'enters editing mode and sets split position to half duration',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: [_createClip(duration: const Duration(seconds: 4))],
        ),
        act: (bloc) => bloc.add(const ClipEditorEditingStarted()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isEditing, 'isEditing', isTrue)
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
        'exits editing mode',
        build: buildBloc,
        seed: () => const ClipEditorState(isEditing: true),
        act: (bloc) => bloc.add(const ClipEditorEditingStopped()),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isEditing,
            'isEditing',
            isFalse,
          ),
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
        'updates split position',
        build: buildBloc,
        seed: () => const ClipEditorState(),
        act: (bloc) => bloc.add(
          const ClipEditorSplitPositionChanged(Duration(seconds: 1)),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.splitPosition,
            'splitPosition',
            equals(const Duration(seconds: 1)),
          ),
        ],
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
              .having((s) => s.clips[2].id, 'third id', 'b'),
        ],
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
              .having((s) => s.isTrimDragging, 'isTrimDragging', isFalse),
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
              ),
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
        'emits nothing when split position is invalid',
        build: buildBloc,
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

      test('copyWith preserves all fields when no overrides given', () {
        final original = ClipEditorState(
          clips: twoClips,
          currentClipIndex: 1,
          splitPosition: const Duration(seconds: 1),
          isEditing: true,
          isTrimDragging: true,
        );

        final copy = original.copyWith();
        expect(copy, equals(original));
      });

      test('copyWith replaces individual fields', () {
        const original = ClipEditorState();
        final updated = original.copyWith(
          isEditing: true,
          isTrimDragging: true,
        );
        expect(updated.isEditing, isTrue);
        expect(updated.isTrimDragging, isTrue);
        // Other fields unchanged
        expect(updated.currentClipIndex, equals(0));
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
        'no-op for unknown clip ID',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'unknown',
            trimStart: Duration(seconds: 1),
            trimEnd: Duration.zero,
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

      test('$ClipEditorClipSelected with same index are equal', () {
        expect(
          const ClipEditorClipSelected(2),
          equals(const ClipEditorClipSelected(2)),
        );
      });

      test('$ClipEditorSplitPositionChanged with same position are equal', () {
        expect(
          const ClipEditorSplitPositionChanged(Duration(seconds: 1)),
          equals(const ClipEditorSplitPositionChanged(Duration(seconds: 1))),
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
