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
    DivineVideoClip sized(String id, Duration duration) => DivineVideoClip(
      id: id,
      video: editor.EditorVideo.file(File('/tmp/$id.mp4')),
      duration: duration,
      recordedAt: DateTime(2024),
      targetAspectRatio: model.AspectRatio.square,
      originalAspectRatio: 1,
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
        'transition, never exceeding half the clip', () {
      final spans = service.computeSeamSpans(
        sized('a', const Duration(milliseconds: 200)),
        sized('b', const Duration(seconds: 3)),
        dissolve, // 500ms, longer than the 200ms clip
      );

      // Clamped to half the 200ms clip; still blends (blend < consumed).
      expect(spans.consumed, equals(const Duration(milliseconds: 100)));
      expect(spans.blend, equals(const Duration(milliseconds: 50)));
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
      // 100ms/side → dip clamped to the 200ms span, not the 500ms request.
      expect(short.consumed, equals(const Duration(milliseconds: 100)));
      expect(short.blend, equals(const Duration(milliseconds: 200)));
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
  });
}
