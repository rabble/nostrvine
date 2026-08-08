// ABOUTME: BuildContext shorthands for the MediaQuery metrics read most often,
// ABOUTME: plus Duration.autoReduceMotion for gating animation lengths on them.
// ABOUTME: Each getter forwards to the aspect-scoped MediaQuery.xxxOf form.

import 'package:flutter/widgets.dart';

/// Shorthands for the handful of `MediaQuery` metrics this app reads
/// everywhere.
///
/// Every getter forwards to the matching `MediaQuery.xxxOf(context)`, so the
/// reader only rebuilds when that one metric changes. Reaching for
/// `MediaQuery.of(context).size` instead subscribes the widget to every
/// metric — a keyboard opening then rebuilds a widget that only cared about
/// the screen size.
///
/// Deliberately partial. Only the metrics with real call-site pressure live
/// here; rarer ones (`orientation`, `platformBrightness`, `boldText`, …) stay
/// explicit `MediaQuery.xxxOf` calls so this doesn't drift into a second copy
/// of the `MediaQuery` API.
extension MediaQueryExtensions on BuildContext {
  /// Whether the platform asked for reduced motion.
  ///
  /// Gate animations on this and fall back to `Duration.zero` or a static
  /// frame — see `.claude/rules/accessibility.md`.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// System text scaling to apply to font sizes.
  TextScaler get textScaler => MediaQuery.textScalerOf(this);

  /// Size of the media in logical pixels — the window, not this widget.
  ///
  /// Named `screenSize` rather than `size` because `BuildContext.size`
  /// already means the render box's own size.
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Display areas obscured by system UI, with anything already covered by
  /// [viewInsets] (typically the keyboard) subtracted out.
  EdgeInsets get padding => MediaQuery.paddingOf(this);

  /// Display areas obscured by system UI, ignoring [viewInsets].
  ///
  /// Prefer this over [padding] for layout that must not jump when the
  /// keyboard opens.
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);

  /// Display areas fully obscured by system UI — in practice, the keyboard.
  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);

  /// Physical pixels per logical pixel.
  double get devicePixelRatio => MediaQuery.devicePixelRatioOf(this);
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
