// ABOUTME: Tests for ClipEditorBloc - clip CRUD, editing mode,
// ABOUTME: trimming, and split operations.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockAudioExtractionService extends Mock
    implements AudioExtractionService {}

class _MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/documents';
}

class _MockSplitProVideoEditor extends ProVideoEditor {
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();

  @override
  Future<String> renderVideoToFile(
    String outputPath,
    VideoRenderData renderData, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    return outputPath;
  }
}

DivineVideoClip _createClip({
  String id = 'clip-1',
  Duration duration = const Duration(seconds: 3),
  double? playbackSpeed,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/path/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2025),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
    playbackSpeed: playbackSpeed,
  );
}

DivineVideoClip _createClipWithFile({
  String id = 'clip-local',
  Duration duration = const Duration(seconds: 5),
  Duration trimStart = const Duration(seconds: 1),
  Duration trimEnd = const Duration(milliseconds: 500),
  double? playbackSpeed,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/path/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2025),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
    playbackSpeed: playbackSpeed,
  ).copyWith(trimStart: trimStart, trimEnd: trimEnd);
}

DivineVideoClip _createClipNoFile({String id = 'clip-no-file'}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.network('https://example.com/vid.mp4'),
    duration: const Duration(seconds: 3),
    recordedAt: DateTime(2025),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
  );
}

/// Pure-Dart fake of [VideoEditorSplitService.splitClip] for tests.
///
/// Mirrors the real service's clip-id and duration math so the bloc behaves
/// identically without touching `path_provider` or `pro_video_editor`
/// plugins. Without this seam, the real service awaits
/// `getApplicationDocumentsDirectory()` before invoking `onClipsCreated`,
/// which hangs on Linux CI when sibling tests in the VGV-merged bundle
/// leave the global plugin mocks in a broken state.
Future<void> _fakeSplitClip({
  required DivineVideoClip sourceClip,
  required Duration splitPosition,
  required void Function(DivineVideoClip startClip, DivineVideoClip endClip)?
  onClipsCreated,
  required void Function(DivineVideoClip clip, String thumbnailPath)?
  onThumbnailExtracted,
  required void Function(DivineVideoClip clip, EditorVideo video)?
  onClipRendered,
}) async {
  final absoluteSplitPos = sourceClip.trimStart + splitPosition;
  final timestampMs = DateTime.now().microsecondsSinceEpoch;
  final startClip = sourceClip.copyWith(
    id: '${timestampMs}_start',
    duration: absoluteSplitPos,
    trimEnd: Duration.zero,
  );
  final previewEndClip = sourceClip.copyWith(
    id: '${timestampMs}_end',
    duration: sourceClip.duration,
    trimStart: absoluteSplitPos,
  );
  onClipsCreated?.call(startClip, previewEndClip);
}

Future<void> _fakeSplitClipThenRenderEnd({
  required DivineVideoClip sourceClip,
  required Duration splitPosition,
  required void Function(DivineVideoClip startClip, DivineVideoClip endClip)?
  onClipsCreated,
  required void Function(DivineVideoClip clip, String thumbnailPath)?
  onThumbnailExtracted,
  required void Function(DivineVideoClip clip, EditorVideo video)?
  onClipRendered,
}) async {
  final absoluteSplitPos = sourceClip.trimStart + splitPosition;
  final timestampMs = DateTime.now().microsecondsSinceEpoch;
  final startClip = sourceClip.copyWith(
    id: '${timestampMs}_start',
    duration: absoluteSplitPos,
    trimEnd: Duration.zero,
  );
  final previewEndClip = sourceClip.copyWith(
    id: '${timestampMs}_end',
    duration: sourceClip.duration,
    trimStart: absoluteSplitPos,
  );
  final renderedEndClip = previewEndClip.copyWith(
    duration: sourceClip.duration - absoluteSplitPos,
    trimStart: Duration.zero,
  );
  onClipsCreated?.call(startClip, previewEndClip);
  onClipRendered?.call(startClip, startClip.video);
  onClipRendered?.call(renderedEndClip, renderedEndClip.video);
}

Future<void> _fakeSplitClipThenFail({
  required DivineVideoClip sourceClip,
  required Duration splitPosition,
  required void Function(DivineVideoClip startClip, DivineVideoClip endClip)?
  onClipsCreated,
  required void Function(DivineVideoClip clip, String thumbnailPath)?
  onThumbnailExtracted,
  required void Function(DivineVideoClip clip, EditorVideo video)?
  onClipRendered,
}) async {
  await _fakeSplitClip(
    sourceClip: sourceClip,
    splitPosition: splitPosition,
    onClipsCreated: onClipsCreated,
    onThumbnailExtracted: onThumbnailExtracted,
    onClipRendered: onClipRendered,
  );
  throw StateError('render failed');
}

Future<EditorVideo> _fakeReverseClip({
  required DivineVideoClip sourceClip,
  required String renderId,
}) async {
  return EditorVideo.file('/reversed/${sourceClip.id}_$renderId.mp4');
}

