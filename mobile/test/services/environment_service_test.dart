// ABOUTME: Tests for environment service persistence and state management
// ABOUTME: Uses mock SharedPreferences for isolation

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/environment_service.dart';

void main() {
  group('EnvironmentService', () {
    late EnvironmentService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to production when no saved state', () async {
      service = EnvironmentService();
      await service.initialize();

      expect(service.currentConfig.environment, AppEnvironment.production);
      expect(service.isDeveloperModeEnabled, false);
    });

    test('loads saved environment from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'developer_mode_enabled': true,
        'app_environment': 'staging',
      });

      service = EnvironmentService();
      await service.initialize();

      expect(service.isDeveloperModeEnabled, true);
      expect(service.currentConfig.environment, AppEnvironment.staging);
    });

    test('loads poc environment from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'developer_mode_enabled': true,
        'app_environment': 'poc',
      });

      service = EnvironmentService();
      await service.initialize();

      expect(service.currentConfig.environment, AppEnvironment.poc);
    });

    test('loads test environment from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'developer_mode_enabled': true,
        'app_environment': 'test',
      });

      service = EnvironmentService();
      await service.initialize();

      expect(service.currentConfig.environment, AppEnvironment.test);
    });

    test('enableDeveloperMode persists state', () async {
      service = EnvironmentService();
      await service.initialize();

      await service.enableDeveloperMode();

      expect(service.isDeveloperModeEnabled, true);

      // Verify persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('developer_mode_enabled'), true);
    });

    test('setEnvironment persists and notifies', () async {
      service = EnvironmentService();
      await service.initialize();

      var notified = false;
      service.addListener(() => notified = true);

      await service.setEnvironment(AppEnvironment.staging);

      expect(service.currentConfig.environment, AppEnvironment.staging);
      expect(notified, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_environment'), 'staging');
    });

    test('setEnvironment to poc persists correctly', () async {
      service = EnvironmentService();
      await service.initialize();

      await service.setEnvironment(AppEnvironment.poc);

      expect(service.currentConfig.environment, AppEnvironment.poc);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_environment'), 'poc');
    });

    test('setEnvironment to test persists correctly', () async {
      service = EnvironmentService();
      await service.initialize();

      await service.setEnvironment(AppEnvironment.test);

      expect(service.currentConfig.environment, AppEnvironment.test);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_environment'), 'test');
    });

    test('setEnvironment clears configured_relays', () async {
      SharedPreferences.setMockInitialValues({
        'configured_relays': 'some_relay_value',
      });

      service = EnvironmentService();
      await service.initialize();

      await service.setEnvironment(AppEnvironment.staging);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('configured_relays'), isNull);
    });
  });
}
