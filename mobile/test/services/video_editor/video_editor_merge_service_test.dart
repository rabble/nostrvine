// ABOUTME: Tests for VideoEditorMergeService - flattening selected clips into
// ABOUTME: a single rendered clip via the concat render pipeline.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_merge_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _createClip({
  required String id,
  Duration duration = const Duration(seconds: 2),
  double? playbackSpeed,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/path/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2025),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    playbackSpeed: playbackSpeed,
  );
}

void main() {
  group(VideoEditorMergeService, () {
    tearDown(() {
      VideoEditorRenderService.renderVideoOverride = null;
    });

    test('returns null when fewer than two clips are supplied', () async {
      var called = false;
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
          }) async {
            called = true;
            return '/out.mp4';
          };

      final result = await VideoEditorMergeService.mergeClips(
        clips: [_createClip(id: 'a')],
        renderId: 'merge-1',
      );

      expect(result, isNull);
      expect(called, isFalse, reason: 'render should not run for one clip');
    });

    test(
      'forwards clips + taskId and returns merged clip on success',
      () async {
        List<DivineVideoClip>? forwardedClips;
        String? forwardedTaskId;
        bool? forwardedPersistent;
        VideoEditorRenderService.renderVideoOverride =
            ({
              required clips,
              required usePersistentStorage,
              aspectRatio,
              parameters,
              taskId,
            }) async {
              forwardedClips = clips;
              forwardedTaskId = taskId;
              forwardedPersistent = usePersistentStorage;
              return '/documents/merged.mp4';
            };

        final clips = [
          _createClip(id: 'a'),
          _createClip(id: 'b', duration: const Duration(seconds: 3)),
        ];

        final result = await VideoEditorMergeService.mergeClips(
          clips: clips,
          renderId: 'merge-1',
        );

        expect(forwardedClips, same(clips));
        expect(forwardedTaskId, equals('merge-1'));
        expect(forwardedPersistent, isTrue);
        expect(result, isNotNull);
        expect(result!.video.file?.path, equals('/documents/merged.mp4'));
        expect(result.duration, equals(const Duration(seconds: 5)));
        expect(result.trimStart, equals(Duration.zero));
        expect(result.trimEnd, equals(Duration.zero));
        expect(result.targetAspectRatio, equals(model.AspectRatio.vertical));
      },
    );

    test('keeps the full merged duration uncapped (no export limit)', () async {
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
          }) async => '/documents/merged.mp4';

      // 5s + 5s = 10s, well beyond the ~6.3s final-export cap, which must not
      // truncate an intermediate merged clip.
      final result = await VideoEditorMergeService.mergeClips(
        clips: [
          _createClip(id: 'a', duration: const Duration(seconds: 5)),
          _createClip(id: 'b', duration: const Duration(seconds: 5)),
        ],
        renderId: 'merge-1',
      );

      expect(result!.duration, equals(const Duration(seconds: 10)));
    });

    test('accounts for playback speed when summing duration', () async {
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
          }) async => '/documents/merged.mp4';

      // 4s at 2x = 2s playback; 2s at 1x = 2s → 4s total.
      final result = await VideoEditorMergeService.mergeClips(
        clips: [
          _createClip(
            id: 'a',
            duration: const Duration(seconds: 4),
            playbackSpeed: 2,
          ),
          _createClip(id: 'b'),
        ],
        renderId: 'merge-1',
      );

      expect(result!.duration, equals(const Duration(seconds: 4)));
    });

    test('returns null when the render fails or is cancelled', () async {
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
          }) async => null;

      final result = await VideoEditorMergeService.mergeClips(
        clips: [
          _createClip(id: 'a'),
          _createClip(id: 'b'),
        ],
        renderId: 'merge-1',
      );

      expect(result, isNull);
    });
  });
}
