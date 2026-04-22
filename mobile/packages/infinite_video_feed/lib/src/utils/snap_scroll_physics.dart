import 'package:flutter/widgets.dart';

/// Page-snapping physics tuned for short-video feeds.
///
/// No edge bounce, fast spring, and a low page-turn threshold (~10%).
class SnapScrollPhysics extends PageScrollPhysics {
  /// Creates page-snapping physics with no edge bounce.
  const SnapScrollPhysics() : super(parent: const ClampingScrollPhysics());

  /// Fraction of a page the user must drag before the feed commits
  /// to the next/previous page (without velocity).
  static const double _pageTurnThreshold = 0.1;

  @override
  SnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return const SnapScrollPhysics();
  }

  @override
  double get minFlingVelocity => 50;

  @override
  double get minFlingDistance => 1;

  @override
  double get dragStartDistanceMotionThreshold => 1;

  /// Critically damped spring — no bounce, snappy settle.
  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.15,
    stiffness: 300,
    damping: 13.4,
  );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // At the edges, defer to ClampingScrollPhysics (no bounce).
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final page = (position as PageMetrics).page!;
    final currentFloor = page.floor();
    final fraction = page - currentFloor;

    int targetPage;

    if (velocity.abs() > tolerance.velocity) {
      // Any detectable fling velocity commits in that direction.
      targetPage = velocity < 0 ? (page - 0.01).floor() : (page + 0.01).ceil();
    } else if (fraction >= _pageTurnThreshold && fraction <= 0.5) {
      // Slow drag forward past threshold → commit forward.
      targetPage = currentFloor + 1;
    } else if (fraction > 0.5 && fraction < (1.0 - _pageTurnThreshold)) {
      // Slow drag backward past threshold → commit backward.
      targetPage = currentFloor;
    } else if (fraction > 0.5) {
      // Near the next page but below backward threshold → snap forward.
      targetPage = currentFloor + 1;
    } else {
      // Below forward threshold → snap back.
      targetPage = currentFloor;
    }

    final maxPage = (position.maxScrollExtent / position.viewportDimension)
        .round();
    targetPage = targetPage.clamp(0, maxPage);

    final targetPixels = targetPage * position.viewportDimension;

    if ((targetPixels - position.pixels).abs() < tolerance.distance) {
      return null;
    }

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPixels,
      velocity,
      tolerance: tolerance,
    );
  }
}
