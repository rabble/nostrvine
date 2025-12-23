// ABOUTME: Tests for environment configuration model
// ABOUTME: Verifies relay URL generation for each environment

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/environment_config.dart';

void main() {
  group('AppEnvironment', () {
    test('has three values', () {
      expect(AppEnvironment.values.length, 3);
      expect(AppEnvironment.values, contains(AppEnvironment.production));
      expect(AppEnvironment.values, contains(AppEnvironment.staging));
      expect(AppEnvironment.values, contains(AppEnvironment.dev));
    });
  });

  group('DevRelay', () {
    test('has two values (umbra and shugur)', () {
      expect(DevRelay.values.length, 2);
      expect(DevRelay.values, contains(DevRelay.umbra));
      expect(DevRelay.values, contains(DevRelay.shugur));
    });
  });

  group('EnvironmentConfig', () {
    test('production returns divine.video relay', () {
      final config = EnvironmentConfig(environment: AppEnvironment.production);
      expect(config.relayUrl, 'wss://relay.divine.video');
    });

    test('staging returns staging-relay', () {
      final config = EnvironmentConfig(environment: AppEnvironment.staging);
      expect(config.relayUrl, 'wss://staging-relay.divine.video');
    });

    test('dev with umbra returns poc relay', () {
      final config = EnvironmentConfig(
        environment: AppEnvironment.dev,
        devRelay: DevRelay.umbra,
      );
      expect(config.relayUrl, 'wss://relay.poc.dvines.org');
    });

    test('dev with shugur returns shugur relay', () {
      final config = EnvironmentConfig(
        environment: AppEnvironment.dev,
        devRelay: DevRelay.shugur,
      );
      expect(config.relayUrl, 'wss://shugur.poc.dvines.org');
    });

    test('dev without devRelay defaults to umbra', () {
      final config = EnvironmentConfig(environment: AppEnvironment.dev);
      expect(config.relayUrl, 'wss://relay.poc.dvines.org');
    });

    test('blossomUrl is same for all environments', () {
      final prod = EnvironmentConfig(environment: AppEnvironment.production);
      final staging = EnvironmentConfig(environment: AppEnvironment.staging);
      final dev = EnvironmentConfig(environment: AppEnvironment.dev);

      expect(prod.blossomUrl, 'https://media.divine.video');
      expect(staging.blossomUrl, 'https://media.divine.video');
      expect(dev.blossomUrl, 'https://media.divine.video');
    });

    test('isProduction returns true only for production', () {
      expect(
        EnvironmentConfig(environment: AppEnvironment.production).isProduction,
        true,
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.staging).isProduction,
        false,
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.dev).isProduction,
        false,
      );
    });

    test('displayName returns human readable name', () {
      expect(
        EnvironmentConfig(environment: AppEnvironment.production).displayName,
        'Production',
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.staging).displayName,
        'Staging',
      );
      expect(
        EnvironmentConfig(
          environment: AppEnvironment.dev,
          devRelay: DevRelay.umbra,
        ).displayName,
        'Dev - Umbra',
      );
      expect(
        EnvironmentConfig(
          environment: AppEnvironment.dev,
          devRelay: DevRelay.shugur,
        ).displayName,
        'Dev - Shugur',
      );
    });
  });
}
