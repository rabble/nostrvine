// ABOUTME: Core feature flag service managing flag state and persistence
import 'package:flutter/foundation.dart'; // ABOUTME: Handles initialization, flag management, and state notifications with SharedPreferences
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/models/feature_flag_state.dart';
import 'package:openvine/features/feature_flags/models/flag_metadata.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service managing feature flag state with change notifications for Riverpod reactivity
class FeatureFlagService extends ChangeNotifier {
  FeatureFlagService(
    this._prefs,
    this._buildConfig, {
    bool Function()? canOverrideInternalFlags,
  }) : _canOverrideInternalFlags = canOverrideInternalFlags ?? _denyInternal {
    _initializeWithDefaults();
  }

  final SharedPreferences _prefs;
  final BuildConfiguration _buildConfig;
  final bool Function() _canOverrideInternalFlags;
  late FeatureFlagState _currentState;

  static bool _denyInternal() => false;

  /// Initialize with build defaults (called in constructor)
  void _initializeWithDefaults() {
    final flags = <FeatureFlag, bool>{};
    for (final flag in FeatureFlag.values) {
      flags[flag] = _buildConfig.getDefault(flag);
    }
    _currentState = FeatureFlagState(flags);
  }

  /// Initialize the service by loading persisted flag values
  Future<void> initialize() async {
    final flags = <FeatureFlag, bool>{};

    for (final flag in FeatureFlag.values) {
      final key = _getPreferenceKey(flag);
      final savedValue = _prefs.getBool(key);

      if (_canUsePersistedOverride(flag, savedValue)) {
        flags[flag] = savedValue!;
      } else {
        if (savedValue != null) {
          await _removeInternalOverride(key, flag);
        }
        flags[flag] = _buildConfig.getDefault(flag);
      }
    }

    _currentState = FeatureFlagState(flags);
    notifyListeners();
  }

  /// Check if a feature flag is enabled
  bool isEnabled(FeatureFlag flag) {
    return _currentState.isEnabled(flag);
  }

  /// Set a feature flag value and persist it
  Future<void> setFlag(FeatureFlag flag, bool value) async {
    final key = _getPreferenceKey(flag);

    if (!_canOverrideFlag(flag)) {
      await _removeInternalOverride(key, flag);
      _currentState = _currentState.copyWith(
        flag,
        _buildConfig.getDefault(flag),
      );
      notifyListeners();
      return;
    }

    try {
      await _prefs.setBool(key, value);

      _currentState = _currentState.copyWith(flag, value);
      notifyListeners();
    } catch (e) {
      // Handle storage errors gracefully - log and continue
      Log.warning(
        'Failed to persist feature flag $flag: $e',
        name: 'FeatureFlagService',
        category: LogCategory.system,
      );
      // Still update in-memory state even if persistence fails
      _currentState = _currentState.copyWith(flag, value);
      notifyListeners();
    }
  }

  /// Reset a flag to its build default value
  Future<void> resetFlag(FeatureFlag flag) async {
    final key = _getPreferenceKey(flag);

    try {
      await _prefs.remove(key);

      final defaultValue = _buildConfig.getDefault(flag);
      _currentState = _currentState.copyWith(flag, defaultValue);
      notifyListeners();
    } catch (e) {
      // Handle storage errors gracefully - log and continue
      Log.warning(
        'Failed to reset feature flag $flag: $e',
        name: 'FeatureFlagService',
        category: LogCategory.system,
      );
      // Still update in-memory state even if persistence fails
      final defaultValue = _buildConfig.getDefault(flag);
      _currentState = _currentState.copyWith(flag, defaultValue);
      notifyListeners();
    }
  }

  /// Reset all flags to their build default values
  Future<void> resetAllFlags() async {
    final flags = <FeatureFlag, bool>{};

    for (final flag in FeatureFlag.values) {
      final key = _getPreferenceKey(flag);
      try {
        await _prefs.remove(key);
      } catch (e) {
        // Handle storage errors gracefully - log and continue
        Log.warning(
          'Failed to reset feature flag $flag: $e',
          name: 'FeatureFlagService',
          category: LogCategory.system,
        );
      }
      flags[flag] = _buildConfig.getDefault(flag);
    }

    _currentState = FeatureFlagState(flags);
    notifyListeners();
  }

  /// Check if a flag has a user override (is different from build default)
  bool hasUserOverride(FeatureFlag flag) {
    if (!_canOverrideFlag(flag)) return false;

    final key = _getPreferenceKey(flag);
    return _prefs.containsKey(key);
  }

  /// Get comprehensive metadata for a flag
  FlagMetadata getFlagMetadata(FeatureFlag flag) {
    return FlagMetadata(
      flag: flag,
      isEnabled: isEnabled(flag),
      hasUserOverride: hasUserOverride(flag),
      buildDefault: _buildConfig.getDefault(flag),
    );
  }

  /// Get the current state of all flags
  FeatureFlagState get currentState => _currentState;

  /// Generate preference key for a flag
  String _getPreferenceKey(FeatureFlag flag) {
    return 'ff_${flag.name}';
  }

  bool _canUsePersistedOverride(FeatureFlag flag, bool? savedValue) {
    if (savedValue == null) return false;
    return _canOverrideFlag(flag);
  }

  bool _canOverrideFlag(FeatureFlag flag) {
    return !flag.isInternal || _canOverrideInternalFlags();
  }

  Future<void> _removeInternalOverride(String key, FeatureFlag flag) async {
    if (!flag.isInternal) return;

    try {
      await _prefs.remove(key);
    } catch (e) {
      Log.warning(
        'Failed to remove internal feature flag override $flag: $e',
        name: 'FeatureFlagService',
        category: LogCategory.system,
      );
    }
  }
}
