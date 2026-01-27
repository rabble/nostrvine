// ABOUTME: Unit tests for relaySetChangeBridge provider
// ABOUTME: Verifies that relay set membership changes trigger feed reset,
// while connection state flapping does not.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/video_event_service.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockVideoEventService extends Mock implements VideoEventService {}

void main() {
  group('relaySetChangeBridge', () {
    late MockNostrClient mockNostrClient;
    late MockVideoEventService mockVideoEventService;
    late StreamController<Map<String, RelayConnectionStatus>> statusController;

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockVideoEventService = MockVideoEventService();
      statusController =
          StreamController<Map<String, RelayConnectionStatus>>.broadcast();

      when(
        () => mockVideoEventService.resetAndResubscribeAll(),
      ).thenAnswer((_) async {});
    });

    tearDown(() {
      statusController.close();
    });

    ProviderContainer createContainer({
      required Map<String, RelayConnectionStatus> initialStatuses,
    }) {
      when(() => mockNostrClient.relayStatuses).thenReturn(initialStatuses);
      when(
        () => mockNostrClient.relayStatusStream,
      ).thenAnswer((_) => statusController.stream);

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      // Activate the provider
      container.read(relaySetChangeBridgeProvider);
      return container;
    }

    test('does not trigger reset on initial activation', () async {
      final container = createContainer(
        initialStatuses: {
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
        },
      );

      // Wait for any async processing
      await Future<void>.delayed(const Duration(seconds: 3));

      verifyNever(() => mockVideoEventService.resetAndResubscribeAll());
      container.dispose();
    });

    test('triggers reset when a new relay is added', () async {
      final container = createContainer(
        initialStatuses: {
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
        },
      );

      // Simulate adding a new relay
      statusController.add({
        'wss://relay1.example.com': RelayConnectionStatus.connected(
          'wss://relay1.example.com',
        ),
        'wss://relay2.example.com': RelayConnectionStatus.connected(
          'wss://relay2.example.com',
        ),
      });

      // Wait for debounce (2s) + buffer
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
      container.dispose();
    });

    test('triggers reset when a relay is removed', () async {
      final container = createContainer(
        initialStatuses: {
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
          'wss://relay2.example.com': RelayConnectionStatus.connected(
            'wss://relay2.example.com',
          ),
        },
      );

      // Simulate removing a relay
      statusController.add({
        'wss://relay1.example.com': RelayConnectionStatus.connected(
          'wss://relay1.example.com',
        ),
      });

      // Wait for debounce
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
      container.dispose();
    });

    test('does not trigger reset on connection state flapping', () async {
      final container = createContainer(
        initialStatuses: {
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
        },
      );

      // Simulate connection state change (same URLs, different status)
      statusController.add({
        'wss://relay1.example.com': RelayConnectionStatus.disconnected(
          'wss://relay1.example.com',
        ),
      });

      // Wait for debounce period
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      verifyNever(() => mockVideoEventService.resetAndResubscribeAll());
      container.dispose();
    });

    test('debounces rapid relay set changes into single reset', () async {
      final container = createContainer(
        initialStatuses: {
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
        },
      );

      // Rapid changes: add relay2, then add relay3 (within 2s window)
      statusController.add({
        'wss://relay1.example.com': RelayConnectionStatus.connected(
          'wss://relay1.example.com',
        ),
        'wss://relay2.example.com': RelayConnectionStatus.connected(
          'wss://relay2.example.com',
        ),
      });

      await Future<void>.delayed(const Duration(milliseconds: 500));

      statusController.add({
        'wss://relay1.example.com': RelayConnectionStatus.connected(
          'wss://relay1.example.com',
        ),
        'wss://relay2.example.com': RelayConnectionStatus.connected(
          'wss://relay2.example.com',
        ),
        'wss://relay3.example.com': RelayConnectionStatus.connected(
          'wss://relay3.example.com',
        ),
      });

      // Wait for debounce to fire (2s from last change)
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      // Should only have fired once despite two set changes
      verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
      container.dispose();
    });

    test('handles empty initial relay set', () async {
      final container = createContainer(initialStatuses: {});

      // Add first relay
      statusController.add({
        'wss://relay1.example.com': RelayConnectionStatus.connected(
          'wss://relay1.example.com',
        ),
      });

      // Wait for debounce
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
      container.dispose();
    });
  });
}
