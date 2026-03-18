// ABOUTME: Tests for FunnelcakeAvailable provider fast-path and probe logic
// ABOUTME: Verifies Divine relay detection skips probe, unknown relays still probe

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:riverpod/riverpod.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  group(FunnelcakeAvailable, () {
    late _MockNostrClient mockNostrClient;
    late _MockFunnelcakeApiClient mockFunnelcakeClient;

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockFunnelcakeClient = _MockFunnelcakeApiClient();

      when(() => mockNostrClient.relayStatuses).thenReturn(
        <String, RelayConnectionStatus>{},
      );
    });

    ProviderContainer createContainer({
      EnvironmentConfig environment = EnvironmentConfig.production,
    }) {
      return ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          funnelcakeApiClientProvider.overrideWithValue(mockFunnelcakeClient),
          currentEnvironmentProvider.overrideWithValue(environment),
        ],
      );
    }

    test('returns false when Funnelcake client is not available', () async {
      when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
      when(() => mockNostrClient.configuredRelays).thenReturn(<String>[]);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(funnelcakeAvailableProvider.future);

      expect(result, isFalse);
    });

    test(
      'returns true immediately for relay.divine.video without probing',
      () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockNostrClient.configuredRelays).thenReturn(
          <String>['wss://relay.divine.video'],
        );

        final container = createContainer();
        addTearDown(container.dispose);

        final result = await container.read(funnelcakeAvailableProvider.future);

        expect(result, isTrue);
        verifyNever(() => mockFunnelcakeClient.getRecentVideos(limit: 1));
      },
    );

    test(
      'returns true immediately when fallback apiBaseUrl contains divine.video',
      () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockNostrClient.configuredRelays).thenReturn(<String>[]);

        final container = createContainer();
        addTearDown(container.dispose);

        final result = await container.read(funnelcakeAvailableProvider.future);

        expect(result, isTrue);
        verifyNever(() => mockFunnelcakeClient.getRecentVideos(limit: 1));
      },
    );

    test(
      'probes API for non-divine relay and returns true on success',
      () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockNostrClient.configuredRelays).thenReturn(
          <String>['wss://relay.custom-server.com'],
        );
        when(
          () => mockFunnelcakeClient.getRecentVideos(limit: 1),
        ).thenAnswer((_) async => <VideoStats>[]);

        const customEnv = EnvironmentConfig(
          environment: AppEnvironment.poc,
        );

        final container = createContainer(environment: customEnv);
        addTearDown(container.dispose);

        final result = await container.read(funnelcakeAvailableProvider.future);

        expect(result, isTrue);
        verify(() => mockFunnelcakeClient.getRecentVideos(limit: 1)).called(1);
      },
    );

    test(
      'probes API for non-divine relay and returns false on failure',
      () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockNostrClient.configuredRelays).thenReturn(
          <String>['wss://relay.custom-server.com'],
        );
        when(
          () => mockFunnelcakeClient.getRecentVideos(limit: 1),
        ).thenThrow(Exception('Connection refused'));

        const customEnv = EnvironmentConfig(
          environment: AppEnvironment.poc,
        );

        final container = createContainer(environment: customEnv);
        addTearDown(container.dispose);

        final result = await container.read(funnelcakeAvailableProvider.future);

        expect(result, isFalse);
        verify(() => mockFunnelcakeClient.getRecentVideos(limit: 1)).called(1);
      },
    );

    test('refresh invalidates and re-evaluates', () async {
      when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
      when(() => mockNostrClient.configuredRelays).thenReturn(
        <String>['wss://relay.divine.video'],
      );

      final container = createContainer();
      addTearDown(container.dispose);

      final result1 = await container.read(funnelcakeAvailableProvider.future);
      expect(result1, isTrue);

      container.read(funnelcakeAvailableProvider.notifier).refresh();

      final result2 = await container.read(funnelcakeAvailableProvider.future);
      expect(result2, isTrue);
    });
  });
}
