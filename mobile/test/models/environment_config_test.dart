// ABOUTME: Tests for environment configuration model
// ABOUTME: Verifies relay URL and API URL generation for each environment

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/environment_config.dart';

void main() {
  group('AppEnvironment', () {
    test('has five values', () {
      expect(AppEnvironment.values.length, 5);
      expect(AppEnvironment.values, contains(AppEnvironment.poc));
      expect(AppEnvironment.values, contains(AppEnvironment.staging));
      expect(AppEnvironment.values, contains(AppEnvironment.test));
      expect(AppEnvironment.values, contains(AppEnvironment.production));
      expect(AppEnvironment.values, contains(AppEnvironment.local));
    });
  });

  group('EnvironmentConfig', () {
    group('relayUrl', () {
      test('poc returns poc relay', () {
        const config = EnvironmentConfig(environment: AppEnvironment.poc);
        expect(config.relayUrl, 'wss://relay.poc.dvines.org');
      });

      test('staging returns staging relay', () {
        const config = EnvironmentConfig(environment: AppEnvironment.staging);
        expect(config.relayUrl, 'wss://relay.staging.dvines.org');
      });

      test('test returns test relay', () {
        const config = EnvironmentConfig(environment: AppEnvironment.test);
        expect(config.relayUrl, 'wss://relay.test.dvines.org');
      });

      test('local returns emulator relay', () {
        const config = EnvironmentConfig(environment: AppEnvironment.local);
        expect(config.relayUrl, 'ws://10.0.2.2:47777');
      });

      test('production returns divine.video relay', () {
        const config = EnvironmentConfig(
          environment: AppEnvironment.production,
        );
        expect(config.relayUrl, 'wss://relay.divine.video');
      });
    });

    group('apiBaseUrl', () {
      test('poc derives from relay URL', () {
        const config = EnvironmentConfig(environment: AppEnvironment.poc);
        expect(config.apiBaseUrl, 'https://relay.poc.dvines.org');
      });

      test('staging derives from relay URL', () {
        const config = EnvironmentConfig(environment: AppEnvironment.staging);
        expect(config.apiBaseUrl, 'https://relay.staging.dvines.org');
      });

      test('test derives from relay URL', () {
        const config = EnvironmentConfig(environment: AppEnvironment.test);
        expect(config.apiBaseUrl, 'https://relay.test.dvines.org');
      });

      test('local returns local API URL', () {
        const config = EnvironmentConfig(environment: AppEnvironment.local);
        expect(config.apiBaseUrl, 'http://10.0.2.2:43001');
      });

      test('production uses api.divine.video for Funnelcake REST', () {
        const config = EnvironmentConfig(
          environment: AppEnvironment.production,
        );
        expect(config.apiBaseUrl, 'https://api.divine.video');
      });
    });

    test('blossomUrl is same for all environments', () {
      const poc = EnvironmentConfig(environment: AppEnvironment.poc);
      const staging = EnvironmentConfig(environment: AppEnvironment.staging);
      const testEnv = EnvironmentConfig(environment: AppEnvironment.test);
      const prod = EnvironmentConfig(environment: AppEnvironment.production);

      expect(poc.blossomUrl, 'https://media.divine.video');
      expect(staging.blossomUrl, 'https://media.divine.video');
      expect(testEnv.blossomUrl, 'https://media.divine.video');
      expect(prod.blossomUrl, 'https://media.divine.video');
    });

    test('isProduction returns true only for production environment', () {
      expect(
        const EnvironmentConfig(environment: AppEnvironment.poc).isProduction,
        false,
      );
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.staging,
        ).isProduction,
        false,
      );
      expect(
        const EnvironmentConfig(environment: AppEnvironment.test).isProduction,
        false,
      );
      expect(
        const EnvironmentConfig(environment: AppEnvironment.local).isProduction,
        false,
      );
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.production,
        ).isProduction,
        true,
      );
    });

    test('displayName returns human readable name', () {
      expect(
        const EnvironmentConfig(environment: AppEnvironment.poc).displayName,
        'POC',
      );
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.staging,
        ).displayName,
        'Staging',
      );
      expect(
        const EnvironmentConfig(environment: AppEnvironment.test).displayName,
        'Test',
      );
      expect(
        const EnvironmentConfig(environment: AppEnvironment.local).displayName,
        'Local',
      );
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.production,
        ).displayName,
        'Production',
      );
    });

    test('indicatorColorValue returns correct colors', () {
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.poc,
        ).indicatorColorValue,
        0xFFFF7640, // accentOrange
      );
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.staging,
        ).indicatorColorValue,
        0xFFFFF140, // accentYellow
      );
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.test,
        ).indicatorColorValue,
        0xFF34BBF1, // accentBlue
      );
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.local,
        ).indicatorColorValue,
        0xFFE040FB, // accentPurple
      );
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.production,
        ).indicatorColorValue,
        0xFF27C58B, // primaryGreen
      );
    });

    group('equality', () {
      test('same environment are equal', () {
        const config1 = EnvironmentConfig(environment: AppEnvironment.staging);
        const config2 = EnvironmentConfig(environment: AppEnvironment.staging);
        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('different environments are not equal', () {
        const config1 = EnvironmentConfig(environment: AppEnvironment.staging);
        const config2 = EnvironmentConfig(
          environment: AppEnvironment.production,
        );
        expect(config1, isNot(equals(config2)));
      });
    });
  });
}