Future<EditorVideo> _fakeTransformClip({
  required DivineVideoClip sourceClip,
  required ExportTransform transform,
  required String renderId,
}) async {
  return EditorVideo.file('/transformed/${sourceClip.id}_$renderId.mp4');
}

void main() {
  group(ClipEditorBloc, () {
    late List<DivineVideoClip> twoClips;
    late List<DivineVideoClip> threeClips;
    late PathProviderPlatform originalPathProviderInstance;
    late ProVideoEditor originalProVideoEditor;

    setUp(() {
      originalPathProviderInstance = PathProviderPlatform.instance;
      originalProVideoEditor = ProVideoEditor.instance;
      PathProviderPlatform.instance = _MockPathProviderPlatform();
      ProVideoEditor.instance = _MockSplitProVideoEditor();
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

    tearDown(() {
      PathProviderPlatform.instance = originalPathProviderInstance;
      ProVideoEditor.instance = originalProVideoEditor;
    });

    ClipEditorBloc buildBloc({
      AudioExtractionService? audioExtractionService,
      SplitClipFn? splitClip,
      ReverseClipFn? reverseClip,
      TransformClipFn? transformClip,
    }) {
      return ClipEditorBloc(
        onFinalClipInvalidated: () {},
        audioExtractionService: audioExtractionService,
        splitClip: splitClip,
        reverseClip: reverseClip,
        transformClip: transformClip,
      );
    }

    test('initial state has correct defaults', () {
      final bloc = buildBloc();
      expect(bloc.state.clips, isEmpty);
      expect(bloc.state.currentClipIndex, equals(0));
      expect(bloc.state.splitPosition, equals(Duration.zero));
      expect(bloc.state.isEditing, isFalse);
      expect(bloc.state.isTrimDragging, isFalse);
      expect(bloc.state.isReversing, isFalse);
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
          ClipEditorClipInserted(index: 1, clip: _createClip(id: 'new')),
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
          ClipEditorClipInserted(index: 100, clip: _createClip(id: 'end')),
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
          ClipEditorClipInserted(index: -5, clip: _createClip(id: 'first')),
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
        seed: () => ClipEditorState(clips: twoClips, currentClipIndex: 5),
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
        build: () => buildBloc(splitClip: _fakeSplitClip),
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
              .having((s) => s.isSplitting, 'isSplitting', isTrue)
              .having((s) => s.isTrimDragging, 'isTrimDragging', isFalse),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having((s) => s.isSplitting, 'isSplitting', isTrue)
              .having(
                (s) => s.clips.first.duration,
                'start duration',
                const Duration(seconds: 1),
              )
              .having(
                (s) => s.clips.last.duration,
                'end duration',
                const Duration(seconds: 2),
              )
              .having(
                (s) => s.clips.last.trimmedDuration,
                'end trimmedDuration',
                const Duration(seconds: 1),
              ),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having((s) => s.isSplitting, 'isSplitting', isFalse),
        ],
      );

      test('uses state splitPosition for resulting clip durations', () async {
        final clip = _createClip(id: 'x', duration: const Duration(seconds: 2));

        final bloc = buildBloc(splitClip: _fakeSplitClip);

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
          replacedState.clips.last.trimmedDuration,
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
        'stops editing and performs split with injected splitter',
        build: () => buildBloc(splitClip: _fakeSplitClip),
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
          isA<ClipEditorState>()
              .having((s) => s.isEditing, 'isEditing', isFalse)
              .having((s) => s.isSplitting, 'isSplitting', isTrue),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having((s) => s.isSplitting, 'isSplitting', isTrue),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having((s) => s.isSplitting, 'isSplitting', isFalse),
        ],
      );

      test(
        'applies rendered clip timing after split render completes',
        () async {
          final clip = _createClip(
            id: 'x',
            duration: const Duration(seconds: 2),
          );

          final bloc = buildBloc(splitClip: _fakeSplitClipThenRenderEnd);

          bloc.emit(
            ClipEditorState(
              clips: [clip],
              isEditing: true,
              splitPosition: const Duration(milliseconds: 500),
            ),
          );

          bloc.add(const ClipEditorSplitRequested());
          await bloc.stream.firstWhere((state) => !state.isSplitting);

          final endClip = bloc.state.clips.last;
          expect(endClip.duration, const Duration(milliseconds: 1500));
          expect(endClip.trimStart, Duration.zero);
          expect(endClip.trimmedDuration, const Duration(milliseconds: 1500));

          await bloc.close();
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'rolls back created split clips when render fails',
        build: () => buildBloc(splitClip: _fakeSplitClipThenFail),
        seed: () {
          final clip = _createClip(
            id: 'source-clip',
            duration: const Duration(seconds: 2),
          );
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
              .having((s) => s.isSplitting, 'isSplitting', isTrue)
              .having(
                (s) => s.clips.single.id,
                'source clip id',
                'source-clip',
              ),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(2))
              .having((s) => s.isSplitting, 'isSplitting', isTrue)
              .having((s) => s.lastSplit, 'lastSplit', isNotNull),
          isA<ClipEditorState>()
              .having((s) => s.clips, 'clips', hasLength(1))
              .having(
                (s) => s.clips.single.id,
                'restored source clip id',
                'source-clip',
              )
              .having((s) => s.isSplitting, 'isSplitting', isFalse)
              .having((s) => s.lastSplit, 'lastSplit', isNull)
              .having(
                (s) => s.lastSplitFailure,
                'lastSplitFailure',
                isA<ClipSplitFailure>(),
              ),
        ],
        errors: () => [isA<StateError>()],
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

      test(
        'sets lastSplit with correct ids and position after split',
        () async {
          final clip = _createClip(
            id: 'source-clip',
            duration: const Duration(seconds: 2),
          );
          final bloc = buildBloc(splitClip: _fakeSplitClip)
            ..emit(
              ClipEditorState(
                clips: [clip],
                isEditing: true,
                splitPosition: const Duration(seconds: 1),
              ),
            );

          bloc.add(const ClipEditorSplitRequested());
          // First emit: isEditing=false. Second: onClipsCreated with lastSplit.
          final states = await bloc.stream.take(2).toList();
          final splitState = states.last;

          expect(splitState.lastSplit, isNotNull);
          expect(splitState.lastSplit!.sourceClipId, equals('source-clip'));
          expect(
            splitState.lastSplit!.startClipId,
            equals(splitState.clips.first.id),
          );
          expect(
            splitState.lastSplit!.endClipId,
            equals(splitState.clips.last.id),
          );

          await bloc.close();
        },
      );

      test('absoluteSplitPosition equals trimStart + splitPosition', () async {
        final clip = _createClip(
          id: 'c',
          duration: const Duration(seconds: 4),
        ).copyWith(trimStart: const Duration(milliseconds: 500));

        final bloc = buildBloc(splitClip: _fakeSplitClip)
          ..emit(
            ClipEditorState(
              clips: [clip],
              isEditing: true,
              // 1 s into the trimmed view
              splitPosition: const Duration(seconds: 1),
            ),
          );

        bloc.add(const ClipEditorSplitRequested());
        final states = await bloc.stream.take(2).toList();
        final split = states.last.lastSplit!;

        expect(
          split.absoluteSplitPosition,
          // trimStart(500ms) + splitPosition(1000ms)
          equals(const Duration(milliseconds: 1500)),
        );

        await bloc.close();
      });

      test('lastSplit captures source trim bounds', () async {
        final clip = _createClip(id: 'c', duration: const Duration(seconds: 10))
            .copyWith(
              trimStart: const Duration(seconds: 3),
              trimEnd: const Duration(seconds: 2),
            );

        final bloc = buildBloc(splitClip: _fakeSplitClip)
          ..emit(
            ClipEditorState(
              clips: [clip],
              isEditing: true,
              splitPosition: const Duration(seconds: 2),
            ),
          );

        bloc.add(const ClipEditorSplitRequested());
        final states = await bloc.stream.take(2).toList();
        final split = states.last.lastSplit!;

        expect(split.sourceTrimStart, equals(const Duration(seconds: 3)));
        expect(split.sourceTrimEnd, equals(const Duration(seconds: 2)));

        await bloc.close();
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

      test('lastSplit defaults to null', () {
        const state = ClipEditorState();
        expect(state.lastSplit, isNull);
      });

      test('copyWith sets lastSplit', () {
        const state = ClipEditorState();
        final split = ClipSplitEvent(
          sourceClipId: 'src',
          startClipId: 'start',
          endClipId: 'end',
          absoluteSplitPosition: const Duration(seconds: 1),
          sourceDuration: const Duration(seconds: 2),
        );

        final updated = state.copyWith(lastSplit: split);

        expect(updated.lastSplit, same(split));
      });

      test(
        'two ClipSplitEvents with identical fields are treated as distinct',
        () {
          final split1 = ClipSplitEvent(
            sourceClipId: 'src',
            startClipId: 'start',
            endClipId: 'end',
            absoluteSplitPosition: const Duration(seconds: 1),
            sourceDuration: const Duration(seconds: 2),
          );
          final split2 = ClipSplitEvent(
            sourceClipId: 'src',
            startClipId: 'start',
            endClipId: 'end',
            absoluteSplitPosition: const Duration(seconds: 1),
            sourceDuration: const Duration(seconds: 2),
          );

          final state1 = ClipEditorState(lastSplit: split1);
          final state2 = ClipEditorState(lastSplit: split2);

          // Identity hash differs between instances → props differ → not equal
          expect(state1, isNot(equals(state2)));
        },
      );
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
            isStart: true,
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
            isStart: true,
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
            isStart: true,
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
            isStart: true,
            trimStart: Duration(seconds: 1),
            trimEnd: Duration.zero,
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.clips.last.trimStart, equals(Duration.zero));
          expect(bloc.state.clips.last.trimEnd, equals(Duration.zero));
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets trimmingClipId and trimPosition to clampedStart when isStart',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorTrimUpdated(
            clipId: 'a',
            isStart: true,
            trimStart: Duration(milliseconds: 500),
            trimEnd: Duration.zero,
          ),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.trimmingClipId, 'trimmingClipId', 'a')
              .having(
                (s) => s.trimPosition,
                'trimPosition',
                const Duration(milliseconds: 500),
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'sets trimPosition to clip.duration - clampedEnd when !isStart',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          // Clip 'a' has duration 2s; trimEnd 500ms → trimPosition 1.5s
          const ClipEditorTrimUpdated(
            clipId: 'a',
            isStart: false,
            trimStart: Duration.zero,
            trimEnd: Duration(milliseconds: 500),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.trimmingClipId, 'trimmingClipId', 'a')
              .having(
                (s) => s.trimPosition,
                'trimPosition',
                const Duration(milliseconds: 1500),
              ),
        ],
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

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clears trimPosition and trimmingClipId',
        build: buildBloc,
        seed: () => const ClipEditorState(
          isTrimDragging: true,
          trimmingClipId: 'a',
          trimPosition: Duration(milliseconds: 500),
        ),
        act: (bloc) => bloc.add(const ClipEditorTrimDragEnded()),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.trimmingClipId, 'trimmingClipId', isNull)
              .having((s) => s.trimPosition, 'trimPosition', isNull),
        ],
      );
    });

    group('ClipEditorClipVolumeChanged', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps volume, bumps revision, and keeps clips unmodifiable',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorClipVolumeChanged(clipId: 'a', volume: -1.0),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips.first.volume, 'volume', 0.0)
              .having((s) => s.clipsVolumeRevision, 'clipsVolumeRevision', 1),
        ],
        verify: (bloc) {
          expect(
            () => (bloc.state.clips as List).add(_createClip(id: 'extra')),
            throwsUnsupportedError,
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when clamped volume matches current volume',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorClipVolumeChanged(clipId: 'a', volume: 2.0),
        ),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op for unknown clip id',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) => bloc.add(
          const ClipEditorClipVolumeChanged(clipId: 'missing', volume: 0.4),
        ),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorAllClipsVolumeChanged', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps below 0 to 0 on every clip, bumps revision, '
        'keeps clips unmodifiable',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) =>
            bloc.add(const ClipEditorAllClipsVolumeChanged(volume: -1.0)),
        expect: () => [
          isA<ClipEditorState>()
              .having(
                (s) => s.clips.map((c) => c.volume).toList(),
                'clip volumes',
                [0.0, 0.0],
              )
              .having((s) => s.clipsVolumeRevision, 'clipsVolumeRevision', 1),
        ],
        verify: (bloc) {
          expect(
            () => (bloc.state.clips as List).add(_createClip(id: 'extra')),
            throwsUnsupportedError,
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'clamps above 1 to 1 on every clip',
        build: buildBloc,
        seed: () => ClipEditorState(
          clips: twoClips
              .map((c) => c.copyWith(volume: 0.5))
              .toList(growable: false),
        ),
        act: (bloc) =>
            bloc.add(const ClipEditorAllClipsVolumeChanged(volume: 2.0)),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.clips.map((c) => c.volume).toList(),
            'clip volumes',
            [1.0, 1.0],
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when there are no clips',
        build: buildBloc,
        seed: () => const ClipEditorState(),
        act: (bloc) =>
            bloc.add(const ClipEditorAllClipsVolumeChanged(volume: 0.0)),
        expect: () => <ClipEditorState>[],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'is no-op when every clip already has the clamped target volume',
        build: buildBloc,
        seed: () => ClipEditorState(clips: twoClips),
        act: (bloc) =>
            bloc.add(const ClipEditorAllClipsVolumeChanged(volume: 2.0)),
        expect: () => <ClipEditorState>[],
      );
    });

    group('ClipEditorClipReverseRequested', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits no-local-file result when clip has no local file',
        build: buildBloc,
        seed: () => ClipEditorState(clips: [_createClipNoFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-no-file'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.lastReverseResult,
            'lastReverseResult',
            isA<ClipReverseNoLocalFile>(),
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'renders reversed clip, swaps trim bounds, and toggles reversed flag',
        build: () => buildBloc(reverseClip: _fakeReverseClip),
        seed: () => ClipEditorState(clips: [_createClipWithFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isReversing, 'isReversing', isTrue)
              .having(
                (s) => s.reversingClipId,
                'reversingClipId',
                'clip-local',
              ),
          isA<ClipEditorState>()
              .having((s) => s.isReversing, 'isReversing', isFalse)
              .having((s) => s.reversingClipId, 'reversingClipId', isNull)
              .having((s) => s.clips.first.reversed, 'reversed', isTrue)
              .having(
                (s) => s.clips.first.trimStart,
                'trimStart',
                const Duration(milliseconds: 500),
              )
              .having(
                (s) => s.clips.first.trimEnd,
                'trimEnd',
                const Duration(seconds: 1),
              )
              .having(
                (s) => s.clips.first.duration,
                'duration',
                const Duration(seconds: 5),
              )
              .having(
                (s) => s.clips.first.forwardVideoPath,
                'forwardVideoPath',
                '/path/clip-local.mp4',
              )
              .having(
                (s) => s.clips.first.reversedVideoPath,
                'reversedVideoPath',
                '/reversed/clip-local_clip-local.mp4',
              )
              .having(
                (s) => s.lastReverseResult,
                'lastReverseResult',
                isA<ClipReverseSuccess>(),
              ),
        ],
        verify: (bloc) {
          expect(
            bloc.state.clips.first.video.file?.path,
            equals('/reversed/clip-local_clip-local.mp4'),
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'restores cached forward clip without calling reverse service',
        build: () => buildBloc(
          reverseClip: ({required sourceClip, required renderId}) async {
            throw StateError('reverse service should not be called');
          },
        ),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile().copyWith(
              video: EditorVideo.file('/reversed/clip-local_clip-local.mp4'),
              trimStart: const Duration(milliseconds: 500),
              trimEnd: const Duration(seconds: 1),
              reversed: true,
              forwardVideoPath: '/path/clip-local.mp4',
              reversedVideoPath: '/reversed/clip-local_clip-local.mp4',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips.first.reversed, 'reversed', isFalse)
              .having(
                (s) => s.clips.first.video.file?.path,
                'videoPath',
                '/path/clip-local.mp4',
              )
              .having(
                (s) => s.clips.first.trimStart,
                'trimStart',
                const Duration(seconds: 1),
              )
              .having(
                (s) => s.clips.first.trimEnd,
                'trimEnd',
                const Duration(milliseconds: 500),
              ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'reuses cached reversed clip and swaps trim bounds',
        build: () => buildBloc(
          reverseClip: ({required sourceClip, required renderId}) async {
            throw StateError('reverse service should not be called');
          },
        ),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile().copyWith(
              forwardVideoPath: '/path/clip-local.mp4',
              reversedVideoPath: '/reversed/clip-local_clip-local.mp4',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.clips.first.reversed, 'reversed', isTrue)
              .having(
                (s) => s.clips.first.video.file?.path,
                'videoPath',
                '/reversed/clip-local_clip-local.mp4',
              )
              .having(
                (s) => s.clips.first.trimStart,
                'trimStart',
                const Duration(milliseconds: 500),
              )
              .having(
                (s) => s.clips.first.trimEnd,
                'trimEnd',
                const Duration(seconds: 1),
              )
              .having(
                (s) => s.clips.first.duration,
                'duration',
                const Duration(seconds: 5),
              ),
        ],
      );

      // Regression test: a duplicate/split of a reversed clip preserves
      // `reversed: true` but clears both cache paths, so the fresh-render
      // branch is reached with reversed input. The render output is forward
      // content and must be cached as `forwardVideoPath`; the reversed input
      // must be cached as `reversedVideoPath`. Mapping by output direction
      // would invert both and make later cached toggles play the wrong way.
      blocTest<ClipEditorBloc, ClipEditorState>(
        'caches forward/reversed paths in the correct direction when fresh '
        'rendering a reversed clip with no cache (duplicate of reversed)',
        build: () => buildBloc(reverseClip: _fakeReverseClip),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile().copyWith(
              video: EditorVideo.file('/path/clip-local-reversed.mp4'),
              reversed: true,
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isReversing,
            'isReversing',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.isReversing, 'isReversing', isFalse)
              .having((s) => s.clips.first.reversed, 'reversed', isFalse)
              .having(
                (s) => s.clips.first.forwardVideoPath,
                'forwardVideoPath',
                '/reversed/clip-local_clip-local.mp4',
              )
              .having(
                (s) => s.clips.first.reversedVideoPath,
                'reversedVideoPath',
                '/path/clip-local-reversed.mp4',
              )
              .having(
                (s) => s.lastReverseResult,
                'lastReverseResult',
                isA<ClipReverseSuccess>(),
              ),
        ],
        verify: (bloc) {
          expect(
            bloc.state.clips.first.video.file?.path,
            equals('/reversed/clip-local_clip-local.mp4'),
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits failure result and reports unexpected errors when the reverse '
        'render throws',
        build: () => buildBloc(
          reverseClip: ({required sourceClip, required renderId}) async {
            throw StateError('reverse render failed');
          },
        ),
        seed: () => ClipEditorState(clips: [_createClipWithFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorClipReverseRequested(clipId: 'clip-local'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isReversing,
            'isReversing',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.isReversing, 'isReversing', isFalse)
              .having((s) => s.reversingClipId, 'reversingClipId', isNull)
              .having(
                (s) => s.lastReverseResult,
                'lastReverseResult',
                isA<ClipReverseFailure>(),
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>()
              .having((r) => r.unwrap(), 'unwrap', isA<StateError>())
              .having((r) => r.context, 'context', '_onClipReverseRequested'),
        ],
      );

      test(
        'discards reverse result when source clip is removed in-flight',
        () async {
          final completer = Completer<EditorVideo>();
          final clip = _createClipWithFile();
          final bloc = buildBloc(
            reverseClip: ({required sourceClip, required renderId}) =>
                completer.future,
          );

          bloc.add(ClipEditorInitialized([clip]));
          await Future<void>.delayed(Duration.zero);

          bloc.add(const ClipEditorClipReverseRequested(clipId: 'clip-local'));
          await Future<void>.delayed(Duration.zero);
          expect(bloc.state.isReversing, isTrue);

          bloc.add(const ClipEditorClipRemoved('clip-local'));
          await Future<void>.delayed(Duration.zero);
          expect(bloc.state.clips, isEmpty);

          completer.complete(EditorVideo.file('/reversed/discarded.mp4'));
          await Future<void>.delayed(Duration.zero);

          expect(bloc.state.isReversing, isFalse);
          expect(bloc.state.reversingClipId, isNull);
          expect(bloc.state.clips, isEmpty);
          expect(bloc.state.lastReverseResult, isA<ClipReverseDiscarded>());

          await bloc.close();
        },
      );
    });

    group('ClipEditorClipTransformRequested', () {
      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits no-local-file result when clip has no local file',
        build: buildBloc,
        seed: () => ClipEditorState(clips: [_createClipNoFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorClipTransformRequested(
            clipId: 'clip-no-file',
            transform: ExportTransform(),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.lastTransformResult,
            'lastTransformResult',
            isA<ClipTransformNoLocalFile>(),
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'renders transformed clip, swaps the file, and clears reverse caches',
        build: () => buildBloc(transformClip: _fakeTransformClip),
        seed: () => ClipEditorState(
          clips: [
            _createClipWithFile().copyWith(
              forwardVideoPath: '/path/clip-local.mp4',
              reversedVideoPath: '/reversed/clip-local.mp4',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const ClipEditorClipTransformRequested(
            clipId: 'clip-local',
            transform: ExportTransform(),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>()
              .having((s) => s.isTransforming, 'isTransforming', isTrue)
              .having(
                (s) => s.transformingClipId,
                'transformingClipId',
                'clip-local_transform',
              ),
          isA<ClipEditorState>()
              .having((s) => s.isTransforming, 'isTransforming', isFalse)
              .having(
                (s) => s.transformingClipId,
                'transformingClipId',
                isNull,
              )
              .having(
                (s) => s.clips.first.forwardVideoPath,
                'forwardVideoPath',
                isNull,
              )
              .having(
                (s) => s.clips.first.reversedVideoPath,
                'reversedVideoPath',
                isNull,
              )
              .having(
                (s) => s.lastTransformResult,
                'lastTransformResult',
                isA<ClipTransformSuccess>(),
              ),
        ],
        verify: (bloc) {
          expect(
            bloc.state.clips.first.video.file?.path,
            equals('/transformed/clip-local_clip-local_transform.mp4'),
          );
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits failure and reports a Reportable on a render error',
        build: () => buildBloc(
          transformClip:
              ({
                required sourceClip,
                required transform,
                required renderId,
              }) async => throw StateError('transform render failed'),
        ),
        seed: () => ClipEditorState(clips: [_createClipWithFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorClipTransformRequested(
            clipId: 'clip-local',
            transform: ExportTransform(),
          ),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isTransforming,
            'isTransforming',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.isTransforming, 'isTransforming', isFalse)
              .having(
                (s) => s.transformingClipId,
                'transformingClipId',
                isNull,
              )
              .having(
                (s) => s.lastTransformResult,
                'lastTransformResult',
                isA<ClipTransformFailure>(),
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>()
              .having((r) => r.unwrap(), 'unwrap', isA<StateError>())
              .having(
                (r) => r.context,
                'context',
                '_onClipTransformRequested',
              ),
        ],
      );

      test(
        'discards transform result when source clip is removed in-flight',
        () async {
          final completer = Completer<EditorVideo>();
          final clip = _createClipWithFile();
          final bloc = buildBloc(
            transformClip:
                ({
                  required sourceClip,
                  required transform,
                  required renderId,
                }) => completer.future,
          );

          bloc.add(ClipEditorInitialized([clip]));
          await Future<void>.delayed(Duration.zero);

          bloc.add(
            const ClipEditorClipTransformRequested(
              clipId: 'clip-local',
              transform: ExportTransform(),
            ),
          );
          await Future<void>.delayed(Duration.zero);
          expect(bloc.state.isTransforming, isTrue);

          bloc.add(const ClipEditorClipRemoved('clip-local'));
          await Future<void>.delayed(Duration.zero);
          expect(bloc.state.clips, isEmpty);

          completer.complete(EditorVideo.file('/transformed/discarded.mp4'));
          await Future<void>.delayed(Duration.zero);

          expect(bloc.state.isTransforming, isFalse);
          expect(bloc.state.transformingClipId, isNull);
          expect(bloc.state.clips, isEmpty);
          expect(
            bloc.state.lastTransformResult,
            isA<ClipTransformDiscarded>(),
          );

          await bloc.close();
        },
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

      test('$ClipEditorClipReverseRequested with same id are equal', () {
        expect(
          const ClipEditorClipReverseRequested(clipId: 'x'),
          equals(const ClipEditorClipReverseRequested(clipId: 'x')),
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
            isStart: true,
            trimStart: Duration(seconds: 1),
            trimEnd: Duration.zero,
          ),
          equals(
            const ClipEditorTrimUpdated(
              clipId: 'a',
              isStart: true,
              trimStart: Duration(seconds: 1),
              trimEnd: Duration.zero,
            ),
          ),
        );
      });
    });

    // =========================================================
    // AUDIO EXTRACTION
    // =========================================================

    group('ClipEditorAudioExtractionRequested', () {
      late _MockAudioExtractionService mockService;

      setUp(() {
        mockService = _MockAudioExtractionService();
        when(
          () => mockService.cleanupAudioFile(any()),
        ).thenAnswer((_) async {});
      });

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits ClipAudioExtractionNoLocalFile when clip has no local file',
        build: buildBloc,
        seed: () => ClipEditorState(clips: [_createClipNoFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(clipTitle: 'Test'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.lastAudioExtraction,
            'lastAudioExtraction',
            isA<ClipAudioExtractionNoLocalFile>(),
          ),
        ],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits isExtractingAudio then success with muted clip and correct endTime',
        build: () {
          when(
            () => mockService.extractAudio(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenAnswer(
            (_) async => const AudioExtractionResult(
              audioFilePath: '/tmp/audio.m4a',
              duration: 5,
              fileSize: 12345,
              sha256Hash: 'abc123',
              mimeType: 'audio/mp4',
            ),
          );
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () => ClipEditorState(clips: [_createClipWithFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(clipTitle: 'Test'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isExtractingAudio,
            'isExtractingAudio',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.isExtractingAudio, 'isExtractingAudio', isFalse)
              .having((s) => s.clips.first.volume, 'volume', 0)
              .having(
                (s) => s.lastAudioExtraction,
                'lastAudioExtraction',
                isA<ClipAudioExtractionSuccess>(),
              ),
        ],
        verify: (bloc) {
          final result =
              bloc.state.lastAudioExtraction! as ClipAudioExtractionSuccess;
          final clip = _createClipWithFile();
          // endTime must use playbackDuration, not raw duration.
          expect(result.audioEvent.endTime, equals(clip.playbackDuration));
          expect(result.audioEvent.duration, equals(5.0));
          expect(result.audioEvent.startOffset, equals(clip.trimStart));
          // Extracted audio is anchored to its source clip by default.
          expect(result.audioEvent.anchorClipId, equals(clip.id));
          expect(result.audioEvent.isAnchored, isTrue);
          verify(
            () => mockService.extractAudio(
              videoPath: '/path/clip-local.mp4',
              speed: any(named: 'speed'),
            ),
          ).called(1);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'uses playback duration and forwards speed for extracted source clip',
        build: () {
          when(
            () => mockService.extractAudio(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenAnswer(
            (_) async => const AudioExtractionResult(
              audioFilePath: '/tmp/audio.m4a',
              duration: 2.5,
              fileSize: 12345,
              sha256Hash: 'abc123',
              mimeType: 'audio/mp4',
            ),
          );
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () =>
            ClipEditorState(clips: [_createClipWithFile(playbackSpeed: 2.0)]),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(clipTitle: 'Test'),
        ),
        verify: (bloc) {
          final result =
              bloc.state.lastAudioExtraction! as ClipAudioExtractionSuccess;
          final clip = _createClipWithFile(playbackSpeed: 2.0);
          expect(result.audioEvent.startTime, equals(Duration.zero));
          expect(result.audioEvent.endTime, equals(clip.playbackDuration));
          expect(result.audioEvent.duration, equals(2.5));
          expect(
            result.audioEvent.startOffset,
            equals(clip.sourceDurationToPlaybackDuration(clip.trimStart)),
          );
          expect(
            result.audioEvent.endTime! - result.audioEvent.startTime,
            equals(clip.playbackDuration),
          );
          verify(
            () => mockService.extractAudio(
              videoPath: '/path/clip-local.mp4',
              speed: 2.0,
            ),
          ).called(1);
        },
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'uses playback-time offsets when an extracted clip follows a slowed clip',
        build: () {
          when(
            () => mockService.extractAudio(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenAnswer(
            (_) async => const AudioExtractionResult(
              audioFilePath: '/tmp/audio.m4a',
              duration: 5,
              fileSize: 12345,
              sha256Hash: 'abc123',
              mimeType: 'audio/mp4',
            ),
          );
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () => ClipEditorState(
          clips: [
            _createClip(
              id: 'slow',
              duration: const Duration(seconds: 4),
              playbackSpeed: 0.5,
            ),
            _createClipWithFile(id: 'target'),
          ],
          currentClipIndex: 1,
        ),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(clipTitle: 'Test'),
        ),
        verify: (bloc) {
          final result =
              bloc.state.lastAudioExtraction! as ClipAudioExtractionSuccess;
          final targetClip = _createClipWithFile(id: 'target');
          expect(
            result.audioEvent.startTime,
            equals(const Duration(seconds: 8)),
          );
          expect(
            result.audioEvent.endTime,
            equals(const Duration(milliseconds: 11500)),
          );
          expect(
            result.audioEvent.endTime! - result.audioEvent.startTime,
            equals(targetClip.playbackDuration),
          );
        },
      );

      test('discards extraction result when clip speed changes during '
          'in-flight extraction', () async {
        final completer = Completer<AudioExtractionResult>();
        when(
          () => mockService.extractAudio(
            videoPath: any(named: 'videoPath'),
            speed: any(named: 'speed'),
          ),
        ).thenAnswer((_) => completer.future);

        final clip = _createClipWithFile(playbackSpeed: 2.0);
        final bloc = buildBloc(audioExtractionService: mockService);

        bloc.add(ClipEditorInitialized([clip]));
        await Future<void>.delayed(Duration.zero);

        bloc.add(const ClipEditorAudioExtractionRequested(clipTitle: 'Test'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.isExtractingAudio, isTrue);

        bloc.add(
          ClipEditorClipUpdated(
            clipId: clip.id,
            clip: clip.copyWith(playbackSpeed: 0.5),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        completer.complete(
          const AudioExtractionResult(
            audioFilePath: '/tmp/stale-speed-audio.wav',
            duration: 2.5,
            fileSize: 12345,
            sha256Hash: 'abc123',
            mimeType: 'audio/wav',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.isExtractingAudio, isFalse);
        expect(bloc.state.clips.single.volume, equals(1));
        expect(
          bloc.state.lastAudioExtraction,
          isA<ClipAudioExtractionDiscarded>(),
        );
        verify(
          () => mockService.extractAudio(
            videoPath: '/path/clip-local.mp4',
            speed: 2.0,
          ),
        ).called(1);
        verify(
          () => mockService.cleanupAudioFile('/tmp/stale-speed-audio.wav'),
        ).called(1);

        await bloc.close();
      });

      blocTest<ClipEditorBloc, ClipEditorState>(
        'emits isExtractingAudio then ClipAudioExtractionFailure on AudioExtractionException',
        build: () {
          when(
            () => mockService.extractAudio(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenThrow(const AudioExtractionException('Extraction failed'));
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () => ClipEditorState(clips: [_createClipWithFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(clipTitle: 'Test'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isExtractingAudio,
            'isExtractingAudio',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.isExtractingAudio, 'isExtractingAudio', isFalse)
              .having(
                (s) => s.lastAudioExtraction,
                'lastAudioExtraction',
                isA<ClipAudioExtractionFailure>(),
              ),
        ],
        errors: () => [isA<AudioExtractionException>()],
      );

      blocTest<ClipEditorBloc, ClipEditorState>(
        'wraps unexpected extraction errors in Reportable with context',
        build: () {
          when(
            () => mockService.extractAudio(
              videoPath: any(named: 'videoPath'),
              speed: any(named: 'speed'),
            ),
          ).thenThrow(StateError('boom'));
          return buildBloc(audioExtractionService: mockService);
        },
        seed: () => ClipEditorState(clips: [_createClipWithFile()]),
        act: (bloc) => bloc.add(
          const ClipEditorAudioExtractionRequested(clipTitle: 'Test'),
        ),
        expect: () => [
          isA<ClipEditorState>().having(
            (s) => s.isExtractingAudio,
            'isExtractingAudio',
            isTrue,
          ),
          isA<ClipEditorState>()
              .having((s) => s.isExtractingAudio, 'isExtractingAudio', isFalse)
              .having(
                (s) => s.lastAudioExtraction,
                'lastAudioExtraction',
                isA<ClipAudioExtractionFailure>(),
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>()
              .having((r) => r.unwrap(), 'unwrap', isA<StateError>())
              .having(
                (r) => r.context,
                'context',
                '_onAudioExtractionRequested',
              ),
        ],
      );

      // Regression test for Fix 1: the handler must re-read `state.clips` after
      // the await and abort when the source clip no longer exists.
      test('discards extraction result and emits ClipAudioExtractionDiscarded '
          'when source clip is removed during in-flight extraction', () async {
        final completer = Completer<AudioExtractionResult>();
        when(
          () => mockService.extractAudio(
            videoPath: any(named: 'videoPath'),
            speed: any(named: 'speed'),
          ),
        ).thenAnswer((_) => completer.future);

        final clip = _createClipWithFile();
        final bloc = buildBloc(audioExtractionService: mockService);

        // Bring bloc to the expected initial state via event.
        bloc.add(ClipEditorInitialized([clip]));
        await Future<void>.delayed(Duration.zero);

        bloc.add(const ClipEditorAudioExtractionRequested(clipTitle: 'Test'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.isExtractingAudio, isTrue);

        // Remove the clip while extraction is awaiting the service.
        bloc.add(ClipEditorClipRemoved(clip.id));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.clips, isEmpty);

        // Complete the service call — bloc must discard the stale result.
        completer.complete(
          const AudioExtractionResult(
            audioFilePath: '/tmp/audio.m4a',
            duration: 5,
            fileSize: 12345,
            sha256Hash: 'abc123',
            mimeType: 'audio/mp4',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.isExtractingAudio, isFalse);
        expect(
          bloc.state.clips,
          isEmpty,
          reason: 'deleted clip must not be resurrected by the result',
        );
        expect(
          bloc.state.lastAudioExtraction,
          isA<ClipAudioExtractionDiscarded>(),
        );
        verify(() => mockService.cleanupAudioFile('/tmp/audio.m4a')).called(1);

        await bloc.close();
      });
    });
  });
}
