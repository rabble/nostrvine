// ABOUTME: Decision object returned by the shared back-navigation policy
// ABOUTME: Keeps the policy pure - callers execute, the policy only decides

import 'package:meta/meta.dart';

/// What a back gesture should do, decided without touching a navigator.
///
/// Returning a decision rather than navigating is what lets one policy serve
/// the Android system-back channel and the shell app-bar button, and be
/// tested with no `BuildContext`, no `GoRouter` and no widget pump.
sealed class BackAction {
  const BackAction();
}

/// Pop the top route off the navigator.
@immutable
final class BackPop extends BackAction {
  const BackPop();

  @override
  bool operator ==(Object other) => other is BackPop;

  @override
  int get hashCode => (BackPop).hashCode;

  @override
  String toString() => 'BackPop()';
}

/// Navigate to [location].
@immutable
final class BackGoTo extends BackAction {
  const BackGoTo(this.location, {this.consumesTabHistory = false});

  final String location;

  /// Whether the caller must also pop the tab history before navigating.
  ///
  /// True only for the "return to the previously visited tab" decision; the
  /// policy cannot mutate the history itself and stay pure.
  final bool consumesTabHistory;

  @override
  bool operator ==(Object other) =>
      other is BackGoTo &&
      other.location == location &&
      other.consumesTabHistory == consumesTabHistory;

  @override
  int get hashCode => Object.hash(location, consumesTabHistory);

  @override
  String toString() =>
      'BackGoTo($location, consumesTabHistory: $consumesTabHistory)';
}

/// Nothing left for the app to do — let the platform handle the press.
///
/// On Android this is what closes the app, so returning it while a tab the
/// user can still back out of is on screen is a bug (#3337).
@immutable
final class BackUnhandled extends BackAction {
  const BackUnhandled();

  @override
  bool operator ==(Object other) => other is BackUnhandled;

  @override
  int get hashCode => (BackUnhandled).hashCode;

  @override
  String toString() => 'BackUnhandled()';
}
