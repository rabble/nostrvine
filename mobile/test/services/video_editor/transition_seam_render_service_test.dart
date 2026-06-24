import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/transition_seam_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  DivineVideoClip clip(String id, {editor.ClipTransition? transition}) =>
      DivineVideoClip(
        id: id,
        video: editor.EditorVideo.file(File('/tmp/$id.mp4')),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 1,
        transition: transition,
      );

  // pro_video_editor's ClipTransition defaults to a 500ms duration.
  const dissolve = editor.ClipTransition(
    type: editor.ClipTransitionType.dissolve,
  );

  group('buildSeamAwarePlayerClips', () {
    test('plays plain clips when no transition is set', () {
      final clips = [clip('a'), clip('b')];
      final result = buildSeamAwarePlayerClips(
        clips,
        TransitionSeamRenderService(),
      );

      expect(result, hasLength(2));
      expect(result[0].uri, equals('/tmp/a.mp4'));
      expect(result[1].uri, equals('/tmp/b.mp4'));
    });

    test('hard-cuts (full clips, no seam) until the seam is rendered', () {
      final clips = [clip('a', transition: dissolve), clip('b')];
      final result = buildSeamAwarePlayerClips(
        clips,
        TransitionSeamRenderService(),
      );

      // No cached seam → 2 untrimmed clips, no seam clip spliced in.
      expect(result, hasLength(2));
      expect(result[0].end, equals(const Duration(seconds: 3)));
      expect(result[1].start, equals(Duration.zero));
    });

    test('splices the rendered seam between trimmed neighbours', () {
      final clipA = clip('a', transition: dissolve);
      final clipB = clip('b');
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          clipA,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 500),
            tailConsumed: Duration(milliseconds: 500),
            headConsumed: Duration(milliseconds: 500),
          ),
        );

      final result = buildSeamAwarePlayerClips([clipA, clipB], service);

      expect(result, hasLength(3));
      // Clip A body: [0, 2500ms] (last 500ms went into the seam).
      expect(result[0].uri, equals('/tmp/a.mp4'));
      expect(result[0].start, equals(Duration.zero));
      expect(result[0].end, equals(const Duration(milliseconds: 2500)));
      // The seam.
      expect(result[1].uri, equals('/tmp/seam.mp4'));
      // Clip B body: [500ms, 3000ms] (first 500ms went into the seam).
      expect(result[2].uri, equals('/tmp/b.mp4'));
      expect(result[2].start, equals(const Duration(milliseconds: 500)));
      expect(result[2].end, equals(const Duration(seconds: 3)));
    });
  });

  group('computeSeamSpans', () {
    DivineVideoClip sized(
      String id,
      Duration duration, {
      double? playbackSpeed,
    }) => DivineVideoClip(
      id: id,
      video: editor.EditorVideo.file(File('/tmp/$id.mp4')),
      duration: duration,
      recordedAt: DateTime(2024),
      targetAspectRatio: model.AspectRatio.square,
      originalAspectRatio: 1,
      playbackSpeed: playbackSpeed,
    );

    final service = TransitionSeamRenderService();

    test('overlap uses 2× blend with a solo lead-in/out on long clips', () {
      final spans = service.computeSeamSpans(
        sized('a', const Duration(seconds: 3)),
        sized('b', const Duration(seconds: 3)),
        dissolve,
      );

      expect(spans.consumed, equals(const Duration(seconds: 1)));
      expect(spans.blend, equals(const Duration(milliseconds: 500)));
      // Solo lead = consumed - blend > 0 → never a degenerate hard cut.
      expect(spans.blend, lessThan(spans.consumed));
      expect(spans.seamTransition.duration, equals(spans.blend));
    });

    test('overlap shrinks proportionally on a clip shorter than the '
        'transition, never exceeding the shorter clip', () {
      final spans = service.computeSeamSpans(
        sized('a', const Duration(milliseconds: 200)),
        sized('b', const Duration(seconds: 3)),
        dissolve, // 500ms, longer than the 200ms clip
      );

      // Clamped to the whole 200ms clip; still blends (blend < consumed).
      expect(spans.consumed, equals(const Duration(milliseconds: 200)));
      expect(spans.blend, equals(const Duration(milliseconds: 100)));
      expect(spans.blend, lessThan(spans.consumed));
    });

    test('dip takes half the duration per side and cannot outrun the span', () {
      const fadeToBlack = editor.ClipTransition(
        type: editor.ClipTransitionType.fadeToBlack,
      );

      final long = service.computeSeamSpans(
        sized('a', const Duration(seconds: 3)),
        sized('b', const Duration(seconds: 3)),
        fadeToBlack,
      );
      expect(long.consumed, equals(const Duration(milliseconds: 250)));
      expect(long.blend, equals(const Duration(milliseconds: 500)));

      final short = service.computeSeamSpans(
        sized('a', const Duration(milliseconds: 200)),
        sized('b', const Duration(milliseconds: 200)),
        fadeToBlack,
      );
      // 200ms/side available → dip clamped to 2× the span, not the 500ms
      // request.
      expect(short.consumed, equals(const Duration(milliseconds: 200)));
      expect(short.blend, equals(const Duration(milliseconds: 400)));
    });

    test('clamps on playbackDuration, not source, for speed-changed clips', () {
      // 4× clips of 2s source each occupy only 500ms of wall-clock time, so the
      // overlap must clamp to that playback span (consumed 500ms, blend 250ms)
      // — not the 2s source span the trimmed-duration basis would have used
      // (which would have allowed the full 1000ms consumed / 500ms blend).
      final spans = service.computeSeamSpans(
        sized('a', const Duration(seconds: 2), playbackSpeed: 4),
        sized('b', const Duration(seconds: 2), playbackSpeed: 4),
        dissolve, // 500ms
      );

      expect(spans.consumed, equals(const Duration(milliseconds: 500)));
      expect(spans.blend, equals(const Duration(milliseconds: 250)));
      expect(spans.blend, lessThan(spans.consumed));
      expect(spans.seamTransition.duration, equals(spans.blend));
    });
  });

  group('cached', () {
    test('reversing a clip swaps the file path and invalidates the seam', () {
      final forward = clip('a', transition: dissolve);
      // Reverse swaps `video` to the physically-reversed file (here with
      // symmetric trims, so the trim-based key alone would not change).
      final reversed = forward.copyWith(
        video: editor.EditorVideo.file(File('/tmp/a_reversed.mp4')),
      );
      final clipB = clip('b');
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          forward,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 1500),
            tailConsumed: Duration(milliseconds: 1000),
            headConsumed: Duration(milliseconds: 1000),
          ),
        );

      expect(service.cached(forward, clipB, dissolve), isNotNull);
      expect(service.cached(reversed, clipB, dissolve), isNull);
    });

    test('changing a clip volume invalidates the seam', () {
      // Volume is baked into the rendered seam audio, so a mute (or any volume
      // change) after caching must miss the cache and re-render.
      final fullVolume = clip('a', transition: dissolve);
      final muted = fullVolume.copyWith(volume: 0);
      final clipB = clip('b');
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          fullVolume,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 1500),
            tailConsumed: Duration(milliseconds: 1000),
            headConsumed: Duration(milliseconds: 1000),
          ),
        );

      expect(service.cached(fullVolume, clipB, dissolve), isNotNull);
      expect(service.cached(muted, clipB, dissolve), isNull);
    });

    test('changing a clip duration invalidates the seam', () {
      // `duration` can be trimmed independently of the file (clip_manager caps
      // a clip on add) and `_tailClip`/`_headClip` read it, so it must be part
      // of the key.
      final original = clip('a', transition: dissolve);
      final longer = original.copyWith(duration: const Duration(seconds: 4));
      final clipB = clip('b');
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          original,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 1500),
            tailConsumed: Duration(milliseconds: 1000),
            headConsumed: Duration(milliseconds: 1000),
          ),
        );

      expect(service.cached(original, clipB, dissolve), isNotNull);
      expect(service.cached(longer, clipB, dissolve), isNull);
    });

    test('changing the target aspect ratio invalidates the seam', () {
      // The seam is rendered (and cropped) to the clip's target aspect ratio,
      // so switching it must re-render rather than reuse the old crop.
      final square = clip('a', transition: dissolve);
      final vertical = square.copyWith(
        targetAspectRatio: model.AspectRatio.vertical,
      );
      final clipB = clip('b');
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          square,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 1500),
            tailConsumed: Duration(milliseconds: 1000),
            headConsumed: Duration(milliseconds: 1000),
          ),
        );

      expect(service.cached(square, clipB, dissolve), isNotNull);
      expect(service.cached(vertical, clipB, dissolve), isNull);
    });
  });

  group('SeamTimeline', () {
    test('is the identity when no seam is spliced', () {
      final timeline = SeamTimeline(
        [clip('a'), clip('b')],
        TransitionSeamRenderService(),
      );

      expect(timeline.hasSeams, isFalse);
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 2500)),
        equals(const Duration(milliseconds: 2500)),
      );
    });

    test('maps the mid-seam position onto the clip boundary', () {
      // 500ms dissolve on 3s clips → consumed 1000ms/side, seam 1500ms.
      final clipA = clip('a', transition: dissolve);
      final clipB = clip('b');
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          clipA,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 1500),
            tailConsumed: Duration(milliseconds: 1000),
            headConsumed: Duration(milliseconds: 1000),
          ),
        );
      final timeline = SeamTimeline([clipA, clipB], service);

      expect(timeline.hasSeams, isTrue);
      // Body of clip A ends at composite 2000ms → editor 2000ms.
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 2000)),
        equals(const Duration(milliseconds: 2000)),
      );
      // Mid-seam (composite 2750ms) lands on the boundary (editor 3000ms).
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 2750)),
        equals(const Duration(seconds: 3)),
      );
      // Composite end (5500ms) → editor end (6000ms).
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 5500)),
        equals(const Duration(seconds: 6)),
      );
      // Round-trips through the boundary.
      expect(
        timeline.timelineToComposite(const Duration(seconds: 3)),
        equals(const Duration(milliseconds: 2750)),
      );
    });

    test('keeps the editor axis monotonic when a short middle clip is fully '
        'consumed by seams on both boundaries', () {
      DivineVideoClip sized(
        String id,
        Duration duration, {
        editor.ClipTransition? transition,
      }) => DivineVideoClip(
        id: id,
        video: editor.EditorVideo.file(File('/tmp/$id.mp4')),
        duration: duration,
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 1,
        transition: transition,
      );

      // A=5s, B=600ms, C=5s, dissolve on A->B and B->C. The 600ms clip B is
      // fully consumed from both sides, so its editor span is claimed by both
      // seams — the case that used to push the editor axis backward.
      final clipA = sized(
        'a',
        const Duration(seconds: 5),
        transition: dissolve,
      );
      final clipB = sized(
        'b',
        const Duration(milliseconds: 600),
        transition: dissolve,
      );
      final clipC = sized('c', const Duration(seconds: 5));

      const seamSpan = TransitionSeam(
        path: '/tmp/seam.mp4',
        duration: Duration(milliseconds: 900),
        tailConsumed: Duration(milliseconds: 600),
        headConsumed: Duration(milliseconds: 600),
      );
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(clipA, clipB, dissolve, seamSpan)
        ..cacheSeamForTest(clipB, clipC, dissolve, seamSpan);
      final timeline = SeamTimeline([clipA, clipB, clipC], service);

      // Sweep the whole composite axis; the mapped editor position must never
      // go backward.
      var previous = Duration.zero;
      for (var ms = 0; ms <= 15000; ms += 50) {
        final mapped = timeline.compositeToTimeline(Duration(milliseconds: ms));
        expect(
          mapped,
          greaterThanOrEqualTo(previous),
          reason: 'editor axis went backward at composite ${ms}ms',
        );
        previous = mapped;
      }

      // Pin the regression directly: the A->B and B->C seams meet around
      // composite 5300ms; the playhead jumped ~600ms back across that junction
      // before the fix.
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 5301)),
        greaterThanOrEqualTo(
          timeline.compositeToTimeline(const Duration(milliseconds: 5299)),
        ),
      );
    });
  });
}
