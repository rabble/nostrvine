// ABOUTME: Tests for LoggingConfigService log-level persistence and restore.
// ABOUTME: Verifies the DI-constructed service drives UnifiedLogger + SharedPreferences.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/logging_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  group(LoggingConfigService, () {
    late LogLevel originalLevel;

    setUp(() {
      originalLevel = UnifiedLogger.currentLevel;
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() => UnifiedLogger.setLogLevel(originalLevel));

    test('setLogLevel updates the active log level', () async {
      await LoggingConfigService().setLogLevel(LogLevel.verbose);

      expect(UnifiedLogger.currentLevel, equals(LogLevel.verbose));
      expect(LoggingConfigService().currentLevel, equals(LogLevel.verbose));
      expect(LoggingConfigService().isVerboseEnabled, isTrue);
    });

    test('initialize restores a previously persisted level', () async {
      // Persist a level, then simulate a fresh process default.
      await LoggingConfigService().setLogLevel(LogLevel.verbose);
      UnifiedLogger.setLogLevel(LogLevel.info);

      await LoggingConfigService().initialize();

      expect(UnifiedLogger.currentLevel, equals(LogLevel.verbose));
    });

    test('initialize is a no-op when no level was persisted', () async {
      UnifiedLogger.setLogLevel(LogLevel.info);

      await LoggingConfigService().initialize();

      expect(UnifiedLogger.currentLevel, equals(LogLevel.info));
    });
  });
}
