// ABOUTME: Activation event emitted when a quick action launches the app.
// ABOUTME: Carries the selected action type and payload back to Dart.

import 'package:equatable/equatable.dart';

/// A selected home-screen quick action.
class DivineQuickActionEvent extends Equatable {
  /// Creates an activation event.
  const DivineQuickActionEvent({
    required this.type,
    this.payload = const <String, String>{},
    this.isLaunchAction = false,
  }) : assert(type != '', 'type must not be empty');

  /// Deserializes an activation event from a native platform map.
  factory DivineQuickActionEvent.fromMap(
    Map<dynamic, dynamic> map, {
    bool isLaunchAction = false,
  }) {
    final type = map['type'];
    if (type is! String || type.isEmpty) {
      throw const FormatException('Quick action event type must be a string.');
    }

    final payload = <String, String>{};
    final rawPayload = map['payload'];
    if (rawPayload is Map<dynamic, dynamic>) {
      for (final entry in rawPayload.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is String) {
          payload[key] = value;
        }
      }
    }

    return DivineQuickActionEvent(
      type: type,
      payload: payload,
      isLaunchAction: isLaunchAction,
    );
  }

  /// Attempts to deserialize an activation event from native platform data.
  static DivineQuickActionEvent? tryFromMap(
    Map<dynamic, dynamic> map, {
    bool isLaunchAction = false,
  }) {
    try {
      return DivineQuickActionEvent.fromMap(
        map,
        isLaunchAction: isLaunchAction,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Stable shortcut identifier selected by the user.
  final String type;

  /// Payload originally configured on the shortcut.
  final Map<String, String> payload;

  /// Whether this event came from the app launch intent.
  final bool isLaunchAction;

  /// Serializes this event for tests and platform fakes.
  Map<String, Object?> toMap() {
    return <String, Object?>{'type': type, 'payload': payload};
  }

  @override
  List<Object?> get props => <Object?>[type, payload, isLaunchAction];
}
