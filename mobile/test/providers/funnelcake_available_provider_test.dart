// ABOUTME: Tests for FunnelcakeAvailable provider fast-path and probe logic
// ABOUTME: Verifies Divine relay detection skips probe, unknown relays still probe

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:riverpod/riverpod.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAnalyticsApiService extends Mock implements AnalyticsApiService {}

void main() {
  group(FunnelcakeAvailable, () {
    late _MockNostrClient mockNostrClient;
    late _MockAnalyticsApiService mockAnalyticsService;

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockAnalyticsService = _MockAnalyticsApiService();

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
          analyticsApiServiceProvider.overrideWithValue(mockAnalyticsService),
          currentEnvironmentProvider.overrideWithValue(environment),
        ],
      );
    }

    test('returns false when analytics service is not available', () async {
      when(() => mockAnalyticsService.isAvailable).thenReturn(false);
      when(() => mockNostrClient.configuredRelays).thenReturn(<String>[]);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(funnelcakeAvailableProvider.future);

      expect(result, isFalse);
    });

    test(
      'returns true immediately for relay.divine.video without probing',
      () async {
        when(() => mockAnalyticsService.isAvailable).thenReturn(true);
        when(() => mockNostrClient.configuredRelays).thenReturn(
          <String>['wss://relay.divine.video'],
        );

        final container = createContainer();
        addTearDown(container.dispose);

        final result = await container.read(funnelcakeAvailableProvider.future);

        expect(result, isTrue);
        // Verify no HTTP probe was made
        verifyNever(
          () => mockAnalyticsService.getRecentVideos(
            limit: 1,
            timeout: const Duration(seconds: 3),
          ),
        );
      },
    );

    test(
      'returns true immediately when fallback apiBaseUrl contains divine.video',
      () async {
        when(() => mockAnalyticsService.isAvailable).thenReturn(true);
        // No configured relays, so resolveApiBaseUrlFromRelays uses fallback
        when(() => mockNostrClient.configuredRelays).thenReturn(<String>[]);

        // Production environment has apiBaseUrl = https://relay.divine.video
        final container = createContainer();
        addTearDown(container.dispose);

        final result = await container.read(funnelcakeAvailableProvider.future);

        expect(result, isTrue);
        verifyNever(
          () => mockAnalyticsService.getRecentVideos(
            limit: 1,
            timeout: const Duration(seconds: 3),
          ),
        );
      },
    );

    test(
      'probes API for non-divine relay and returns true on success',
      () async {
        when(() => mockAnalyticsService.isAvailable).thenReturn(true);
        when(() => mockNostrClient.configuredRelays).thenReturn(
          <String>['wss://relay.custom-server.com'],
        );
        when(
          () => mockAnalyticsService.getRecentVideos(
            limit: 1,
            timeout: const Duration(seconds: 3),
          ),
        ).thenAnswer((_) async => <VideoEvent>[]);

        // Use a non-divine environment fallback
        const customEnv = EnvironmentConfig(
          environment: AppEnvironment.poc,
        );

        final container = createContainer(environment: customEnv);
        addTearDown(container.dispose);

        final result = await container.read(funnelcakeAvailableProvider.future);

        expect(result, isTrue);
        verify(
          () => mockAnalyticsService.getRecentVideos(
            limit: 1,
            timeout: const Duration(seconds: 3),
          ),
        ).called(1);
      },
    );

    test(
      'probes API for non-divine relay and returns false on failure',
      () async {
        when(() => mockAnalyticsService.isAvailable).thenReturn(true);
        when(() => mockNostrClient.configuredRelays).thenReturn(
          <String>['wss://relay.custom-server.com'],
        );
        when(
          () => mockAnalyticsService.getRecentVideos(
            limit: 1,
            timeout: const Duration(seconds: 3),
          ),
        ).thenThrow(Exception('Connection refused'));

        const customEnv = EnvironmentConfig(
          environment: AppEnvironment.poc,
        );

        final container = createContainer(environment: customEnv);
        addTearDown(container.dispose);

        final result = await container.read(funnelcakeAvailableProvider.future);

        expect(result, isFalse);
        verify(
          () => mockAnalyticsService.getRecentVideos(
            limit: 1,
            timeout: const Duration(seconds: 3),
          ),
        ).called(1);
      },
    );

    test('refresh invalidates and re-evaluates', () async {
      when(() => mockAnalyticsService.isAvailable).thenReturn(true);
      when(() => mockNostrClient.configuredRelays).thenReturn(
        <String>['wss://relay.divine.video'],
      );

      final container = createContainer();
      addTearDown(container.dispose);

      // First read
      final result1 = await container.read(funnelcakeAvailableProvider.future);
      expect(result1, isTrue);

      // Trigger refresh
      container.read(funnelcakeAvailableProvider.notifier).refresh();

      // Read again after refresh
      final result2 = await container.read(funnelcakeAvailableProvider.future);
      expect(result2, isTrue);
    });
  });
}
