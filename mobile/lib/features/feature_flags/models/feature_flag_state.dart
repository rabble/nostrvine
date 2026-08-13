// ABOUTME: Immutable state container for feature flag values
// ABOUTME: Manages flag state with copy-on-write semantics and type safety

import 'package:meta/meta.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';

@immutable
class FeatureFlagState {
  const FeatureFlagState(this._flags);

  final Map<FeatureFlag, bool> _flags;

  /// Check if a feature flag is enabled
  bool isEnabled(FeatureFlag flag) {
    return _flags[flag] ?? false;
  }

  /// Get all flag values as an immutable map
  Map<FeatureFlag, bool> get allFlags => Map.unmodifiable(_flags);

  /// Create a new state with a flag value changed
  FeatureFlagState copyWith(FeatureFlag flag, bool value) {
    final newFlags = Map<FeatureFlag, bool>.from(_flags);
    newFlags[flag] = value;
    return FeatureFlagState(newFlags);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FeatureFlagState) return false;

    // Compare all flags
    if (_flags.length != other._flags.length) return false;

    for (final entry in _flags.entries) {
      if (other._flags[entry.key] != entry.value) return false;
    }

    return true;
  }

  @override
  int get hashCode {
    var hash = 0;
    for (final entry in _flags.entries) {
      hash ^= entry.key.hashCode ^ entry.value.hashCode;
    }
    return hash;
  }
}
