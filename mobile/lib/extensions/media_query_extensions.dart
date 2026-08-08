// ABOUTME: BuildContext shorthands for the MediaQuery metrics this PR uses,
// ABOUTME: plus Duration.autoReduceMotion for gating animation lengths on them.
// ABOUTME: Each getter forwards to the aspect-scoped MediaQuery.xxxOf form.

import 'package:flutter/widgets.dart';

/// Shorthands for `MediaQuery` metrics this app reads often.
///
/// Every getter forwards to the matching `MediaQuery.xxxOf(context)`, so the
/// reader only rebuilds when that one metric changes. Reaching for
/// `MediaQuery.of(context).size` instead subscribes the widget to every
/// metric — a keyboard opening then rebuilds a widget that only cared about
/// the screen size.
///
/// Deliberately partial. Add new shorthands only alongside production call
/// sites, so this does not drift into a second copy of the `MediaQuery` API.
extension MediaQueryExtensions on BuildContext {
  /// Whether the platform asked for reduced motion.
  ///
  /// Gate animations on this and fall back to `Duration.zero` or a static
  /// frame — see `.claude/rules/accessibility.md`.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// System text scaling to apply to font sizes.
  TextScaler get textScaler => MediaQuery.textScalerOf(this);
}

/// Lets an animation length opt into the platform's reduced-motion setting.
extension ReduceMotionDuration on Duration {
  /// This duration, or [Duration.zero] when [BuildContext.reduceMotion] is on.
  ///
  /// ```dart
  /// AnimatedContainer(
  ///   duration: const Duration(milliseconds: 200).autoReduceMotion(context),
  /// )
  /// ```
  ///
  /// A zero duration makes implicit animations jump straight to their target,
  /// which is what reduced motion asks for. Use this for tweens between two
  /// legible states; an animation whose *end* state is the only readable one
  /// (a spinner, a marquee) needs a static replacement instead, not a
  /// zero-length run.
  ///
  /// Not every API tolerates a zero duration. `ScrollPosition.animateTo`
  /// asserts `duration > Duration.zero`, so scroll positions have to branch on
  /// [BuildContext.reduceMotion] and call `jumpTo` instead.
  Duration autoReduceMotion(BuildContext context) =>
      context.reduceMotion ? Duration.zero : this;
}
