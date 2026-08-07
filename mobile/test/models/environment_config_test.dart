// ABOUTME: Tests for environment configuration model
// ABOUTME: Verifies relay URL and API URL generation for each environment

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/environment_config.dart';

void main() {
  group('localHost', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('is the emulator alias on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(localHost, androidEmulatorHost);
    });

    test('is loopback on iOS', () {
      // 10.0.2.2 is an Android-emulator-only alias. The iOS Simulator shares
      // the host's network stack, where it routes out to the LAN instead.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(localHost, loopbackHost);
    });

    test('is loopback on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(localHost, loopbackHost);
    });

    test('drives every local endpoint off the resolved host', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const config = EnvironmentConfig(environment: AppEnvironment.local);
      expect(config.relayUrl, 'ws://$loopbackHost:$localRelayPort');
      expect(config.apiBaseUrl, 'http://$loopbackHost:$localApiPort');
      expect(config.blossomUrl, 'http://$loopbackHost:$localBlossomPort');
      expect(
        config.relayManagerApiUrl,
        'http://$loopbackHost:$localRelayManagerPort',
      );
      expect(config.indexerRelays, ['ws://$loopbackHost:$localRelayPort']);
    });
  });

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
    // The LOCAL assertions below spell out 10.0.2.2. Without an explicit
    // override they would inherit TargetPlatform.android from the test
    // harness — flutter_test forces it inside an assert block whenever
    // FLUTTER_TEST is set — rather than stating the platform they mean.
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    group('relayUrl', () {
      test('poc returns poc relay', () {
        const config = EnvironmentConfig(environment: AppEnvironment.poc);
        expect(config.relayUrl, 'wss://relay.poc.dvines.org');
      });

      test('staging returns staging relay', () {
        const config = EnvironmentConfig(environment: AppEnvironment.staging);
        expect(config.relayUrl, 'wss://relay.staging.divine.video');
      });

      test('test returns test relay', () {
        const config = EnvironmentConfig(environment: AppEnvironment.test);
        expect(config.relayUrl, 'wss://relay.test.dvines.org');
      });

      test('local returns emulator relay', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
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
        expect(config.apiBaseUrl, 'https://relay.staging.divine.video');
      });

      test('test derives from relay URL', () {
        const config = EnvironmentConfig(environment: AppEnvironment.test);
        expect(config.apiBaseUrl, 'https://relay.test.dvines.org');
      });

      test('local returns local API URL (unified funnelcake-proxy port)', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        const config = EnvironmentConfig(environment: AppEnvironment.local);
        expect(config.apiBaseUrl, 'http://10.0.2.2:47777');
      });

      test('production uses api.divine.video for Funnelcake REST', () {
        const config = EnvironmentConfig(
          environment: AppEnvironment.production,
        );
        expect(config.apiBaseUrl, 'https://api.divine.video');
      });
    });

    group('eventPublishBaseUrl', () {
      test('production uses relay.divine.video for NIP-98 event publish', () {
        const config = EnvironmentConfig(
          environment: AppEnvironment.production,
        );
        expect(config.eventPublishBaseUrl, 'https://relay.divine.video');
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

    test('pushServicePubkey returns the expected key for each environment', () {
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.poc,
        ).pushServicePubkey,
        '2fc7d43fc02ae951a226108d3a31330bd26f37c1ef88eaa91948251de98b049d',
      );
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.staging,
        ).pushServicePubkey,
        '5414dcebf15d0d8b36fb80c6295ae4222113b61807e777870cbd1fd422a35809',
      );
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.test,
        ).pushServicePubkey,
        '5414dcebf15d0d8b36fb80c6295ae4222113b61807e777870cbd1fd422a35809',
      );
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.local,
        ).pushServicePubkey,
        '5414dcebf15d0d8b36fb80c6295ae4222113b61807e777870cbd1fd422a35809',
      );
      expect(
        const EnvironmentConfig(
          environment: AppEnvironment.production,
        ).pushServicePubkey,
        '2f871aaa4a519da94aeb5ebffe7587549158855c4460e7a5a1b91d36d2fb5b04',
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

    group('verifierBaseUrl', () {
      test('production returns the verifier host', () {
        const config = EnvironmentConfig(
          environment: AppEnvironment.production,
        );
        expect(config.verifierBaseUrl, equals('https://verifier.divine.video'));
      });

      test('is the same across environments (no local stub)', () {
        for (final env in AppEnvironment.values) {
          final config = EnvironmentConfig(environment: env);
          expect(
            config.verifierBaseUrl,
            equals('https://verifier.divine.video'),
          );
        }
      });
    });

    group('inviteBaseUrl', () {
      // These exercise the no-define path. The
      // `bool.hasEnvironment('INVITE_SERVER_URL')` override branch cannot be
      // reached without a --dart-define on the test run itself.
      test('local tracks the resolved host on Android', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        const config = EnvironmentConfig(environment: AppEnvironment.local);
        expect(
          config.inviteBaseUrl,
          'http://$androidEmulatorHost:$localInvitePort',
        );
      });

      test('local tracks the resolved host on iOS', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        const config = EnvironmentConfig(environment: AppEnvironment.local);
        expect(config.inviteBaseUrl, 'http://$loopbackHost:$localInvitePort');
      });

      test('every non-local environment uses the invite service host', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        for (final env in AppEnvironment.values) {
          if (env == AppEnvironment.local) continue;
          final config = EnvironmentConfig(environment: env);
          expect(config.inviteBaseUrl, 'https://invite.divine.video');
        }
      });
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
