// ABOUTME: Manages app environment (prod/staging/dev) with persistence
// ABOUTME: Handles developer mode unlock and environment switching

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/models/environment_config.dart';

/// Service for managing app environment configuration
class EnvironmentService extends ChangeNotifier {
  static const _keyDeveloperMode = 'developer_mode_enabled';
  static const _keyEnvironment = 'app_environment';
  static const _keyDevRelay = 'dev_relay_selection';

  SharedPreferences? _prefs;
  bool _developerModeEnabled = false;
  EnvironmentConfig _currentConfig = EnvironmentConfig.production;
  bool _initialized = false;

  /// Whether developer mode has been unlocked
  bool get isDeveloperModeEnabled => _developerModeEnabled;

  /// Current environment configuration
  EnvironmentConfig get currentConfig => _currentConfig;

  /// Whether service has been initialized
  bool get isInitialized => _initialized;

  /// Initialize the service and load persisted state
  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    _developerModeEnabled = _prefs!.getBool(_keyDeveloperMode) ?? false;

    final envString = _prefs!.getString(_keyEnvironment);
    final devRelayString = _prefs!.getString(_keyDevRelay);

    final environment = _parseEnvironment(envString);
    final devRelay = _parseDevRelay(devRelayString);

    _currentConfig = EnvironmentConfig(
      environment: environment,
      devRelay: devRelay,
    );

    _initialized = true;
    notifyListeners();
  }

  /// Enable developer mode (called after 7 taps on version)
  Future<void> enableDeveloperMode() async {
    _ensureInitialized();
    _developerModeEnabled = true;
    await _prefs!.setBool(_keyDeveloperMode, true);
    notifyListeners();
  }

  /// Set the app environment
  Future<void> setEnvironment(AppEnvironment environment) async {
    _ensureInitialized();

    _currentConfig = EnvironmentConfig(
      environment: environment,
      devRelay: environment == AppEnvironment.dev
          ? (_currentConfig.devRelay ?? DevRelay.umbra)
          : null,
    );

    await _prefs!.setString(_keyEnvironment, environment.name);

    // Clear persisted relay list so new environment starts fresh with its default
    await _prefs!.remove('configured_relays');

    notifyListeners();
  }

  /// Set the dev relay selection (only applies when in dev environment)
  Future<void> setDevRelay(DevRelay relay) async {
    _ensureInitialized();

    _currentConfig = EnvironmentConfig(
      environment: _currentConfig.environment,
      devRelay: relay,
    );

    await _prefs!.setString(_keyDevRelay, relay.name);
    notifyListeners();
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('EnvironmentService must be initialized first');
    }
  }

  AppEnvironment _parseEnvironment(String? value) {
    if (value == null) return AppEnvironment.production;
    return AppEnvironment.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppEnvironment.production,
    );
  }

  DevRelay? _parseDevRelay(String? value) {
    if (value == null) return null;
    return DevRelay.values.cast<DevRelay?>().firstWhere(
      (e) => e?.name == value,
      orElse: () => null,
    );
  }
}
