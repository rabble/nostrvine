// ABOUTME: Tests for VideoEditorClipLibrarySaveService - flattening one clip
// ABOUTME: into a standalone library clip via the render pipeline.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/editor_overlay_snapshot.dart';
import 'package:openvine/services/video_editor/video_editor_clip_library_save_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show CompleteParameters, ExportedLayer, FilterState, Layer;
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _createClip({
  String id = 'a',
  Duration duration = const Duration(seconds: 3),
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
  double? playbackSpeed,
  bool reversed = false,
  double volume = 1,
  String? thumbnailPath,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/path/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2025),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    trimStart: trimStart,
    trimEnd: trimEnd,
    playbackSpeed: playbackSpeed,
    reversed: reversed,
    volume: volume,
    thumbnailPath: thumbnailPath,
  );
}

void main() {
  group(VideoEditorClipLibrarySaveService, () {
    tearDown(() {
      VideoEditorRenderService.renderVideoOverride = null;
    });

    test(
      'renders the source clip and returns it as a fresh library clip',
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
              maxOutputDuration,
            }) async {
              forwardedClips = clips;
              forwardedTaskId = taskId;
              forwardedPersistent = usePersistentStorage;
              return '/documents/divine_1.mp4';
            };

        final clip = _createClip(trimStart: const Duration(seconds: 2));
        final result =
            await VideoEditorClipLibrarySaveService.flattenClipForLibrary(
              clip: clip,
              renderId: 'save-1',
            );

        expect(forwardedClips?.single.id, equals(clip.id));
        expect(
          forwardedClips?.single.trimStart,
          equals(const Duration(seconds: 2)),
          reason: 'the render must still see the trim window to bake it in',
        );
        expect(forwardedTaskId, equals('save-1'));
        expect(result, isNotNull);
        expect(result!.video.file?.path, equals('/documents/divine_1.mp4'));
        expect(result.id, isNot(equals(clip.id)));
        expect(result.targetAspectRatio, equals(model.AspectRatio.vertical));
        expect(
          forwardedPersistent,
          isTrue,
          reason:
              'the library resolves clips against the documents dir, so a '
              'temp-dir render would save and then dangle',
        );
      },
    );

    test('bakes the edits in rather than carrying them on the clip', () async {
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
            maxOutputDuration,
          }) async => '/documents/divine_1.mp4';

      final result =
          await VideoEditorClipLibrarySaveService.flattenClipForLibrary(
            clip: _createClip(
              duration: const Duration(seconds: 10),
              trimStart: const Duration(seconds: 2),
              trimEnd: const Duration(seconds: 3),
              playbackSpeed: 2,
              reversed: true,
              volume: 0.5,
            ),
            renderId: 'save-1',
          );

      // The render pipeline applies trim/speed/volume, and a reversed clip's
      // file is already reversed — re-flagging any of these would double-apply
      // them the next time the library clip is rendered.
      expect(result!.trimStart, equals(Duration.zero));
      expect(result.trimEnd, equals(Duration.zero));
      expect(result.playbackSpeed, isNull);
      expect(result.reversed, isFalse);
      expect(result.volume, equals(1.0));
      expect(result.minTrimStart, equals(Duration.zero));
    });

    test(
      'sizes the library clip to the trimmed section, not the source',
      () async {
        VideoEditorRenderService.renderVideoOverride =
            ({
              required clips,
              required usePersistentStorage,
              aspectRatio,
              parameters,
              taskId,
              maxOutputDuration,
            }) async => '/documents/divine_1.mp4';

        // A 10s source trimmed to its middle 5s.
        final result =
            await VideoEditorClipLibrarySaveService.flattenClipForLibrary(
              clip: _createClip(
                duration: const Duration(seconds: 10),
                trimStart: const Duration(seconds: 2),
                trimEnd: const Duration(seconds: 3),
              ),
              renderId: 'save-1',
            );

        expect(result!.duration, equals(const Duration(seconds: 5)));
      },
    );

    test('accounts for playback speed in the saved duration', () async {
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
            maxOutputDuration,
          }) async => '/documents/divine_1.mp4';

      // 8s of source at 2x plays back in 4s, which is what lands on disk.
      final result =
          await VideoEditorClipLibrarySaveService.flattenClipForLibrary(
            clip: _createClip(
              duration: const Duration(seconds: 8),
              playbackSpeed: 2,
            ),
            renderId: 'save-1',
          );

      expect(result!.duration, equals(const Duration(seconds: 4)));
    });

    test('renders uncapped so a long section is not truncated', () async {
      var capWasSet = true;
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
            maxOutputDuration,
          }) async {
            capWasSet = maxOutputDuration != null;
            return '/documents/divine_1.mp4';
          };

      await VideoEditorClipLibrarySaveService.flattenClipForLibrary(
        clip: _createClip(duration: const Duration(seconds: 10)),
        renderId: 'save-1',
      );

      // The whole point of #5322 is reusing e.g. a 10s section of a long
      // video; the ~6.3s cap belongs to the final export, not to a clip the
      // user can still trim.
      expect(
        capWasSet,
        isFalse,
        reason: 'a capped render silently truncates the saved section',
      );
    });

    test('keeps the source thumbnail when extraction yields nothing', () async {
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
            maxOutputDuration,
          }) async => '/documents/divine_1.mp4';

      // The rendered file does not exist here, so extraction returns null —
      // the library card must still get a frame rather than none.
      final result =
          await VideoEditorClipLibrarySaveService.flattenClipForLibrary(
            clip: _createClip(thumbnailPath: '/documents/thumb_a.jpg'),
            renderId: 'save-1',
          );

      expect(result!.thumbnailPath, equals('/documents/thumb_a.jpg'));
    });

    test('bakes the overlays over the clip into the render', () async {
      CompleteParameters? forwardedParameters;
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
            maxOutputDuration,
          }) async {
            forwardedParameters = parameters;
            return '/documents/divine_1.mp4';
          };

      await VideoEditorClipLibrarySaveService.flattenClipForLibrary(
        clip: _createClip(),
        renderId: 'save-1',
        overlays: EditorOverlaySnapshot(
          bodySize: const Size(100, 200),
          blur: 4,
          capturedLayers: [
            ExportedLayer(
              layer: Layer(id: 'text'),
              bytes: Uint8List.fromList([1]),
              logicalSize: const Size(10, 10),
            ),
          ],
          filterStates: [
            FilterState(
              id: 'sepia',
              name: 'sepia',
              matrices: [
                [1.0],
              ],
            ),
          ],
        ),
      );

      // Without bodySize the render silently skips every layer, so it has to
      // travel with them.
      expect(forwardedParameters, isNotNull);
      expect(forwardedParameters!.bodySize, equals(const Size(100, 200)));
      expect(forwardedParameters!.capturedLayers, hasLength(1));
      expect(forwardedParameters!.filterStates, hasLength(1));
      expect(forwardedParameters!.blur, equals(4));
    });

    test('sends no parameters when there are no overlays', () async {
      var parametersWereSent = true;
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
            maxOutputDuration,
          }) async {
            parametersWereSent = parameters != null;
            return '/documents/divine_1.mp4';
          };

      await VideoEditorClipLibrarySaveService.flattenClipForLibrary(
        clip: _createClip(),
        renderId: 'save-1',
        overlays: const EditorOverlaySnapshot(bodySize: Size(100, 200)),
      );

      expect(parametersWereSent, isFalse);
    });

    test(
      'drops the transition — it belongs to a boundary this clip lost',
      () async {
        List<DivineVideoClip>? forwardedClips;
        VideoEditorRenderService.renderVideoOverride =
            ({
              required clips,
              required usePersistentStorage,
              aspectRatio,
              parameters,
              taskId,
              maxOutputDuration,
            }) async {
              forwardedClips = clips;
              return '/documents/divine_1.mp4';
            };

        final clip = _createClip().copyWith(
          transition: const ClipTransition(type: ClipTransitionType.dissolve),
        );

        await VideoEditorClipLibrarySaveService.flattenClipForLibrary(
          clip: clip,
          renderId: 'save-1',
        );

        // Rendering alone, there is no next clip to blend into.
        expect(forwardedClips?.single.transition, isNull);
      },
    );

    test('returns null when the render fails or is cancelled', () async {
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
            maxOutputDuration,
          }) async => null;

      final result =
          await VideoEditorClipLibrarySaveService.flattenClipForLibrary(
            clip: _createClip(),
            renderId: 'save-1',
          );

      expect(result, isNull);
    });
  });
}
