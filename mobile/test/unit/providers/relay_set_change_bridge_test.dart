// ABOUTME: Unit tests for relaySetChangeBridge provider
// ABOUTME: Verifies that relay set membership changes trigger feed reset,
// while connection state flapping does not.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/video_event_service.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockVideoEventService extends Mock implements VideoEventService {}

class SwappableNostrService extends NostrService {
  SwappableNostrService(this.initialClient);

  final NostrClient initialClient;

  @override
  NostrClient build() => initialClient;

  void replaceWith(NostrClient client) {
    state = client;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

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
      when(() => mockNostrClient.isInitialized).thenReturn(true);
      when(() => mockNostrClient.forceReconnectAll()).thenAnswer((_) async {});
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

    test('does not trigger reset on initial activation', () {
      fakeAsync((async) {
        final container = createContainer(
          initialStatuses: {
            'wss://relay1.example.com': RelayConnectionStatus.connected(
              'wss://relay1.example.com',
            ),
          },
        );

        // Elapse well past debounce to confirm nothing fires
        async.elapse(const Duration(seconds: 3));

        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());
        container.dispose();
      });
    });

    test('triggers reset when a new relay is added', () {
      fakeAsync((async) {
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

        async.flushMicrotasks();
        // Elapse past the 2s debounce timer
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verify(() => mockNostrClient.forceReconnectAll()).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        container.dispose();
      });
    });

    test('triggers reset when a relay is removed', () {
      fakeAsync((async) {
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

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        container.dispose();
      });
    });

    test('does not trigger reset on connection state flapping', () {
      fakeAsync((async) {
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

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());
        container.dispose();
      });
    });

    test('debounces rapid relay set changes into single reset', () {
      fakeAsync((async) {
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

        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 500));

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

        async.flushMicrotasks();
        // 2s from last change fires the debounce
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // Should only have fired once despite two set changes
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        container.dispose();
      });
    });

    test('handles empty initial relay set', () {
      fakeAsync((async) {
        final container = createContainer(initialStatuses: {});

        // Add first relay
        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
        });

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        container.dispose();
      });
    });

    test('does not reconnect for a change observed during initialization', () {
      fakeAsync((async) {
        var isInitialized = false;
        when(
          () => mockNostrClient.isInitialized,
        ).thenAnswer((_) => isInitialized);
        final container = createContainer(initialStatuses: {});

        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connecting(
            'wss://relay1.example.com',
          ),
        });

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        isInitialized = true;
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verifyNever(() => mockNostrClient.forceReconnectAll());
        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());
        container.dispose();
      });
    });

    test(
      'does not reconnect when client settles before service initialization',
      () {
        fakeAsync((async) {
          final container = createContainer(initialStatuses: {});
          container
              .read(nostrInitializationInProgressProvider.notifier)
              .begin(mockNostrClient);

          statusController.add({
            'wss://relay1.example.com': RelayConnectionStatus.connecting(
              'wss://relay1.example.com',
            ),
          });

          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 1));
          container
              .read(nostrInitializationInProgressProvider.notifier)
              .end(mockNostrClient);
          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();

          verifyNever(() => mockNostrClient.forceReconnectAll());
          verifyNever(() => mockVideoEventService.resetAndResubscribeAll());
          container.dispose();
        });
      },
    );

    test('defers a healthy relay change while initialization overlaps', () {
      fakeAsync((async) {
        final container = createContainer(initialStatuses: {});

        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
        });

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        container
            .read(nostrInitializationInProgressProvider.notifier)
            .begin(mockNostrClient);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verifyNever(() => mockNostrClient.forceReconnectAll());
        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());

        container
            .read(nostrInitializationInProgressProvider.notifier)
            .end(mockNostrClient);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verify(() => mockNostrClient.forceReconnectAll()).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        container.dispose();
      });
    });

    test(
      'resets for an active-client edit while a replacement initializes',
      () {
        fakeAsync((async) {
          final replacementClient = MockNostrClient();
          final container = createContainer(initialStatuses: {});
          container
              .read(nostrInitializationInProgressProvider.notifier)
              .begin(replacementClient);

          statusController.add({
            'wss://relay1.example.com': RelayConnectionStatus.connected(
              'wss://relay1.example.com',
            ),
          });

          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();

          verify(() => mockNostrClient.forceReconnectAll()).called(1);
          verify(
            () => mockVideoEventService.resetAndResubscribeAll(),
          ).called(1);
          container
              .read(nostrInitializationInProgressProvider.notifier)
              .end(replacementClient);
          container.dispose();
        });
      },
    );

    test('keeps reset intent when a startup change joins the debounce', () {
      fakeAsync((async) {
        final container = createContainer(initialStatuses: {});

        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
        });
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 500));

        container
            .read(nostrInitializationInProgressProvider.notifier)
            .begin(mockNostrClient);
        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
          'wss://relay2.example.com': RelayConnectionStatus.connecting(
            'wss://relay2.example.com',
          ),
        });
        async.flushMicrotasks();
        container
            .read(nostrInitializationInProgressProvider.notifier)
            .end(mockNostrClient);

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verify(() => mockNostrClient.forceReconnectAll()).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        container.dispose();
      });
    });

    test('carries a pending relay edit onto a replacement client', () {
      fakeAsync((async) {
        final replacementClient = MockNostrClient();
        final replacementStatuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        const removedRelay = 'wss://relay-old.example.com';
        const addedRelay = 'wss://relay1.example.com';
        final replacementRelays = <String>{removedRelay};

        when(() => mockNostrClient.relayStatuses).thenReturn({
          removedRelay: RelayConnectionStatus.connected(removedRelay),
        });
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statusController.stream);
        when(() => replacementClient.isInitialized).thenReturn(true);
        when(
          () => replacementClient.relayStatuses,
        ).thenAnswer(
          (_) => {
            for (final relay in replacementRelays)
              relay: RelayConnectionStatus.connected(relay),
          },
        );
        when(
          () => replacementClient.relayStatusStream,
        ).thenAnswer((_) => replacementStatuses.stream);
        when(
          () => replacementClient.configuredRelays,
        ).thenAnswer((_) => replacementRelays.toList());
        when(() => replacementClient.addRelays(any())).thenAnswer((call) async {
          final relays = call.positionalArguments.single as List<String>;
          replacementRelays.addAll(relays);
          return relays.length;
        });
        when(
          () => replacementClient.removeRelay(any()),
        ).thenAnswer((call) async {
          final relay = call.positionalArguments.single as String;
          return replacementRelays.remove(relay);
        });
        when(replacementClient.forceReconnectAll).thenAnswer((_) async {});

        final swappableService = SwappableNostrService(mockNostrClient);
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWith(() => swappableService),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );
        final bridgeSubscription = container.listen<void>(
          relaySetChangeBridgeProvider,
          (_, _) {},
          fireImmediately: true,
        );

        statusController.add({
          addedRelay: RelayConnectionStatus.connected(addedRelay),
        });
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));

        swappableService.replaceWith(replacementClient);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(replacementRelays, contains(addedRelay));
        expect(replacementRelays, isNot(contains(removedRelay)));
        verify(() => replacementClient.addRelays([addedRelay])).called(1);
        verify(() => replacementClient.removeRelay(removedRelay)).called(1);
        verify(replacementClient.forceReconnectAll).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        verifyNever(() => mockNostrClient.forceReconnectAll());

        bridgeSubscription.close();
        container.dispose();
        replacementStatuses.close();
      });
    });
  });
}
