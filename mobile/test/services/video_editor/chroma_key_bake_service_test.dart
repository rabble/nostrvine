import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/services/video_editor/chroma_key_bake_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(ChromaKeyBakeService, () {
    final clip = DivineVideoClip(
      id: 'clip-1',
      video: EditorVideo.file('/a/clip-1.mp4'),
      duration: const Duration(seconds: 6),
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.square,
      originalAspectRatio: 1,
    );
    final inputVideo = EditorVideo.file('/a/clip-1.mp4');

    group('buildTask', () {
      test('keys a colour background on a single track', () async {
        const key = ClipChromaKey(
          key: ChromaKey.greenScreen(backgroundColor: Color(0xFF102030)),
        );

        final task = await ChromaKeyBakeService.buildTask(
          renderId: 'r',
          sourceClip: clip,
          inputVideo: inputVideo,
          chromaKey: key,
        );

        // A colour, image or transparent key needs no second track, so it must
        // not pay for a composition render.
        expect(task.composition, isNull);
        expect(task.videoSegments, hasLength(1));
        expect(task.videoSegments!.single.chromaKey, key.key);
      });

      test('renders the full clip, leaving trim to the timeline', () async {
        final trimmed = clip.copyWith(
          trimStart: const Duration(seconds: 1),
          trimEnd: const Duration(seconds: 2),
        );

        final task = await ChromaKeyBakeService.buildTask(
          renderId: 'r',
          sourceClip: trimmed,
          inputVideo: inputVideo,
          chromaKey: const ClipChromaKey(
            key: ChromaKey.greenScreen(backgroundColor: Color(0xFF102030)),
          ),
        );

        // Trim stays in clip state and is applied to the baked file
        // downstream; baking it in here would make the trim handles
        // unrecoverable.
        expect(task.videoSegments!.single.startTime, isNull);
        expect(task.videoSegments!.single.endTime, isNull);
      });

      test('refuses to put a transparent key on a single track', () async {
        // H.264 carries no alpha and the renderer asserts rather than silently
        // flattening, so "nothing behind the subject" must not be sent down
        // the single-track path. It becomes a lone keyed layer over the
        // composition's own opaque canvas instead.
        //
        // `getMetadata` needs a platform channel, so this asserts the branch
        // is taken by the failure it produces: a MissingPluginException from
        // the metadata call rather than the renderer's assertion error.
        await expectLater(
          ChromaKeyBakeService.buildTask(
            renderId: 'r',
            sourceClip: clip,
            inputVideo: inputVideo,
            chromaKey: const ClipChromaKey(key: ChromaKey.greenScreen()),
          ),
          throwsA(isNot(isA<AssertionError>())),
        );
      });

      test('refuses a backdrop clip whose file is gone', () async {
        const key = ClipChromaKey(
          key: ChromaKey.greenScreen(),
          backgroundVideoPath: '/a/does-not-exist.mp4',
        );

        await expectLater(
          ChromaKeyBakeService.buildTask(
            renderId: 'r',
            sourceClip: clip,
            inputVideo: inputVideo,
            chromaKey: key,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('backdropSegments', () {
      test('plays a long-enough backdrop once, trimmed to the clip', () {
        final segments = ChromaKeyBakeService.backdropSegments(
          path: '/a/backdrop.mp4',
          backdropDuration: const Duration(seconds: 10),
          coverDuration: const Duration(seconds: 6),
        );

        expect(segments, hasLength(1));
        expect(segments.single.timelineStart, isNull);
        expect(segments.single.endTime, const Duration(seconds: 6));
        // A backdrop is a picture, not a soundtrack — its audio would fight
        // the clip's own.
        expect(segments.single.volume, 0);
      });

      test('loops a short backdrop until it covers the clip', () {
        final segments = ChromaKeyBakeService.backdropSegments(
          path: '/a/backdrop.mp4',
          backdropDuration: const Duration(seconds: 2),
          coverDuration: const Duration(seconds: 5),
        );

        expect(segments, hasLength(3));
        expect(segments[0].timelineStart, isNull);
        expect(segments[1].timelineStart, const Duration(seconds: 2));
        expect(segments[2].timelineStart, const Duration(seconds: 4));
        // Only the tail is trimmed; the full repeats play end to end.
        expect(segments[0].endTime, isNull);
        expect(segments[1].endTime, isNull);
        expect(segments[2].endTime, const Duration(seconds: 1));
      });

      test('does not overshoot when the backdrop divides the clip evenly', () {
        final segments = ChromaKeyBakeService.backdropSegments(
          path: '/a/backdrop.mp4',
          backdropDuration: const Duration(seconds: 3),
          coverDuration: const Duration(seconds: 6),
        );

        expect(segments, hasLength(2));
        expect(segments.last.endTime, isNull);
      });

      test('caps the repeats rather than building thousands of segments', () {
        final segments = ChromaKeyBakeService.backdropSegments(
          path: '/a/backdrop.mp4',
          backdropDuration: const Duration(milliseconds: 40),
          coverDuration: const Duration(seconds: 60),
        );

        expect(segments, hasLength(ChromaKeyBakeService.maxBackdropRepeats));
      });

      test('falls back to a single segment for an unknown duration', () {
        // Metadata can come back with a zero duration; looping on that would
        // spin until the cap and emit 60 identical segments.
        final segments = ChromaKeyBakeService.backdropSegments(
          path: '/a/backdrop.mp4',
          backdropDuration: Duration.zero,
          coverDuration: const Duration(seconds: 6),
        );

        expect(segments, hasLength(1));
        expect(segments.single.endTime, isNull);
      });
    });
  });
}
