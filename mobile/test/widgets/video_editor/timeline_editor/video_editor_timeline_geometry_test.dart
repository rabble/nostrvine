// ABOUTME: Unit tests for the pure timeline geometry helpers.
// ABOUTME: Verifies scroll-offset ↔ playback-position conversion symmetry
// ABOUTME: across single-clip, multi-clip, and empty-clip compositions.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _clip(String id, int seconds, {double? speed}) =>
    DivineVideoClip(
      id: id,
      video: EditorVideo.file('/tmp/$id.mp4'),
      duration: Duration(seconds: seconds),
      recordedAt: DateTime(2025),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
      playbackSpeed: speed,
    );

void main() {
  // Three-clip composition used throughout most tests:
  //   clip 0 → 2 s, clip 1 → 3 s, clip 2 → 2 s  (total 7 s)
  // At pixelsPerSecond=52 and clipGap=1 the layout is:
  //   [0…104 px] gap [105…260 px] gap [261…365 px]
  //
  // Position → offset reference table
  //   pos  0 s  → 0 * 52 + 0 gaps =   0 px
  //   pos  1 s  → 1 * 52 + 0 gaps =  52 px  (within clip 0)
  //   pos  2 s  → 2 * 52 + 1 gap  = 105 px  (start of gap after clip 0)
  //   pos  2.5s → 2.5*52 + 1 gap  = 131 px  (within clip 1)
  //   pos  5 s  → 5 * 52 + 2 gaps = 262 px  (start of gap after clip 1)
  //   pos  6 s  → 6 * 52 + 2 gaps = 314 px  (within clip 2)

  final clips = [
    _clip('c0', 2),
    _clip('c1', 3),
    _clip('c2', 2),
  ];
  const pps = 52.0;
  const totalDuration = Duration(seconds: 7);

  group(timelinePositionToScrollOffset, () {
    test('returns 0 for zero position', () {
      expect(
        timelinePositionToScrollOffset(clips, Duration.zero, pps),
        equals(0.0),
      );
    });

    test('no gap offset within first clip', () {
      expect(
        timelinePositionToScrollOffset(clips, const Duration(seconds: 1), pps),
        equals(52.0),
      );
    });

    test('adds one gap at the boundary between clip 0 and clip 1', () {
      expect(
        timelinePositionToScrollOffset(clips, const Duration(seconds: 2), pps),
        equals(105.0), // 2 * 52 + 1
      );
    });

    test('one gap within clip 1', () {
      expect(
        timelinePositionToScrollOffset(
          clips,
          const Duration(milliseconds: 2500),
          pps,
        ),
        equals(131.0), // 2.5 * 52 + 1
      );
    });

    test('adds two gaps at the boundary between clip 1 and clip 2', () {
      expect(
        timelinePositionToScrollOffset(clips, const Duration(seconds: 5), pps),
        equals(262.0), // 5 * 52 + 2
      );
    });

    test('two gaps within clip 2', () {
      expect(
        timelinePositionToScrollOffset(clips, const Duration(seconds: 6), pps),
        equals(314.0), // 6 * 52 + 2
      );
    });

    test('does not add a trailing gap at total duration', () {
      expect(
        timelinePositionToScrollOffset(clips, totalDuration, pps),
        equals(366.0), // 7 * 52 + 2
      );
    });

    test('empty clip list — no gaps added', () {
      expect(
        timelinePositionToScrollOffset([], const Duration(seconds: 3), pps),
        equals(156.0), // 3 * 52
      );
    });

    test('single clip — no gaps', () {
      expect(
        timelinePositionToScrollOffset(
          [_clip('only', 10)],
          const Duration(seconds: 4),
          pps,
        ),
        equals(208.0), // 4 * 52
      );
    });
  });

  group(timelineScrollOffsetToPosition, () {
    test('returns zero for zero offset', () {
      expect(
        timelineScrollOffsetToPosition(clips, 0.0, pps, totalDuration),
        equals(Duration.zero),
      );
    });

    test('no gap correction within first clip', () {
      expect(
        timelineScrollOffsetToPosition(clips, 52.0, pps, totalDuration),
        equals(const Duration(seconds: 1)),
      );
    });

    test('subtracts one gap at clip 0/1 boundary', () {
      expect(
        timelineScrollOffsetToPosition(clips, 105.0, pps, totalDuration),
        equals(const Duration(seconds: 2)),
      );
    });

    test('maps offsets inside the clip 0/1 gap to the shared boundary', () {
      expect(
        timelineScrollOffsetToPosition(clips, 104.5, pps, totalDuration),
        equals(const Duration(seconds: 2)),
      );
    });

    test('subtracts one gap within clip 1', () {
      expect(
        timelineScrollOffsetToPosition(clips, 131.0, pps, totalDuration),
        equals(const Duration(milliseconds: 2500)),
      );
    });

    test('subtracts two gaps at clip 1/2 boundary', () {
      expect(
        timelineScrollOffsetToPosition(clips, 262.0, pps, totalDuration),
        equals(const Duration(seconds: 5)),
      );
    });

    test('maps offsets inside the clip 1/2 gap to the shared boundary', () {
      expect(
        timelineScrollOffsetToPosition(clips, 261.5, pps, totalDuration),
        equals(const Duration(seconds: 5)),
      );
    });

    test('subtracts two gaps within clip 2', () {
      expect(
        timelineScrollOffsetToPosition(clips, 314.0, pps, totalDuration),
        equals(const Duration(seconds: 6)),
      );
    });

    test('clamps negative offsets to Duration.zero', () {
      expect(
        timelineScrollOffsetToPosition(clips, -10.0, pps, totalDuration),
        equals(Duration.zero),
      );
    });

    test('clamps offsets beyond end to totalDuration', () {
      expect(
        timelineScrollOffsetToPosition(clips, 99999.0, pps, totalDuration),
        equals(totalDuration),
      );
    });

    test('maps the exact end offset back to total duration', () {
      expect(
        timelineScrollOffsetToPosition(clips, 366.0, pps, totalDuration),
        equals(totalDuration),
      );
    });

    test('empty clip list — no gap subtraction', () {
      expect(
        timelineScrollOffsetToPosition(
          [],
          156.0,
          pps,
          const Duration(seconds: 10),
        ),
        equals(const Duration(seconds: 3)),
      );
    });
  });

  group(
    'round-trip: scrollOffsetToPosition ∘ positionToScrollOffset == id',
    () {
      for (final pos in [
        Duration.zero,
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(milliseconds: 2500),
        const Duration(seconds: 5),
        const Duration(seconds: 6),
        totalDuration,
      ]) {
        test('position $pos survives round-trip', () {
          final offset = timelinePositionToScrollOffset(clips, pos, pps);
          final recovered = timelineScrollOffsetToPosition(
            clips,
            offset,
            pps,
            totalDuration,
          );
          expect(recovered, equals(pos));
        });
      }
    },
  );

  // Regression for the pinch-zoom drift fix in `_updatePinchZoom`.
  //
  // Old bug: zoom preserved scroll by `_scrollController.offset * ratio`,
  // which over-shoots by `clipsPassed × clipGap × (ratio - 1)` px once the
  // playhead is past clip 0 (gaps stay 1 px, they don't scale with pps).
  //
  // New behavior re-anchors through the gap-aware helpers: derive the
  // current playback position at the old pps, then map it back to a scroll
  // offset at the new pps. The composite position must remain stable.
  group('pinch-zoom anchoring keeps playhead position stable', () {
    const newPps = 104.0; // 2× zoom-in

    for (final pos in [
      const Duration(milliseconds: 2500), // inside clip 1
      const Duration(seconds: 5), // boundary clip 1/2
      const Duration(seconds: 6), // inside clip 2
    ]) {
      test('position $pos stays centered across pps change', () {
        // Simulate the playhead sitting at `pos` at the old pps.
        final oldOffset = timelinePositionToScrollOffset(clips, pos, pps);

        // What the new gap-aware pinch logic would jump to:
        final anchorPosition = timelineScrollOffsetToPosition(
          clips,
          oldOffset,
          pps,
          totalDuration,
        );
        final newOffset = timelinePositionToScrollOffset(
          clips,
          anchorPosition,
          newPps,
        );

        // The recovered position at the new pps must match the original.
        final recovered = timelineScrollOffsetToPosition(
          clips,
          newOffset,
          newPps,
          totalDuration,
        );
        expect(recovered, equals(pos));

        // Sanity: the naive `oldOffset * ratio` path drifts (proving the
        // gap-aware re-anchor is doing real work past clip 0).
        const ratio = newPps / pps;
        final naiveOffset = oldOffset * ratio;
        expect(
          naiveOffset,
          isNot(equals(newOffset)),
          reason:
              'Past clip 0 the naive scroll-rescale must differ from the '
              'gap-aware anchoring; otherwise the regression would be '
              'silently lost.',
        );
      });
    }
  });

  group('DivineVideoClip.playbackDuration', () {
    test('null speed → same as trimmedDuration', () {
      final clip = _clip('a', 10);
      expect(clip.playbackDuration, equals(clip.trimmedDuration));
    });

    test('speed 1.0 → same as trimmedDuration', () {
      final clip = _clip('a', 10, speed: 1.0);
      expect(clip.playbackDuration, equals(clip.trimmedDuration));
    });

    test('speed 2.0 → half of trimmedDuration', () {
      final clip = _clip('a', 10, speed: 2.0);
      expect(clip.playbackDuration, equals(const Duration(seconds: 5)));
    });

    test('speed 0.5 → double of trimmedDuration', () {
      final clip = _clip('a', 10, speed: 0.5);
      expect(clip.playbackDuration, equals(const Duration(seconds: 20)));
    });

    test('playbackDurationInSeconds matches playbackDuration', () {
      final clip = _clip('a', 10, speed: 2.0);
      expect(clip.playbackDurationInSeconds, equals(5.0));
    });
  });

  group('speed-aware geometry', () {
    // Two-clip composition: clip 0 is 10 s at 2×speed (→ 5 s wide),
    // clip 1 is 4 s at 1×speed (→ 4 s wide).  Total playback = 9 s.
    final speedClips = [
      _clip('fast', 10, speed: 2.0),
      _clip('normal', 4),
    ];
    const speedPps = 52.0;
    const speedTotal = Duration(seconds: 9);

    test('positionToOffset: 0 s → 0 px', () {
      expect(
        timelinePositionToScrollOffset(speedClips, Duration.zero, speedPps),
        equals(0.0),
      );
    });

    test('positionToOffset: 5 s (end of fast clip) → 261 px (5*52 + gap)', () {
      // 5 s * 52 pps = 260, + 1 gap = 261
      expect(
        timelinePositionToScrollOffset(
          speedClips,
          const Duration(seconds: 5),
          speedPps,
        ),
        equals(261.0),
      );
    });

    test('positionToOffset: 2.5 s (mid fast clip) → 130 px (no gap yet)', () {
      expect(
        timelinePositionToScrollOffset(
          speedClips,
          const Duration(milliseconds: 2500),
          speedPps,
        ),
        equals(130.0),
      );
    });

    test('positionToOffset: 7 s (mid normal clip) → 365 px', () {
      // 7 s * 52 + 1 gap = 364 + 1 = 365
      expect(
        timelinePositionToScrollOffset(
          speedClips,
          const Duration(seconds: 7),
          speedPps,
        ),
        equals(365.0),
      );
    });

    test('round-trip at 5 s boundary with speed', () {
      const pos = Duration(seconds: 5);
      final offset = timelinePositionToScrollOffset(speedClips, pos, speedPps);
      final recovered = timelineScrollOffsetToPosition(
        speedClips,
        offset,
        speedPps,
        speedTotal,
      );
      expect(recovered, equals(pos));
    });

    test('round-trip at 7 s with speed', () {
      const pos = Duration(seconds: 7);
      final offset = timelinePositionToScrollOffset(speedClips, pos, speedPps);
      final recovered = timelineScrollOffsetToPosition(
        speedClips,
        offset,
        speedPps,
        speedTotal,
      );
      expect(recovered, equals(pos));
    });
  });
}
