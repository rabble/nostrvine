// ABOUTME: Tests for environment configuration model
// ABOUTME: Verifies relay URL generation for each environment

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/environment_config.dart';

void main() {
  group('AppEnvironment', () {
    test('has four values', () {
      expect(AppEnvironment.values.length, 4);
      expect(AppEnvironment.values, contains(AppEnvironment.production));
      expect(AppEnvironment.values, contains(AppEnvironment.productionNew));
      expect(AppEnvironment.values, contains(AppEnvironment.staging));
      expect(AppEnvironment.values, contains(AppEnvironment.dev));
    });
  });

  group('DevRelay', () {
    test('has three values (umbra, shugur, funnelcakeProd)', () {
      expect(DevRelay.values.length, 3);
      expect(DevRelay.values, contains(DevRelay.umbra));
      expect(DevRelay.values, contains(DevRelay.shugur));
      expect(DevRelay.values, contains(DevRelay.funnelcakeProd));
    });
  });

  group('EnvironmentConfig', () {
    test('production returns divine.video relay', () {
      final config = EnvironmentConfig(environment: AppEnvironment.production);
      expect(config.relayUrl, 'wss://relay.divine.video');
    });

    test('productionNew returns funnelcake production relay', () {
      final config = EnvironmentConfig(
        environment: AppEnvironment.productionNew,
      );
      expect(config.relayUrl, 'wss://relay.dvines.org');
    });

    test('staging returns staging relay', () {
      final config = EnvironmentConfig(environment: AppEnvironment.staging);
      expect(config.relayUrl, 'wss://relay.staging.dvines.org');
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

    test('dev with funnelcakeProd returns dvines relay', () {
      final config = EnvironmentConfig(
        environment: AppEnvironment.dev,
        devRelay: DevRelay.funnelcakeProd,
      );
      expect(config.relayUrl, 'wss://relay.dvines.org');
    });

    test('blossomUrl is same for all environments', () {
      final prod = EnvironmentConfig(environment: AppEnvironment.production);
      final prodNew = EnvironmentConfig(
        environment: AppEnvironment.productionNew,
      );
      final staging = EnvironmentConfig(environment: AppEnvironment.staging);
      final dev = EnvironmentConfig(environment: AppEnvironment.dev);

      expect(prod.blossomUrl, 'https://media.divine.video');
      expect(prodNew.blossomUrl, 'https://media.divine.video');
      expect(staging.blossomUrl, 'https://media.divine.video');
      expect(dev.blossomUrl, 'https://media.divine.video');
    });

    test('isProduction returns true for production environments', () {
      expect(
        EnvironmentConfig(environment: AppEnvironment.production).isProduction,
        true,
      );
      expect(
        EnvironmentConfig(
          environment: AppEnvironment.productionNew,
        ).isProduction,
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
        EnvironmentConfig(
          environment: AppEnvironment.productionNew,
        ).displayName,
        'Production (Funnelcake)',
      );
      expect(
        EnvironmentConfig(environment: AppEnvironment.staging).displayName,
        'Staging (Funnelcake)',
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
      expect(
        EnvironmentConfig(
          environment: AppEnvironment.dev,
          devRelay: DevRelay.funnelcakeProd,
        ).displayName,
        'Dev - Funnelcake Prod',
      );
    });
  });
}
