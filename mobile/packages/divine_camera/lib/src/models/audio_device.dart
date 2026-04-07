import 'package:flutter/foundation.dart';

/// Represents an audio input device (microphone).
@immutable
class AudioDevice {
  /// Creates an [AudioDevice].
  const AudioDevice({
    required this.id,
    required this.name,
  });

  /// Creates an [AudioDevice] from a platform map.
  factory AudioDevice.fromMap(Map<dynamic, dynamic> map) {
    return AudioDevice(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }

  /// The unique identifier for this device.
  final String id;

  /// The human-readable name of this device.
  final String name;

  @override
  String toString() => 'AudioDevice(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
