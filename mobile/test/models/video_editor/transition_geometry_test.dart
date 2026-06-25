import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType, EditorVideo;

void main() {
  const dissolve = ClipTransition(type: ClipTransitionType.dissolve);
  const fadeToBlack = ClipTransition(type: ClipTransitionType.fadeToBlack);

  group('transitionConsumedPerSide', () {
    test('an overlap consumes twice its duration per side', () {
      final t = dissolve.copyWith(duration: const Duration(milliseconds: 400));
      expect(
        transitionConsumedPerSide(
          const Duration(seconds: 3),
          const Duration(seconds: 3),
          t,
        ),
        equals(const Duration(milliseconds: 800)),
      );
    });

    test('a dip consumes half its duration per side', () {
      final t = fadeToBlack.copyWith(duration: const Duration(seconds: 2));
      expect(
        transitionConsumedPerSide(
          const Duration(seconds: 3),
          const Duration(seconds: 3),
          t,
        ),
        equals(const Duration(seconds: 1)),
      );
    });

    test('clamps to the shorter of the two adjacent clips', () {
      final t = fadeToBlack.copyWith(duration: const Duration(seconds: 4));
      // Half of 4s = 2s, but the shorter clip is only 1s.
      expect(
        transitionConsumedPerSide(
          const Duration(seconds: 1),
          const Duration(seconds: 3),
          t,
        ),
        equals(const Duration(seconds: 1)),
      );
    });
  });

  group('transitionDurationForConsumed', () {
    test('inverts the overlap geometry (consumed × 0.5)', () {
      expect(
        transitionDurationForConsumed(
          const Duration(milliseconds: 800),
          ClipTransitionType.dissolve,
        ),
        equals(const Duration(milliseconds: 400)),
      );
    });

    test('inverts the dip geometry (consumed × 2)', () {
      expect(
        transitionDurationForConsumed(
          const Duration(milliseconds: 500),
          ClipTransitionType.fadeToBlack,
        ),
        equals(const Duration(seconds: 1)),
      );
    });

    test('returns zero when there is no room', () {
      expect(
        transitionDurationForConsumed(
          Duration.zero,
          ClipTransitionType.dissolve,
        ),
        equals(Duration.zero),
      );
      expect(
        transitionDurationForConsumed(
          const Duration(milliseconds: -10),
          ClipTransitionType.fadeToBlack,
        ),
        equals(Duration.zero),
      );
    });

    test('round-trips with transitionConsumedPerSide for in-bounds values', () {
      final t = dissolve.copyWith(duration: const Duration(milliseconds: 600));
      final consumed = transitionConsumedPerSide(
        const Duration(seconds: 5),
        const Duration(seconds: 5),
        t,
      );
      expect(
        transitionDurationForConsumed(consumed, ClipTransitionType.dissolve),
        equals(const Duration(milliseconds: 600)),
      );
    });
  });

  group('clampTransitions', () {
    DivineVideoClip clip(
      String id,
      Duration duration, {
      ClipTransition? transition,
      double? playbackSpeed,
    }) => DivineVideoClip(
      id: id,
      video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
      duration: duration,
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      transition: transition,
      playbackSpeed: playbackSpeed,
    );

    test('drops the transition on the last clip (no following boundary)', () {
      final clips = [
        clip('a', const Duration(seconds: 2)),
        clip('b', const Duration(seconds: 2), transition: dissolve),
      ];

      expect(clampTransitions(clips)['b'], isNull);
    });

    test('returns null for a clip with no transition', () {
      final clips = [
        clip('a', const Duration(seconds: 2)),
        clip('b', const Duration(seconds: 2)),
      ];

      expect(clampTransitions(clips)['a'], isNull);
    });

    test('passes an in-bounds overlap through unchanged', () {
      // Two 2s clips → overlap ceiling is half the shorter clip = 1s. 800ms is
      // within bounds.
      final eightHundred = dissolve.copyWith(
        duration: const Duration(milliseconds: 800),
      );
      final clips = [
        clip('a', const Duration(seconds: 2), transition: eightHundred),
        clip('b', const Duration(seconds: 2)),
      ];

      expect(clampTransitions(clips)['a'], equals(eightHundred));
    });

    test('clamps an overlap longer than half the shorter clip', () {
      final tooLong = dissolve.copyWith(
        duration: const Duration(milliseconds: 1500),
      );
      final clips = [
        clip('a', const Duration(seconds: 2), transition: tooLong),
        clip('b', const Duration(seconds: 2)),
      ];

      // Half the shorter (2s) clip = 1s.
      expect(
        clampTransitions(clips)['a']?.duration,
        equals(const Duration(seconds: 1)),
      );
    });

    test('lets a dip run up to twice the shorter clip', () {
      // Dips fade out then in (sequential), so a 1500ms dip on 2s clips
      // (ceiling 4s) is left unchanged where the same overlap would be clamped.
      final dip = fadeToBlack.copyWith(
        duration: const Duration(milliseconds: 1500),
      );
      final clips = [
        clip('a', const Duration(seconds: 2), transition: dip),
        clip('b', const Duration(seconds: 2)),
      ];

      expect(
        clampTransitions(clips)['a']?.duration,
        equals(const Duration(milliseconds: 1500)),
      );
    });

    test('clamps on playbackDuration for speed-changed clips', () {
      // A 2× clip of 4s source occupies 2s of playback → overlap ceiling 1s.
      final tooLong = dissolve.copyWith(
        duration: const Duration(milliseconds: 1500),
      );
      final clips = [
        clip(
          'a',
          const Duration(seconds: 4),
          transition: tooLong,
          playbackSpeed: 2,
        ),
        clip('b', const Duration(seconds: 4), playbackSpeed: 2),
      ];

      expect(
        clampTransitions(clips)['a']?.duration,
        equals(const Duration(seconds: 1)),
      );
    });

    test('splits a shared middle clip between two over-consuming dips', () {
      // 3×1s clips with 2s dips on both boundaries. Each dip alone would consume
      // the whole 1s middle clip; together they must not overlap, so each is
      // clamped to 1s (0.5s consumed per side → head + tail exactly fills the
      // middle clip). This is what fixes the "both halves the same color" bug.
      final dip2s = fadeToBlack.copyWith(duration: const Duration(seconds: 2));
      final clips = [
        clip('a', const Duration(seconds: 1), transition: dip2s),
        clip('b', const Duration(seconds: 1), transition: dip2s),
        clip('c', const Duration(seconds: 1)),
      ];

      final clamped = clampTransitions(clips);
      expect(clamped['a']?.duration, equals(const Duration(seconds: 1)));
      expect(clamped['b']?.duration, equals(const Duration(seconds: 1)));
      expect(clamped['c'], isNull);
    });

    test('splits a shared middle clip between two over-consuming overlaps', () {
      // 3×1s clips with a dissolve at the overlap ceiling (500ms) on both
      // boundaries. Each alone would consume the whole 1s middle clip, leaving
      // no solo body — and the native overlap (planOverlap) then falls back to
      // a hard cut, dropping the transition. Clamped, they split the clip: each
      // becomes 250ms so the middle keeps 500ms of solo body for both blends.
      final overlap500 = dissolve.copyWith(
        duration: const Duration(milliseconds: 500),
      );
      final clips = [
        clip('a', const Duration(seconds: 1), transition: overlap500),
        clip('b', const Duration(seconds: 1), transition: overlap500),
        clip('c', const Duration(seconds: 1)),
      ];

      final clamped = clampTransitions(clips);
      expect(clamped['a']?.duration, equals(const Duration(milliseconds: 250)));
      expect(clamped['b']?.duration, equals(const Duration(milliseconds: 250)));
    });

    test('does not reduce a single dip even when the middle clip is short', () {
      // Only the first boundary has a transition, so the 1s middle clip is
      // consumed from one side only — the dip keeps its full (in-bounds) length.
      final dip1s = fadeToBlack.copyWith(duration: const Duration(seconds: 1));
      final clips = [
        clip('a', const Duration(seconds: 1), transition: dip1s),
        clip('b', const Duration(seconds: 1)),
        clip('c', const Duration(seconds: 1)),
      ];

      final clamped = clampTransitions(clips);
      expect(clamped['a']?.duration, equals(const Duration(seconds: 1)));
    });

    test(
      'scales the two boundaries by their demand on an over-consumed clip',
      () {
        // The middle clip (1s) is over-consumed: its incoming dip wants 1s/side
        // (2s dip) and its outgoing overlap wants 1s/side (500ms dissolve). They
        // share the 1s budget proportionally to their equal demand → 0.5s each,
        // so neither side over-runs and the clip is split between them.
        final dip2s = fadeToBlack.copyWith(
          duration: const Duration(seconds: 2),
        );
        final overlap500 = dissolve.copyWith(
          duration: const Duration(milliseconds: 500),
        );
        final clips = [
          clip('a', const Duration(seconds: 1), transition: dip2s),
          clip('b', const Duration(seconds: 1), transition: overlap500),
          clip('c', const Duration(seconds: 1)),
        ];

        final clamped = clampTransitions(clips);
        // Dip: 0.5s consumed → duration 1s. Overlap: 0.5s consumed → duration
        // 250ms.
        expect(clamped['a']?.duration, equals(const Duration(seconds: 1)));
        expect(
          clamped['b']?.duration,
          equals(const Duration(milliseconds: 250)),
        );
      },
    );
  });

  group('output timeline', () {
    DivineVideoClip clip(
      String id,
      Duration duration, {
      ClipTransition? transition,
    }) => DivineVideoClip(
      id: id,
      video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
      duration: duration,
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      transition: transition,
    );

    group('renderedOutputDuration', () {
      test('subtracts the blend of an overlap from the total', () {
        // 2×1s with a 500ms dissolve → the blend removes 500ms → 1.5s.
        final overlap500 = dissolve.copyWith(
          duration: const Duration(milliseconds: 500),
        );
        final clips = [
          clip('a', const Duration(seconds: 1), transition: overlap500),
          clip('b', const Duration(seconds: 1)),
        ];

        expect(
          renderedOutputDuration(clips),
          equals(const Duration(milliseconds: 1500)),
        );
      });

      test('leaves the total unchanged for dips', () {
        // Dips fade out then in without overlapping, so the timeline length is
        // unchanged: 3×1s with two dips stays 3s.
        final dip = fadeToBlack.copyWith(duration: const Duration(seconds: 1));
        final clips = [
          clip('a', const Duration(seconds: 1), transition: dip),
          clip('b', const Duration(seconds: 1), transition: dip),
          clip('c', const Duration(seconds: 1)),
        ];

        expect(
          renderedOutputDuration(clips),
          equals(const Duration(seconds: 3)),
        );
      });

      test('equals the sum when there are no transitions', () {
        final clips = [
          clip('a', const Duration(seconds: 1)),
          clip('b', const Duration(milliseconds: 500)),
        ];

        expect(
          renderedOutputDuration(clips),
          equals(const Duration(milliseconds: 1500)),
        );
      });
    });

    group('editorToOutputPosition', () {
      // 2×1s with a 500ms dissolve: editor axis 0..2s, output axis 0..1.5s.
      // The blend covers editor [0.5s, 1.5s] (2×500ms) → 500ms of output.
      final overlap500 = dissolve.copyWith(
        duration: const Duration(milliseconds: 500),
      );
      final clips = [
        clip('a', const Duration(seconds: 1), transition: overlap500),
        clip('b', const Duration(seconds: 1)),
      ];

      test('is the identity before the blend region', () {
        expect(
          editorToOutputPosition(clips, const Duration(milliseconds: 250)),
          equals(const Duration(milliseconds: 250)),
        );
      });

      test('compresses 2:1 inside the blend region', () {
        // Boundary at editor 1s is the blend midpoint → output 0.75s.
        expect(
          editorToOutputPosition(clips, const Duration(seconds: 1)),
          equals(const Duration(milliseconds: 750)),
        );
      });

      test('maps the editor end onto the output end', () {
        expect(
          editorToOutputPosition(clips, const Duration(seconds: 2)),
          equals(const Duration(milliseconds: 1500)),
        );
      });

      test('is the identity when no transition shortens the timeline', () {
        final plain = [
          clip('a', const Duration(seconds: 1)),
          clip('b', const Duration(seconds: 1)),
        ];

        expect(
          editorToOutputPosition(plain, const Duration(milliseconds: 1500)),
          equals(const Duration(milliseconds: 1500)),
        );
      });
    });

    group('outputToEditorPosition', () {
      // 2×1s with a 500ms dissolve: editor axis 0..2s, output axis 0..1.5s.
      // The blend covers editor [0.5s, 1.5s] (2×500ms) → 500ms of output.
      final overlap500 = dissolve.copyWith(
        duration: const Duration(milliseconds: 500),
      );
      final clips = [
        clip('a', const Duration(seconds: 1), transition: overlap500),
        clip('b', const Duration(seconds: 1)),
      ];

      test('is the identity before the blend region', () {
        expect(
          outputToEditorPosition(clips, const Duration(milliseconds: 250)),
          equals(const Duration(milliseconds: 250)),
        );
      });

      test('expands 1:2 inside the blend region', () {
        // Output 0.75s sits at the blend midpoint → editor boundary 1s.
        expect(
          outputToEditorPosition(clips, const Duration(milliseconds: 750)),
          equals(const Duration(seconds: 1)),
        );
      });

      test('maps the output end onto the editor end', () {
        expect(
          outputToEditorPosition(clips, const Duration(milliseconds: 1500)),
          equals(const Duration(seconds: 2)),
        );
      });

      test('clamps a negative output to zero', () {
        expect(
          outputToEditorPosition(clips, const Duration(milliseconds: -100)),
          equals(Duration.zero),
        );
      });

      test('round-trips with editorToOutputPosition', () {
        for (final editorMs in [0, 250, 500, 750, 1000, 1250, 1500, 2000]) {
          final editor = Duration(milliseconds: editorMs);
          final output = editorToOutputPosition(clips, editor);
          expect(
            outputToEditorPosition(clips, output),
            equals(editor),
            reason: 'editor ${editorMs}ms should survive a round-trip',
          );
        }
      });

      test('is the identity when no transition shortens the timeline', () {
        final plain = [
          clip('a', const Duration(seconds: 1)),
          clip('b', const Duration(seconds: 1)),
        ];

        expect(
          outputToEditorPosition(plain, const Duration(milliseconds: 1500)),
          equals(const Duration(milliseconds: 1500)),
        );
      });
    });

    group(TransitionTimelineMap, () {
      final overlap500 = dissolve.copyWith(
        duration: const Duration(milliseconds: 500),
      );

      test('exposes editor and output durations for an overlap', () {
        final map = TransitionTimelineMap.fromClips([
          clip('a', const Duration(seconds: 1), transition: overlap500),
          clip('b', const Duration(seconds: 1)),
        ]);

        expect(map.editorDuration, equals(const Duration(seconds: 2)));
        expect(map.outputDuration, equals(const Duration(milliseconds: 1500)));
      });

      test('editor and output durations match for a dip', () {
        final dip500 = fadeToBlack.copyWith(
          duration: const Duration(milliseconds: 500),
        );
        final map = TransitionTimelineMap.fromClips([
          clip('a', const Duration(seconds: 1), transition: dip500),
          clip('b', const Duration(seconds: 1)),
        ]);

        expect(map.editorDuration, equals(map.outputDuration));
      });
    });
  });
}
