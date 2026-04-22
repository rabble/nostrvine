import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/utils/snap_scroll_physics.dart';

/// Minimal [PageMetrics] for physics tests.
PageMetrics _page({
  required double pixels,
  required double maxScrollExtent,
  double viewportDimension = 800,
}) => PageMetrics(
  minScrollExtent: 0,
  maxScrollExtent: maxScrollExtent,
  pixels: pixels,
  viewportDimension: viewportDimension,
  axisDirection: AxisDirection.down,
  viewportFraction: 1,
  devicePixelRatio: 1,
);

void main() {
  const physics = SnapScrollPhysics();

  group(SnapScrollPhysics, () {
    group('applyTo', () {
      test('returns a SnapScrollPhysics instance', () {
        expect(physics.applyTo(null), isA<SnapScrollPhysics>());
      });
    });

    group('constants', () {
      test('minFlingVelocity is 50', () {
        expect(physics.minFlingVelocity, equals(50));
      });

      test('minFlingDistance is 1', () {
        expect(physics.minFlingDistance, equals(1));
      });

      test('dragStartDistanceMotionThreshold is 1', () {
        expect(physics.dragStartDistanceMotionThreshold, equals(1));
      });
    });

    group('spring', () {
      test('uses critically-damped spring parameters', () {
        final s = physics.spring;
        expect(s.mass, equals(0.15));
        expect(s.stiffness, equals(300));
        expect(s.damping, equals(13.4));
      });
    });

    group('createBallisticSimulation', () {
      test('returns null at min edge with negative velocity', () {
        final pos = _page(pixels: 0, maxScrollExtent: 800);
        final sim = physics.createBallisticSimulation(pos, -100);
        expect(sim, isNull);
      });

      test('returns null at max edge with positive velocity', () {
        final pos = _page(pixels: 800, maxScrollExtent: 800);
        final sim = physics.createBallisticSimulation(pos, 100);
        expect(sim, isNull);
      });

      test('snaps forward on fling velocity > 0', () {
        // Position is page 0.1 (80 px into page 0, total 800 px per page).
        final pos = _page(pixels: 80, maxScrollExtent: 800);
        final sim = physics.createBallisticSimulation(pos, 500);
        expect(sim, isNotNull);
        // After settling, position should be at page 1 (800 px).
        final settled = _settleSimulation(sim!);
        expect(settled, closeTo(800, 10));
      });

      test('snaps backward on fling velocity < 0', () {
        // Position is page 0.9 (720 px into page 0).
        final pos = _page(pixels: 720, maxScrollExtent: 800);
        final sim = physics.createBallisticSimulation(pos, -500);
        expect(sim, isNotNull);
        final settled = _settleSimulation(sim!);
        expect(settled, closeTo(0, 10));
      });

      test('commits forward when fraction >= threshold (slow drag)', () {
        // 10% threshold → 80 px drag on 800 px page should commit forward.
        final pos = _page(pixels: 80, maxScrollExtent: 800);
        final sim = physics.createBallisticSimulation(pos, 0);
        expect(sim, isNotNull);
        final settled = _settleSimulation(sim!);
        expect(settled, closeTo(800, 10));
      });

      test('snaps back when fraction < threshold (tiny drag)', () {
        // 1% drag → well below threshold.
        final pos = _page(pixels: 8, maxScrollExtent: 800);
        final sim = physics.createBallisticSimulation(pos, 0);
        expect(sim, isNotNull);
        final settled = _settleSimulation(sim!);
        expect(settled, closeTo(0, 10));
      });

      test('snaps forward when fraction > back-threshold (near next page)', () {
        // 95% through page 0 is > (1 - 0.1) = 0.9 → snap forward to page 1.
        final pos = _page(pixels: 760, maxScrollExtent: 800);
        final sim = physics.createBallisticSimulation(pos, 0);
        expect(sim, isNotNull);
        final settled = _settleSimulation(sim!);
        expect(settled, closeTo(800, 10));
      });

      test('snaps backward when fraction just below back-threshold', () {
        // 80% through page 0 is > 0.5 but < (1 - 0.1) = 0.9 → snap back.
        final pos = _page(pixels: 640, maxScrollExtent: 800);
        final sim = physics.createBallisticSimulation(pos, 0);
        expect(sim, isNotNull);
        final settled = _settleSimulation(sim!);
        expect(settled, closeTo(0, 10));
      });

      test('returns null when already at target pixel', () {
        // Position exactly at page 1 with no velocity → already settled.
        final pos = _page(pixels: 800, maxScrollExtent: 1600);
        final sim = physics.createBallisticSimulation(pos, 0);
        expect(sim, isNull);
      });

      test('clamps targetPage to maxPage', () {
        // On the last page, fling forward → clamps to maxPage.
        final pos = _page(pixels: 880, maxScrollExtent: 800);
        final sim = physics.createBallisticSimulation(pos, 500);
        // At the edge boundary, super.createBallisticSimulation is called.
        // Either null or a sim that settles at max.
        if (sim != null) {
          final settled = _settleSimulation(sim);
          expect(settled, lessThanOrEqualTo(800 + 1));
        }
      });
    });
  });
}

/// Advances [sim] until it reports done and returns the last `x` value.
double _settleSimulation(Simulation sim) {
  var t = 0.0;
  var last = sim.x(t);
  while (!sim.isDone(t) && t < 10) {
    t += 0.016;
    last = sim.x(t);
  }
  return last;
}
