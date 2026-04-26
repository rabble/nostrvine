// ABOUTME: Regression tests for relayNotificationApiServiceProvider URL selection.
// ABOUTME: Ensures notifications REST calls stay pinned to Divine/environment APIs.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  group('relayNotificationApiServiceProvider', () {
    late _MockNostrClient mockNostrClient;
    late _MockNip98AuthService mockNip98AuthService;

    const testPubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    ProviderContainer createContainer({
      required EnvironmentConfig environment,
      required List<String> configuredRelays,
    }) {
      when(() => mockNostrClient.configuredRelays).thenReturn(configuredRelays);

      return ProviderContainer(
        overrides: [
          currentEnvironmentProvider.overrideWithValue(environment),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          nip98AuthServiceProvider.overrideWithValue(mockNip98AuthService),
        ],
      );
    }

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockNip98AuthService = _MockNip98AuthService();
    });

    test('uses relay.divine.video when that relay is configured', () async {
      String? requestedUrl;

      when(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: HttpMethod.get,
        ),
      ).thenAnswer((invocation) async {
        requestedUrl = invocation.namedArguments[const Symbol('url')] as String;
        return null;
      });

      final container = createContainer(
        environment: const EnvironmentConfig(
          environment: AppEnvironment.staging,
        ),
        configuredRelays: const [
          'wss://relay.damus.io',
          'wss://relay.divine.video',
        ],
      );

      final service = container.read(relayNotificationApiServiceProvider);
      await service.getNotifications(pubkey: testPubkey);

      expect(
        requestedUrl,
        startsWith(
          'https://relay.divine.video/api/users/$testPubkey/notifications',
        ),
      );

      container.dispose();
    });

    test(
      'falls back to the environment relay URL when divine relay is absent',
      () async {
        String? requestedUrl;

        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: HttpMethod.get,
          ),
        ).thenAnswer((invocation) async {
          requestedUrl =
              invocation.namedArguments[const Symbol('url')] as String;
          return null;
        });

        final container = createContainer(
          environment: const EnvironmentConfig(
            environment: AppEnvironment.staging,
          ),
          configuredRelays: const ['wss://relay.damus.io'],
        );

        final service = container.read(relayNotificationApiServiceProvider);
        await service.getNotifications(pubkey: testPubkey);

        expect(
          requestedUrl,
          startsWith(
            'https://relay.staging.dvines.org/api/users/$testPubkey/notifications',
          ),
        );

        container.dispose();
      },
    );

    test('production fallback uses relay host, not Fastly CDN', () async {
      String? requestedUrl;

      when(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: HttpMethod.get,
        ),
      ).thenAnswer((invocation) async {
        requestedUrl = invocation.namedArguments[const Symbol('url')] as String;
        return null;
      });

      // Production with no divine relay in configured list — simulates
      // the startup race where configuredRelays is empty.
      final container = createContainer(
        environment: EnvironmentConfig.production,
        configuredRelays: const [],
      );

      final service = container.read(relayNotificationApiServiceProvider);
      await service.getNotifications(pubkey: testPubkey);

      // Must hit relay.divine.video (notification server),
      // NOT api.divine.video (Fastly CDN for FunnelCake).
      expect(
        requestedUrl,
        startsWith(
          'https://relay.divine.video/api/users/$testPubkey/notifications',
        ),
      );

      container.dispose();
    });
  });
}
