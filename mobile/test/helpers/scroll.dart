// ABOUTME: Scroll helper that settles the frame before a tap reads coordinates.
// ABOUTME: Guards the #7179 class where a tap uses the pre-scroll layout and misses.

import 'package:flutter_test/flutter_test.dart';

/// Scrolls [target] into view and settles the frame before returning.
///
/// Use this instead of a bare `tester.scrollUntilVisible` wherever a tap or
/// another viewport-sensitive interaction follows.
///
/// `scrollUntilVisible` ends by calling `Scrollable.ensureVisible` on [target]
/// itself, so the target is positioned correctly — but it does not pump a
/// frame afterwards. Tapping straight away reads the target's centre from the
/// not-yet-settled layout, which can sit at or past the viewport edge on a
/// screen whose content happens to be tall. The tap then lands on nothing:
/// `warnIfMissed` only prints a warning, so the failure surfaces later as an
/// unrelated assertion (#7179).
///
/// Whether a row lands near that edge is not stable across a run. `VineTheme`'s
/// font helpers are `GoogleFonts.inter(...)`, and google_fonts registers its
/// asset into the process-global font collection asynchronously, so the first
/// widget test in an isolate to render a screen lays it out with the wider
/// fallback test font and every later one with real Inter metrics. Randomized
/// ordering decides which test pays that cost.
///
/// Every parameter besides [tester] passes straight through to
/// `scrollUntilVisible` with its own defaults, so this is a drop-in
/// replacement.
Future<void> scrollUntilTappable(
  WidgetTester tester,
  Finder target,
  double delta, {
  Finder? scrollable,
  int maxScrolls = 50,
  Duration duration = const Duration(milliseconds: 50),
  bool continuous = false,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: scrollable,
    maxScrolls: maxScrolls,
    duration: duration,
    continuous: continuous,
  );
  await tester.pumpAndSettle();
}
