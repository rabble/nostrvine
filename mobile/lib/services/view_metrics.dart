// ABOUTME: Pure view/loop/session metric definitions per 2026-08-13 spec.
// ABOUTME: No I/O, no Flutter — only arithmetic and predicates testable in isolation.

import 'dart:math' as math;

/// Metric definitions per `2026-08-13-view-and-loop-metrics-design.md`.
///
/// loop   := one playthrough fraction (completed + partial)
/// view   := one playback start, deduplicated per viewing session
/// session:= a continuous period of engagement with one video by one viewer
///
/// One session emits one view and N loops where N is frequently zero.
class ViewMetrics {
  const ViewMetrics._();

  /// Whether a session with [loopCount] loops and a view should exist.
  ///
  /// A view is a playback start. A session exists whenever playback started,
  /// regardless of whether any loop completed. N=0 (view with zero loops)
  /// is valid and common — 91% of view_counts rows have fewer loops than views.
  static bool isValidSession({required bool playbackStarted}) =>
      playbackStarted;

  /// Validates that a view event's loop count is admissible.
  ///
  /// Loops are fractional (Float64/Float32), not integral. Fractional values
  /// like 0.75 or 2.4 are legitimate partial playthroughs. The median signed
  /// view event is 0.75. Only negative values are invalid.
  static bool isValidLoopCount(double? loopCount) {
    if (loopCount == null) return true;
    return loopCount >= 0;
  }

  /// Display path: raw sum, no filtering (Decision 5).
  ///
  /// A displayed number is never reduced — no damping, capping, or silent
  /// dedup. Withholding (hiding below a floor) is the only legitimate gate
  /// and it happens elsewhere ([publicLoopCountFloor]).
  static double displayLoopsSum(Iterable<double> loops) =>
      loops.fold(0, (sum, v) => sum + v);

  static int displayViewsSum(Iterable<int> views) =>
      views.fold(0, (sum, v) => sum + v);

  /// Ranking path: damps loops, trusts views (Decision 6).
  ///
  /// Retained from current behaviour: log1p(loops) * 0.5. A single session
  /// with 218 loops must not outrank many distinct viewers.
  static double rankingScore({
    required double loops,
    required int views,
    double loopsWeight = 0.5,
  }) {
    final loopTerm = math.log(1 + loops) * loopsWeight;
    return loopTerm + views;
  }

  /// Whether loops >= views — asserted to be FALSE in general.
  ///
  /// This helper exists only so tests can pin that the inequality does NOT
  /// hold. Do not use it as an invariant.
  static bool loopsGreaterOrEqualViews({
    required double loops,
    required int views,
  }) => loops >= views;
}
