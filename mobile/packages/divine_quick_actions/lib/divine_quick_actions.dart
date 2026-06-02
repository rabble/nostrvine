// ABOUTME: Public API for Divine home-screen quick actions.
// ABOUTME: Exposes typed shortcut configuration and activation events.

import 'dart:async';

import 'package:divine_quick_actions/divine_quick_actions_platform_interface.dart';
import 'package:divine_quick_actions/src/models/divine_quick_action.dart';
import 'package:divine_quick_actions/src/models/divine_quick_action_event.dart';

export 'src/models/divine_quick_action.dart';
export 'src/models/divine_quick_action_event.dart';

/// Service for configuring and receiving mobile home-screen quick actions.
///
/// Use [DivineQuickActions.instance] from app startup. [initialize] returns
/// a launch action when the app was opened from a shortcut before Dart had a
/// chance to attach a listener.
class DivineQuickActions {
  DivineQuickActions._internal();

  /// The singleton instance of [DivineQuickActions].
  static final DivineQuickActions instance = DivineQuickActions._internal();

  StreamSubscription<DivineQuickActionEvent>? _actionSubscription;

  DivineQuickActionsPlatform get _platform =>
      DivineQuickActionsPlatform.instance;

  /// Emits shortcut activations received while the app is already running.
  Stream<DivineQuickActionEvent> get actionStream => _platform.actionStream;

  /// Returns whether the current platform supports home-screen quick actions.
  Future<bool> get isSupported => _platform.isSupported();

  /// Installs an optional [onAction] callback and consumes the launch action.
  ///
  /// The returned action is non-null when the app was launched from a shortcut
  /// before Dart startup completed. When [onAction] is supplied, the launch
  /// action is also delivered to the callback.
  Future<DivineQuickActionEvent?> initialize({
    void Function(DivineQuickActionEvent action)? onAction,
  }) async {
    await _actionSubscription?.cancel();
    _actionSubscription = null;

    if (onAction != null) {
      _actionSubscription = actionStream.listen(onAction);
    }

    final launchAction = await _platform.consumeLaunchAction();
    if (launchAction != null) {
      onAction?.call(launchAction);
    }

    return launchAction;
  }

  /// Replaces all dynamic quick actions with [actions].
  Future<bool> setActions(List<DivineQuickAction> actions) {
    _validateActions(actions);
    return _platform.setActions(actions);
  }

  /// Returns the dynamic quick actions currently configured by the app.
  Future<List<DivineQuickAction>> getActions() {
    return _platform.getActions();
  }

  /// Clears all dynamic quick actions.
  Future<bool> clearActions() {
    return _platform.clearActions();
  }

  /// Removes the callback installed by [initialize].
  Future<void> dispose() async {
    await _actionSubscription?.cancel();
    _actionSubscription = null;
  }

  void _validateActions(List<DivineQuickAction> actions) {
    final seenTypes = <String>{};
    for (final action in actions) {
      if (!seenTypes.add(action.type)) {
        throw ArgumentError.value(
          action.type,
          'actions',
          'Quick action types must be unique.',
        );
      }
    }
  }
}
