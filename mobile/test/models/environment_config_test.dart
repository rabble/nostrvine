// ABOUTME: Tests for environment configuration model
// ABOUTME: Verifies relay URL and API URL generation for each environment

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/environment_config.dart';

void main() {
  group('AppEnvironment', () {
    test('has four values', () {
      expect(AppEnvironment.values.length, 4);
      expect(AppEnvironment.values, contains(AppEnvironment.poc));
      expect(AppEnvironment.values, contains(AppEnvironment.staging));
      expect(AppEnvironment.values, contains(AppEnvironment.test));
      expect(AppEnvironment.values, contains(AppEnvironment.production));
    });
  });

  group('EnvironmentConfig', () {
    group('relayUrl', () {
      test('poc returns poc relay', () {
        final config = EnvironmentConfig(environment: AppEnvironment.poc);
        expect(config.relayUrl, 'wss://relay.poc.dvines.org');
      });

      test('staging returns staging relay', () {
        final config = EnvironmentConfig(environment: AppEnvironment.staging);
        expect(config.relayUrl, 'wss://relay.staging.dvines.org');
      });

      test('test returns test relay', () {
        final config = EnvironmentConfig(environment: AppEnvironment.test);
        expect(config.relayUrl, 'wss://relay.test.dvines.org');
      });

      test('production returns divine.video relay', () {
        final config = EnvironmentConfig(
          environment: AppEnvironment.production,
        );
        expect(config.relayUrl, 'wss://relay.divine.video');
      });
    });

    group('apiBaseUrl', () {
      test('poc returns poc API', () {
        final config = EnvironmentConfig(environment: AppEnvironment.poc);
        expect(config.apiBaseUrl, 'https://api.poc.dvines.org');
      });

      test('staging returns staging API', () {
        final config = EnvironmentConfig(environment: AppEnvironment.staging);
        expect(config.apiBaseUrl, 'https://api.staging.dvines.org');
      });

      test('test returns test API', () {
        final config = EnvironmentConfig(environment: AppEnvironment.test);
        expect(config.apiBaseUrl, 'https://api.test.dvines.org');
      });

      test('production returns divine.video API', () {
        final config = EnvironmentConfig(
          environment: AppEnvironment.production,
        );
        expect(config.apiBaseUrl, 'https://api.divine.video');
      });
    });

    test('blossomUrl is same for all environments', () {
      final poc = EnvironmentConfig(environment: AppEnvironment.poc);
      final staging = EnvironmentConfig(environment: AppEnvironment.staging);
      final testEnv = EnvironmentConfig(environment: AppEnvironment.test);
      final prod = EnvironmentConfig(environment: AppEnvironment.production);

      expect(poc.blossomUrl, 'https://media.divine.video');
      expect(staging.blossomUrl, 'https://media.divine.video');
      expect(testEnv.blossomUrl, 'https://media.divine.video');
      expect(prod.blossomUrl, 'https://media.divine.video');
    });

    test('isProduction returns true only for production environment', () {
      expect(
        EnvironmentConfig(environment: AppEnvironment.poc).isProduction,
        false,
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.staging).isProduction,
        false,
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.test).isProduction,
        false,
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.production).isProduction,
        true,
      );
    });

    test('displayName returns human readable name', () {
      expect(
        EnvironmentConfig(environment: AppEnvironment.poc).displayName,
        'POC',
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.staging).displayName,
        'Staging',
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.test).displayName,
        'Test',
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.production).displayName,
        'Production',
      );
    });

    test('indicatorColorValue returns correct colors', () {
      expect(
        EnvironmentConfig(environment: AppEnvironment.poc).indicatorColorValue,
        0xFFFF7640, // accentOrange
      );
      expect(
        EnvironmentConfig(
          environment: AppEnvironment.staging,
        ).indicatorColorValue,
        0xFFFFF140, // accentYellow
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.test).indicatorColorValue,
        0xFF34BBF1, // accentBlue
      );
      expect(
        EnvironmentConfig(
          environment: AppEnvironment.production,
        ).indicatorColorValue,
        0xFF27C58B, // primaryGreen
      );
    });

    group('equality', () {
      test('same environment are equal', () {
        final config1 = EnvironmentConfig(environment: AppEnvironment.staging);
        final config2 = EnvironmentConfig(environment: AppEnvironment.staging);
        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('different environments are not equal', () {
        final config1 = EnvironmentConfig(environment: AppEnvironment.staging);
        final config2 = EnvironmentConfig(
          environment: AppEnvironment.production,
        );
        expect(config1, isNot(equals(config2)));
      });
    });
  });
}
