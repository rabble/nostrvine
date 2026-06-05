// ABOUTME: Typed model for configuring mobile home-screen quick actions.
// ABOUTME: Keeps Android and iOS icon metadata explicit and serializable.

import 'package:equatable/equatable.dart';

/// iOS icon rendering style for a quick action.
enum DivineQuickActionIosIconStyle {
  /// Uses an app-bundled template image name.
  template('template'),

  /// Uses an SF Symbol name on iOS 13 and newer.
  system('system');

  const DivineQuickActionIosIconStyle(this.value);

  /// Native serialization value.
  final String value;

  /// Creates a style from its native value.
  static DivineQuickActionIosIconStyle fromValue(String? value) {
    return DivineQuickActionIosIconStyle.values.firstWhere(
      (style) => style.value == value,
      orElse: () => DivineQuickActionIosIconStyle.template,
    );
  }
}

/// A dynamic home-screen quick action.
class DivineQuickAction extends Equatable {
  /// Creates a quick action.
  const DivineQuickAction({
    required this.type,
    required this.title,
    this.subtitle,
    this.androidIconName,
    this.iosIconName,
    this.iosIconStyle = DivineQuickActionIosIconStyle.template,
    this.rank,
    this.payload = const <String, String>{},
  }) : assert(type != '', 'type must not be empty'),
       assert(title != '', 'title must not be empty'),
       assert(rank == null || rank >= 0, 'rank must be non-negative');

  /// Deserializes a quick action from a native platform map.
  factory DivineQuickAction.fromMap(Map<dynamic, dynamic> map) {
    final type = map['type'];
    final title = map['title'];
    if (type is! String || type.isEmpty) {
      throw const FormatException('Quick action type must be a string.');
    }
    if (title is! String || title.isEmpty) {
      throw const FormatException('Quick action title must be a string.');
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

    return DivineQuickAction(
      type: type,
      title: title,
      subtitle: map['subtitle'] as String?,
      androidIconName: map['androidIconName'] as String?,
      iosIconName: map['iosIconName'] as String?,
      iosIconStyle: DivineQuickActionIosIconStyle.fromValue(
        map['iosIconStyle'] as String?,
      ),
      rank: map['rank'] as int?,
      payload: payload,
    );
  }

  /// Attempts to deserialize a quick action from native platform data.
  static DivineQuickAction? tryFromMap(Map<dynamic, dynamic> map) {
    try {
      return DivineQuickAction.fromMap(map);
    } on Object {
      return null;
    }
  }

  /// Stable shortcut identifier delivered when the action is selected.
  final String type;

  /// Primary label shown by the operating system.
  final String title;

  /// Secondary label shown when the platform has room for more text.
  final String? subtitle;

  /// Android drawable or mipmap resource name, for example `ic_quick_record`.
  final String? androidIconName;

  /// iOS template image name or SF Symbol name, depending on [iosIconStyle].
  final String? iosIconName;

  /// Determines whether [iosIconName] is an app template asset or SF Symbol.
  final DivineQuickActionIosIconStyle iosIconStyle;

  /// Optional ordering hint. Lower values are presented first on Android.
  final int? rank;

  /// String payload delivered with the activation event.
  final Map<String, String> payload;

  /// Serializes this action for the native platform.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'androidIconName': androidIconName,
      'iosIconName': iosIconName,
      'iosIconStyle': iosIconStyle.value,
      'rank': rank,
      'payload': payload,
    };
  }

  @override
  List<Object?> get props => <Object?>[
    type,
    title,
    subtitle,
    androidIconName,
    iosIconName,
    iosIconStyle,
    rank,
    payload,
  ];
}
