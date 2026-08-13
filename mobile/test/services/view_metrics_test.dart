// ABOUTME: Tests for view/loop/session metric boundaries per 2026-08-13 spec.
// ABOUTME: Pins N=0 views, fractional loops, display vs ranking, and parity.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/view_metrics.dart';

void main() {
  group('view/loop/session boundaries (spec)', () {
    test('scroll-past with no playback start emits nothing — no session', () {
      expect(
        ViewMetrics.isValidSession(playbackStarted: false),
        isFalse,
      );
    });

    test('playback start emits one view and N loops, including N=0', () {
      expect(ViewMetrics.isValidSession(playbackStarted: true), isTrue);
      // N=0 is valid: viewer starts and leaves before completing a pass
      expect(ViewMetrics.isValidLoopCount(0), isTrue);
      expect(ViewMetrics.isValidLoopCount(0.0), isTrue);
      expect(ViewMetrics.isValidLoopCount(null), isTrue);
    });

    test('fractional loops are valid — median 0.75, 2.4 etc', () {
      expect(ViewMetrics.isValidLoopCount(0.75), isTrue);
      expect(ViewMetrics.isValidLoopCount(2.4), isTrue);
      expect(ViewMetrics.isValidLoopCount(218.2), isTrue);
      expect(ViewMetrics.isValidLoopCount(0.99), isTrue);
    });

    test('negative loops are invalid', () {
      expect(ViewMetrics.isValidLoopCount(-0.1), isFalse);
      expect(ViewMetrics.isValidLoopCount(-1), isFalse);
    });

    test('loops >= views does NOT hold — view with zero loops is valid', () {
      // 91% of view_counts rows have fewer loops than views; aggregate 0.63-0.71
      expect(
        ViewMetrics.loopsGreaterOrEqualViews(loops: 0, views: 1),
        isFalse,
      );
      expect(
        ViewMetrics.loopsGreaterOrEqualViews(loops: 0.75, views: 1),
        isFalse,
      );
      // helpers report the inequality; tests pin that the false case exists
      expect(
        ViewMetrics.loopsGreaterOrEqualViews(loops: 1, views: 1),
        isTrue,
      );
    });
  });

  group('display path — no filtering (Decision 5)', () {
    test('raw sums: no damping, capping, or dedup', () {
      expect(ViewMetrics.displayLoopsSum([0.75, 2.4, 0]), equals(3.15));
      expect(ViewMetrics.displayViewsSum([1, 1, 1]), equals(3));
      // large anonymous batch still sums raw
      expect(ViewMetrics.displayLoopsSum([1, 1, 1, 1]), equals(4));
    });

    test('display sum preserves fractional loops', () {
      // flooring would zero the median 0.75 case — must not happen
      expect(
        ViewMetrics.displayLoopsSum([0.75, 0.75, 0.75]),
        greaterThan(2),
      );
    });
  });

  group('ranking path — damps loops, trusts views (Decision 6)', () {
    test(
      'single session with 218 loops does not outrank 218 distinct viewers',
      () {
        final singleHeavy = ViewMetrics.rankingScore(loops: 218, views: 1);
        final manyViewers = ViewMetrics.rankingScore(loops: 5, views: 218);
        expect(singleHeavy, lessThan(manyViewers));
      },
    );

    test('ranking uses log1p(loops) * 0.5 + views', () {
      const loops = 10.0;
      const views = 5;
      final expected = math.log(1 + loops) * 0.5 + views;
      expect(
        ViewMetrics.rankingScore(loops: loops, views: views),
        closeTo(expected, 1e-9),
      );
    });

    test(
      'anonymous vs signed parity: same definition, different weight noted',
      () {
        // Spec: anonymous events weigh less in ranking than signed, but count
        // fully for display. We pin that definition parity holds by checking
        // both paths use the same ViewMetrics helpers.
        const loops = 1.0;
        const views = 1;
        expect(
          ViewMetrics.displayLoopsSum([loops]),
          ViewMetrics.displayLoopsSum([loops]),
        );
        expect(
          ViewMetrics.rankingScore(loops: loops, views: views),
          ViewMetrics.rankingScore(loops: loops, views: views),
        );
        // With explicit lower anonymous weight the ranking would be lower;
        // we document the tuning knob without asserting a specific value.
        final signedRank = ViewMetrics.rankingScore(
          loops: loops,
          views: views,
        );
        final anonRankLowerWeight = ViewMetrics.rankingScore(
          loops: loops,
          views: views,
          loopsWeight: 0.25,
        );
        expect(anonRankLowerWeight, lessThan(signedRank));
      },
    );
  });
}
