import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/utils/hash_util.dart';

class _MockNostr extends Mock implements Nostr {}

class _MockRelayManager extends Mock implements RelayManager {}

class _MockAppDbClient extends Mock implements AppDbClient {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockNostrEventsDao extends Mock implements NostrEventsDao {}

class _FakeEvent extends Fake implements Event {}

class _FakeFilter extends Fake implements Filter {}

class _FakeContactList extends Fake implements ContactList {}

class _FakeRelay extends Fake implements Relay {
  @override
  final String url = 'wss://fake.example.com';

  @override
  RelayStatus relayStatus = RelayStatus('wss://fake.example.com');
}

const testPublicKey =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';

Event _createTestEvent({
  String? id,
  String? pubkey,
  int? kind,
  String? content,
  int? createdAt,
}) {
  final eventPubkey = pubkey ?? testPublicKey;
  final eventKind = kind ?? EventKind.textNote;
  final eventContent = content ?? 'Test content';
  final event = Event(
    eventPubkey,
    eventKind,
    <List<dynamic>>[],
    eventContent,
    createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
  if (id != null) {
    // Override the generated ID for testing
    event.id = id;
  }
  return event;
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('NostrClient', () {
    late _MockNostr mockNostr;
    late _MockRelayManager mockRelayManager;
    late NostrClient client;

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(_FakeFilter());
      registerFallbackValue(_FakeContactList());
      registerFallbackValue(_FakeRelay());
      registerFallbackValue(<Map<String, dynamic>>[]);
      registerFallbackValue(<String>[]);
      registerFallbackValue(RelayType.all);
      registerFallbackValue(const Duration(seconds: 10));
      registerFallbackValue(const CountResponse(count: 0));
    });

    setUp(() {
      mockNostr = _MockNostr();
      mockRelayManager = _MockRelayManager();

      // Set up default mock behavior
      when(() => mockNostr.publicKey).thenReturn(testPublicKey);
      when(() => mockNostr.close()).thenReturn(null);
      when(() => mockRelayManager.dispose()).thenAnswer((_) async {});
      // Default to having connected relays (tests can override if needed)
      when(
        () => mockRelayManager.connectedRelays,
      ).thenReturn(['wss://relay.example.com']);

      client = NostrClient.forTesting(
        nostr: mockNostr,
        relayManager: mockRelayManager,
      );
    });

    tearDown(() {
      reset(mockNostr);
      reset(mockRelayManager);
    });
    group('constructor and properties', () {
      test('publicKey returns the nostr public key', () {
        expect(client.publicKey, equals(testPublicKey));
        verify(() => mockNostr.publicKey).called(1);
      });

      test('creates client without dbClient', () {
        final localMockRelayManager = _MockRelayManager();
        final clientWithoutDb = NostrClient.forTesting(
          nostr: mockNostr,
          relayManager: localMockRelayManager,
        );
        expect(clientWithoutDb.publicKey, equals(testPublicKey));
      });
    });

    group('publishEvent', () {
      test('publishes event successfully', () async {
        final event = _createTestEvent();
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => event);

        final result = await client.publishEvent(event);

        expect(result, equals(event));
        verify(
          () => mockNostr.sendEvent(
            event,
          ),
        ).called(1);
      });

      test('publishes event with target relays', () async {
        final event = _createTestEvent();
        final targetRelays = ['wss://relay1.example.com'];
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => event);

        await client.publishEvent(event, targetRelays: targetRelays);

        verify(
          () => mockNostr.sendEvent(
            event,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when sendEvent fails', () async {
        final event = _createTestEvent();
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.publishEvent(event);

        expect(result, isNull);
      });

      test('attempts reconnection when no relays connected', () async {
        final event = _createTestEvent();
        final connectedRelays = ['wss://relay1.example.com'];

        // Initially no relays connected
        when(() => mockRelayManager.connectedRelays).thenReturn([]);
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {
          // Simulate successful reconnection by updating connected relays
          when(
            () => mockRelayManager.connectedRelays,
          ).thenReturn(connectedRelays);
        });
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => event);

        final result = await client.publishEvent(event);

        expect(result, equals(event));
        verify(mockRelayManager.retryDisconnectedRelays).called(1);
        verify(
          () => mockNostr.sendEvent(
            event,
          ),
        ).called(1);
      });

      test('returns null when reconnection fails', () async {
        final event = _createTestEvent();

        // No relays connected before and after reconnection attempt
        when(() => mockRelayManager.connectedRelays).thenReturn([]);
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {});

        final result = await client.publishEvent(event);

        expect(result, isNull);
        verify(mockRelayManager.retryDisconnectedRelays).called(1);
        verifyNever(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });

      test('does not attempt reconnection when relays are connected', () async {
        final event = _createTestEvent();
        final connectedRelays = ['wss://relay1.example.com'];

        when(
          () => mockRelayManager.connectedRelays,
        ).thenReturn(connectedRelays);
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => event);

        final result = await client.publishEvent(event);

        expect(result, equals(event));
        verifyNever(mockRelayManager.retryDisconnectedRelays);
        verify(
          () => mockNostr.sendEvent(
            event,
          ),
        ).called(1);
      });

      group('optimistic cache rollback on reconnection failure', () {
        late _MockAppDbClient mockDbClient;
        late _MockAppDatabase mockDatabase;
        late _MockNostrEventsDao mockNostrEventsDao;
        late NostrClient clientWithCache;

        setUp(() {
          mockDbClient = _MockAppDbClient();
          mockDatabase = _MockAppDatabase();
          mockNostrEventsDao = _MockNostrEventsDao();

          when(() => mockDbClient.database).thenReturn(mockDatabase);
          when(
            () => mockDatabase.nostrEventsDao,
          ).thenReturn(mockNostrEventsDao);

          clientWithCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
            dbClient: mockDbClient,
          );
        });

        tearDown(() {
          reset(mockDbClient);
          reset(mockDatabase);
          reset(mockNostrEventsDao);
        });

        test('rolls back optimistic cache when reconnection fails', () async {
          // Use a kind that DOES support optimistic caching
          // (Kind 1 = text note)
          final event = _createTestEvent(kind: EventKind.textNote);

          // No relays connected, reconnection fails
          when(() => mockRelayManager.connectedRelays).thenReturn([]);
          when(
            mockRelayManager.retryDisconnectedRelays,
          ).thenAnswer((_) async {});
          when(
            () => mockNostrEventsDao.upsertEvent(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockNostrEventsDao.deleteEventsByIds(any()),
          ).thenAnswer((_) async => 1);

          final result = await clientWithCache.publishEvent(event);

          expect(result, isNull);
          // Should have optimistically cached the event
          verify(() => mockNostrEventsDao.upsertEvent(event)).called(1);
          // Should have rolled back the cache
          verify(
            () => mockNostrEventsDao.deleteEventsByIds([event.id]),
          ).called(1);
        });

        test(
          'does not roll back cache for replaceable events when reconnection '
          'fails',
          () async {
            // Use a replaceable event kind (Kind 0 = metadata)
            final event = _createTestEvent(kind: EventKind.metadata);

            // No relays connected, reconnection fails
            when(() => mockRelayManager.connectedRelays).thenReturn([]);
            when(
              mockRelayManager.retryDisconnectedRelays,
            ).thenAnswer((_) async {});
            when(
              () => mockNostrEventsDao.upsertEvent(any()),
            ).thenAnswer((_) async {});
            when(
              () => mockNostrEventsDao.deleteEventsByIds(any()),
            ).thenAnswer((_) async => 1);

            final result = await clientWithCache.publishEvent(event);

            expect(result, isNull);
            // Should NOT have optimistically cached (replaceable events)
            verifyNever(() => mockNostrEventsDao.upsertEvent(any()));
            // Should NOT roll back (nothing was cached)
            verifyNever(() => mockNostrEventsDao.deleteEventsByIds(any()));
          },
        );

        test('continues normal flow after successful reconnection', () async {
          final event = _createTestEvent(kind: EventKind.textNote);
          final connectedRelays = ['wss://relay1.example.com'];

          // Initially no relays, but reconnection succeeds
          when(() => mockRelayManager.connectedRelays).thenReturn([]);
          when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {
            when(
              () => mockRelayManager.connectedRelays,
            ).thenReturn(connectedRelays);
          });
          when(
            () => mockNostr.sendEvent(
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => event);
          when(
            () => mockNostrEventsDao.upsertEvent(any()),
          ).thenAnswer((_) async {});

          final result = await clientWithCache.publishEvent(event);

          expect(result, equals(event));
          // Should have optimistically cached
          verify(() => mockNostrEventsDao.upsertEvent(event)).called(1);
          // Should NOT have rolled back (send succeeded)
          verifyNever(() => mockNostrEventsDao.deleteEventsByIds(any()));
        });
      });
    });

    group('queryEvents', () {
      test('queries events via WebSocket', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final events = [_createTestEvent(), _createTestEvent()];

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        final result = await client.queryEvents(filters);

        expect(result, equals(events));
        verify(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).called(1);
      });

      test('returns empty list when WebSocket returns empty', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        final result = await client.queryEvents(filters);

        expect(result, isEmpty);
      });

      test('queries with multiple filters', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
          Filter(kinds: [EventKind.metadata], limit: 5),
        ];
        final events = [_createTestEvent()];

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        final result = await client.queryEvents(filters);

        expect(result, equals(events));
      });

      test('passes all parameters to WebSocket query', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final events = [_createTestEvent()];
        final tempRelays = ['wss://temp.example.com'];

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        await client.queryEvents(
          filters,
          subscriptionId: 'test-sub',
          tempRelays: tempRelays,
          relayTypes: [RelayType.normal],
          sendAfterAuth: true,
        );

        verify(
          () => mockNostr.queryEvents(
            any(),
            id: 'test-sub',
            tempRelays: tempRelays,
            relayTypes: [RelayType.normal],
            sendAfterAuth: true,
          ),
        ).called(1);
      });
    });

    group('fetchEventById', () {
      test('fetches event via WebSocket', () async {
        const eventId = 'test-event-id';
        final event = _createTestEvent(id: eventId);

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [event]);

        final result = await client.fetchEventById(eventId);

        expect(result, equals(event));
      });

      test('uses provided relayUrl', () async {
        const eventId = 'test-event-id';
        const relayUrl = 'wss://relay.example.com';
        final event = _createTestEvent(id: eventId);

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [event]);

        await client.fetchEventById(eventId, relayUrl: relayUrl);

        verify(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: [relayUrl],
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).called(1);
      });

      test('returns null when no events found', () async {
        const eventId = 'nonexistent-id';

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        final result = await client.fetchEventById(eventId);

        expect(result, isNull);
      });
    });

    group('fetchProfile', () {
      test('fetches profile via WebSocket', () async {
        const pubkey = testPublicKey;
        final profileEvent = _createTestEvent(
          pubkey: pubkey,
          kind: EventKind.metadata,
          content: '{"name":"Test User"}',
        );

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [profileEvent]);

        final result = await client.fetchProfile(pubkey);

        expect(result, equals(profileEvent));
      });

      test('returns null when no profile found', () async {
        const pubkey = testPublicKey;

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        final result = await client.fetchProfile(pubkey);

        expect(result, isNull);
      });
    });

    group('subscribe', () {
      test('creates subscription and returns stream', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenReturn('test-sub-id');

        final stream = client.subscribe(filters);

        expect(stream, isA<Stream<Event>>());
        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).called(1);
      });

      test('creates new subscription for different filters', () {
        final filters1 = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final filters2 = [
          Filter(kinds: [EventKind.metadata], limit: 5),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenReturn('test-sub-id');

        client
          ..subscribe(filters1)
          ..subscribe(filters2);

        // Should create two separate subscriptions
        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).called(2);
      });

      test('uses custom subscription ID when provided', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        const customId = 'my-custom-subscription';

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenReturn(customId);

        client.subscribe(filters, subscriptionId: customId);

        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: customId,
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).called(1);
      });

      test('passes all parameters correctly', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenReturn('test-sub-id');

        client.subscribe(
          filters,
          subscriptionId: 'test-id',
          tempRelays: tempRelays,
          targetRelays: targetRelays,
          relayTypes: [RelayType.normal],
          sendAfterAuth: true,
        );

        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: 'test-id',
            tempRelays: tempRelays,
            targetRelays: targetRelays,
            relayTypes: [RelayType.normal],
            sendAfterAuth: true,
            onEose: any(named: 'onEose'),
          ),
        ).called(1);
      });

      test('handles nostr returning different subscription ID', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        // Nostr returns a different ID than what was requested
        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenReturn('nostr-generated-id');

        final stream = client.subscribe(filters, subscriptionId: 'my-id');

        expect(stream, isA<Stream<Event>>());
      });
    });

    group('unsubscribe', () {
      test('unsubscribes and closes stream', () async {
        const subscriptionId = 'test-sub-id';
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenReturn(subscriptionId);
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        client.subscribe(filters, subscriptionId: subscriptionId);
        await client.unsubscribe(subscriptionId);

        verify(() => mockNostr.unsubscribe(subscriptionId)).called(1);
      });

      test('handles unsubscribing non-existent subscription', () async {
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        // Should not throw
        await client.unsubscribe('nonexistent-id');

        verify(() => mockNostr.unsubscribe('nonexistent-id')).called(1);
      });
    });

    group('closeAllSubscriptions', () {
      test('closes all active subscriptions', () async {
        final filters1 = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final filters2 = [
          Filter(kinds: [EventKind.metadata], limit: 5),
        ];

        var callCount = 0;
        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => 'sub-${callCount++}');
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        client
          ..subscribe(filters1)
          ..subscribe(filters2);
        await client.closeAllSubscriptions();

        verify(() => mockNostr.unsubscribe(any())).called(2);
      });

      test('handles no active subscriptions', () async {
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        // Should not throw
        await client.closeAllSubscriptions();

        verifyNever(() => mockNostr.unsubscribe(any()));
      });
    });

    group('addRelay', () {
      test('delegates to RelayManager', () async {
        const relayUrl = 'wss://relay.example.com';
        when(
          () => mockRelayManager.addRelay(relayUrl),
        ).thenAnswer((_) async => true);

        final result = await client.addRelay(relayUrl);

        expect(result, isTrue);
        verify(() => mockRelayManager.addRelay(relayUrl)).called(1);
      });

      test('returns false when RelayManager returns false', () async {
        const relayUrl = 'wss://relay.example.com';
        when(
          () => mockRelayManager.addRelay(relayUrl),
        ).thenAnswer((_) async => false);

        final result = await client.addRelay(relayUrl);

        expect(result, isFalse);
      });
    });

    group('addRelays', () {
      test(
        'adds multiple relays and returns count of successful additions',
        () async {
          final relayUrls = [
            'wss://relay1.example.com',
            'wss://relay2.example.com',
            'wss://relay3.example.com',
          ];

          when(
            () => mockRelayManager.addRelay(any()),
          ).thenAnswer((_) async => true);

          final result = await client.addRelays(relayUrls);

          expect(result, equals(3));
          verify(() => mockRelayManager.addRelay(relayUrls[0])).called(1);
          verify(() => mockRelayManager.addRelay(relayUrls[1])).called(1);
          verify(() => mockRelayManager.addRelay(relayUrls[2])).called(1);
        },
      );

      test('returns 0 when empty list is provided', () async {
        final result = await client.addRelays([]);

        expect(result, equals(0));
        verifyNever(() => mockRelayManager.addRelay(any()));
      });

      test(
        'handles partial failures and returns count of successful only',
        () async {
          final relayUrls = [
            'wss://relay1.example.com',
            'wss://relay2.example.com',
            'wss://relay3.example.com',
          ];

          // First and third succeed, second fails
          when(
            () => mockRelayManager.addRelay('wss://relay1.example.com'),
          ).thenAnswer((_) async => true);
          when(
            () => mockRelayManager.addRelay('wss://relay2.example.com'),
          ).thenAnswer((_) async => false);
          when(
            () => mockRelayManager.addRelay('wss://relay3.example.com'),
          ).thenAnswer((_) async => true);

          final result = await client.addRelays(relayUrls);

          expect(result, equals(2));
        },
      );

      test('returns 0 when all relays fail to add', () async {
        final relayUrls = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ];

        when(
          () => mockRelayManager.addRelay(any()),
        ).thenAnswer((_) async => false);

        final result = await client.addRelays(relayUrls);

        expect(result, equals(0));
      });

      test('adds single relay successfully', () async {
        final relayUrls = ['wss://single-relay.example.com'];

        when(
          () => mockRelayManager.addRelay(any()),
        ).thenAnswer((_) async => true);

        final result = await client.addRelays(relayUrls);

        expect(result, equals(1));
        verify(
          () => mockRelayManager.addRelay('wss://single-relay.example.com'),
        ).called(1);
      });
    });

    group('removeRelay', () {
      test('delegates to RelayManager', () async {
        const relayUrl = 'wss://relay.example.com';
        when(
          () => mockRelayManager.removeRelay(relayUrl),
        ).thenAnswer((_) async => true);

        final result = await client.removeRelay(relayUrl);

        expect(result, isTrue);
        verify(() => mockRelayManager.removeRelay(relayUrl)).called(1);
      });
    });

    group('connectedRelays', () {
      test('delegates to RelayManager', () {
        final expectedRelays = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ];
        when(() => mockRelayManager.connectedRelays).thenReturn(expectedRelays);

        final result = client.connectedRelays;

        expect(result, equals(expectedRelays));
        verify(() => mockRelayManager.connectedRelays).called(1);
      });

      test('returns empty list when no relays connected', () {
        when(() => mockRelayManager.connectedRelays).thenReturn([]);

        final result = client.connectedRelays;

        expect(result, isEmpty);
      });
    });

    group('connectedRelayCount', () {
      test('delegates to RelayManager', () {
        when(() => mockRelayManager.connectedRelayCount).thenReturn(3);

        expect(client.connectedRelayCount, equals(3));
        verify(() => mockRelayManager.connectedRelayCount).called(1);
      });

      test('returns 0 when no relays connected', () {
        when(() => mockRelayManager.connectedRelayCount).thenReturn(0);

        expect(client.connectedRelayCount, equals(0));
      });
    });

    group('relayStatuses', () {
      test('delegates to RelayManager', () {
        final expectedStatuses = {
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
          'wss://relay2.example.com': RelayConnectionStatus.connected(
            'wss://relay2.example.com',
          ),
        };
        when(
          () => mockRelayManager.currentStatuses,
        ).thenReturn(expectedStatuses);

        final result = client.relayStatuses;

        expect(result, equals(expectedStatuses));
        verify(() => mockRelayManager.currentStatuses).called(1);
      });

      test('returns empty map when no relays', () {
        when(() => mockRelayManager.currentStatuses).thenReturn({});

        final result = client.relayStatuses;

        expect(result, isEmpty);
      });
    });

    group('configuredRelays', () {
      test('delegates to RelayManager', () {
        final expectedRelays = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ];
        when(
          () => mockRelayManager.configuredRelays,
        ).thenReturn(expectedRelays);

        final result = client.configuredRelays;

        expect(result, equals(expectedRelays));
        verify(() => mockRelayManager.configuredRelays).called(1);
      });
    });

    group('configuredRelayCount', () {
      test('delegates to RelayManager', () {
        when(() => mockRelayManager.configuredRelayCount).thenReturn(2);

        expect(client.configuredRelayCount, equals(2));
        verify(() => mockRelayManager.configuredRelayCount).called(1);
      });

      test('returns 0 when no relays configured', () {
        when(() => mockRelayManager.configuredRelayCount).thenReturn(0);

        expect(client.configuredRelayCount, equals(0));
      });
    });

    group('relayStatusStream', () {
      test('delegates to RelayManager', () async {
        final controller =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        when(
          () => mockRelayManager.statusStream,
        ).thenAnswer((_) => controller.stream);

        final result = client.relayStatusStream;

        expect(result, isNotNull);
        verify(() => mockRelayManager.statusStream).called(1);

        await controller.close();
      });
    });

    group('retryDisconnectedRelays', () {
      test('delegates to RelayManager', () async {
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {});

        await client.retryDisconnectedRelays();

        verify(mockRelayManager.retryDisconnectedRelays).called(1);
      });
    });

    group('forceReconnectAll', () {
      test('delegates to RelayManager', () async {
        when(mockRelayManager.forceReconnectAll).thenAnswer((_) async {});

        await client.forceReconnectAll();

        verify(mockRelayManager.forceReconnectAll).called(1);
      });
    });

    group('sendLike', () {
      test('sends like successfully', () async {
        const eventId = 'event-to-like';
        final likeEvent = _createTestEvent(kind: EventKind.reaction);

        when(
          () => mockNostr.sendLike(
            any(),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => likeEvent);

        final result = await client.sendLike(eventId);

        expect(result, equals(likeEvent));
        verify(
          () => mockNostr.sendLike(
            eventId,
          ),
        ).called(1);
      });

      test('sends like with custom content', () async {
        const eventId = 'event-to-like';
        const content = '❤️';
        final likeEvent = _createTestEvent(kind: EventKind.reaction);

        when(
          () => mockNostr.sendLike(
            any(),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => likeEvent);

        await client.sendLike(eventId, content: content);

        verify(
          () => mockNostr.sendLike(
            eventId,
            content: content,
          ),
        ).called(1);
      });

      test('sends like with relay parameters', () async {
        const eventId = 'event-to-like';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final likeEvent = _createTestEvent(kind: EventKind.reaction);

        when(
          () => mockNostr.sendLike(
            any(),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => likeEvent);

        await client.sendLike(
          eventId,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.sendLike(
            eventId,
            tempRelays: tempRelays,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when sendLike fails', () async {
        const eventId = 'event-to-like';

        when(
          () => mockNostr.sendLike(
            any(),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.sendLike(eventId);

        expect(result, isNull);
      });
    });

    group('sendRepost', () {
      test('sends repost successfully', () async {
        const eventId = 'event-to-repost';
        final repostEvent = _createTestEvent(kind: EventKind.repost);

        when(
          () => mockNostr.sendRepost(
            any(),
            relayAddr: any(named: 'relayAddr'),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => repostEvent);

        final result = await client.sendRepost(eventId);

        expect(result, equals(repostEvent));
        verify(
          () => mockNostr.sendRepost(
            eventId,
          ),
        ).called(1);
      });

      test('sends repost with all parameters', () async {
        const eventId = 'event-to-repost';
        const relayAddr = 'wss://relay.example.com';
        const content = '{"event":"data"}';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final repostEvent = _createTestEvent(kind: EventKind.repost);

        when(
          () => mockNostr.sendRepost(
            any(),
            relayAddr: any(named: 'relayAddr'),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => repostEvent);

        await client.sendRepost(
          eventId,
          relayAddr: relayAddr,
          content: content,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.sendRepost(
            eventId,
            relayAddr: relayAddr,
            content: content,
            tempRelays: tempRelays,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when sendRepost fails', () async {
        const eventId = 'event-to-repost';

        when(
          () => mockNostr.sendRepost(
            any(),
            relayAddr: any(named: 'relayAddr'),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.sendRepost(eventId);

        expect(result, isNull);
      });
    });

    group('sendGenericRepost', () {
      const addressableId = '''
34236:82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2
:unique-identifier''';
      const targetKind = 34236;
      const authorPubkey =
          '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';

      test('sends generic repost successfully', () async {
        final repostEvent = _createTestEvent(kind: EventKind.genericRepost);

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => repostEvent);

        final result = await client.sendGenericRepost(
          addressableId: addressableId,
          targetKind: targetKind,
          authorPubkey: authorPubkey,
        );

        expect(result, equals(repostEvent));
        final captured =
            verify(
                  () => mockNostr.sendEvent(
                    captureAny(),
                    tempRelays: any(named: 'tempRelays'),
                    targetRelays: any(named: 'targetRelays'),
                  ),
                ).captured.single
                as Event;

        expect(captured.kind, equals(EventKind.genericRepost));
        expect(captured.content, isEmpty);
        expect(
          captured.tags,
          containsAll([
            ['k', '$targetKind'],
            ['a', addressableId],
            ['p', authorPubkey],
          ]),
        );
      });

      test('sends generic repost with all parameters', () async {
        const content = 'Test repost content';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final repostEvent = _createTestEvent(kind: EventKind.genericRepost);

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => repostEvent);

        final result = await client.sendGenericRepost(
          addressableId: addressableId,
          targetKind: targetKind,
          authorPubkey: authorPubkey,
          content: content,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        expect(result, equals(repostEvent));
        final captured =
            verify(
                  () => mockNostr.sendEvent(
                    captureAny(),
                    tempRelays: tempRelays,
                    targetRelays: targetRelays,
                  ),
                ).captured.single
                as Event;

        expect(captured.content, equals(content));
      });

      test('returns null when sendEvent fails', () async {
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.sendGenericRepost(
          addressableId: addressableId,
          targetKind: targetKind,
          authorPubkey: authorPubkey,
        );

        expect(result, isNull);
      });

      test('creates event with correct tag structure', () async {
        final repostEvent = _createTestEvent(kind: EventKind.genericRepost);

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => repostEvent);

        await client.sendGenericRepost(
          addressableId: addressableId,
          targetKind: targetKind,
          authorPubkey: authorPubkey,
        );

        final captured =
            verify(
                  () => mockNostr.sendEvent(
                    captureAny(),
                    tempRelays: any(named: 'tempRelays'),
                    targetRelays: any(named: 'targetRelays'),
                  ),
                ).captured.single
                as Event;

        // Verify tags are in correct order: k, a, p
        expect(captured.tags.length, equals(3));
        final tag0 = captured.tags[0] as List<dynamic>;
        final tag1 = captured.tags[1] as List<dynamic>;
        final tag2 = captured.tags[2] as List<dynamic>;
        expect(tag0[0], equals('k'));
        expect(tag0[1], equals('$targetKind'));
        expect(tag1[0], equals('a'));
        expect(tag1[1], equals(addressableId));
        expect(tag2[0], equals('p'));
        expect(tag2[1], equals(authorPubkey));
      });
    });

    group('deleteEvent', () {
      test('deletes event successfully', () async {
        const eventId = 'event-to-delete';
        final deleteEvent = _createTestEvent(kind: EventKind.eventDeletion);

        when(
          () => mockNostr.deleteEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        final result = await client.deleteEvent(eventId);

        expect(result, equals(deleteEvent));
        verify(
          () => mockNostr.deleteEvent(
            eventId,
          ),
        ).called(1);
      });

      test('deletes event with relay parameters', () async {
        const eventId = 'event-to-delete';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final deleteEvent = _createTestEvent(kind: EventKind.eventDeletion);

        when(
          () => mockNostr.deleteEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        await client.deleteEvent(
          eventId,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.deleteEvent(
            eventId,
            tempRelays: tempRelays,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when deleteEvent fails', () async {
        const eventId = 'event-to-delete';

        when(
          () => mockNostr.deleteEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.deleteEvent(eventId);

        expect(result, isNull);
      });
    });

    group('deleteEvents', () {
      test('deletes multiple events successfully', () async {
        final eventIds = ['event-1', 'event-2', 'event-3'];
        final deleteEvent = _createTestEvent(kind: EventKind.eventDeletion);

        when(
          () => mockNostr.deleteEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        final result = await client.deleteEvents(eventIds);

        expect(result, equals(deleteEvent));
        verify(
          () => mockNostr.deleteEvents(
            eventIds,
          ),
        ).called(1);
      });

      test('deletes events with relay parameters', () async {
        final eventIds = ['event-1', 'event-2'];
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final deleteEvent = _createTestEvent(kind: EventKind.eventDeletion);

        when(
          () => mockNostr.deleteEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        await client.deleteEvents(
          eventIds,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.deleteEvents(
            eventIds,
            tempRelays: tempRelays,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when deleteEvents fails', () async {
        final eventIds = ['event-1', 'event-2'];

        when(
          () => mockNostr.deleteEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.deleteEvents(eventIds);

        expect(result, isNull);
      });
    });

    group('sendContactList', () {
      test('sends contact list successfully', () async {
        final contacts = ContactList();
        const content = '{"relay":"preferences"}';
        final contactListEvent = _createTestEvent(kind: EventKind.contactList);

        when(
          () => mockNostr.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => contactListEvent);

        final result = await client.sendContactList(contacts, content);

        expect(result, equals(contactListEvent));
        verify(
          () => mockNostr.sendContactList(
            contacts,
            content,
          ),
        ).called(1);
      });

      test('sends contact list with relay parameters', () async {
        final contacts = ContactList();
        const content = '{"relay":"preferences"}';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final contactListEvent = _createTestEvent(kind: EventKind.contactList);

        when(
          () => mockNostr.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => contactListEvent);

        await client.sendContactList(
          contacts,
          content,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.sendContactList(
            contacts,
            content,
            tempRelays: tempRelays,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when sendContactList fails', () async {
        final contacts = ContactList();
        const content = '{"relay":"preferences"}';

        when(
          () => mockNostr.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.sendContactList(contacts, content);

        expect(result, isNull);
      });
    });

    group('createNip98AuthHeader', () {
      test(
        'returns "Nostr <base64>" with payload tag when payload is provided',
        () async {
          when(() => mockNostr.signEvent(any())).thenAnswer((invocation) {
            invocation.positionalArguments[0] as Event
              ..id = 'id'
              ..sig = 'sig';
            return Future.value();
          });

          const url = 'https://divine.video/api/username/claim';
          final authHeader = await client.createNip98AuthHeader(
            url: url,
            method: 'POST',
            payload: 'payload',
          );
          final decoded =
              jsonDecode(utf8.decode(base64Decode(authHeader!.split(' ')[1])))
                  as Map<String, dynamic>;
          final tags = (decoded['tags'] as List).cast<List<dynamic>>();

          expect(authHeader, startsWith('Nostr '));
          expect(decoded['kind'], equals(EventKind.httpAuth));
          expect(tags[0][1], equals(url));
          expect(tags[1][1], equals('POST'));
          expect(
            tags[2][1],
            equals(HashUtil.sha256Bytes(utf8.encode('payload'))),
          );
        },
      );

      test(
        'returns "Nostr <base64>" without payload tag when payload is not '
        'provided',
        () async {
          when(() => mockNostr.signEvent(any())).thenAnswer((invocation) {
            invocation.positionalArguments[0] as Event
              ..id = 'id'
              ..sig = 'sig';
            return Future.value();
          });

          const url = 'https://divine.video/api/username/claim';
          final authHeader = await client.createNip98AuthHeader(
            url: url,
            method: 'POST',
          );
          final decoded =
              jsonDecode(utf8.decode(base64Decode(authHeader!.split(' ')[1])))
                  as Map<String, dynamic>;
          final tags = (decoded['tags'] as List).cast<List<dynamic>>();

          expect(authHeader, startsWith('Nostr '));
          expect(decoded['kind'], equals(EventKind.httpAuth));
          expect(tags[0][1], equals(url));
          expect(tags[1][1], equals('POST'));
          expect(tags.length, equals(2));
        },
      );

      test(
        'returns null when signing fails',
        () async {
          when(
            () => mockNostr.signEvent(any()),
          ).thenAnswer((_) => Future.value());

          const url = 'https://divine.video/api/username/claim';
          final authHeader = await client.createNip98AuthHeader(
            url: url,
            method: 'POST',
          );
          expect(authHeader, isNull);
        },
      );
    });

    group('dispose', () {
      test('closes all subscriptions and nostr client', () async {
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        await client.dispose();

        verify(() => mockNostr.close()).called(1);
      });

      test('closes active subscriptions before disposing', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenReturn('test-sub-id');
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        client.subscribe(filters);
        await client.dispose();

        verify(() => mockNostr.unsubscribe(any())).called(1);
        verify(() => mockNostr.close()).called(1);
      });
    });

    group('Database caching integration', () {
      late _MockAppDbClient mockDbClient;
      late _MockAppDatabase mockDatabase;
      late _MockNostrEventsDao mockNostrEventsDao;
      late NostrClient clientWithCache;

      setUp(() {
        mockDbClient = _MockAppDbClient();
        mockDatabase = _MockAppDatabase();
        mockNostrEventsDao = _MockNostrEventsDao();

        when(() => mockDbClient.database).thenReturn(mockDatabase);
        when(() => mockDatabase.nostrEventsDao).thenReturn(mockNostrEventsDao);

        clientWithCache = NostrClient.forTesting(
          nostr: mockNostr,
          relayManager: mockRelayManager,
          dbClient: mockDbClient,
        );
      });

      tearDown(() {
        reset(mockDbClient);
        reset(mockDatabase);
        reset(mockNostrEventsDao);
      });

      group('constructor with dbClient', () {
        test('creates client with dbClient', () {
          expect(clientWithCache.publicKey, equals(testPublicKey));
        });

        test('creates client without dbClient (backward compat)', () {
          final clientWithoutCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
          );
          expect(clientWithoutCache.publicKey, equals(testPublicKey));
        });
      });

      group('subscribe with auto-caching', () {
        test('caches events received from subscription', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];
          final event = _createTestEvent();

          // Capture the callback passed to nostr.subscribe
          void Function(Event)? capturedCallback;
          when(
            () => mockNostr.subscribe(
              any(),
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((invocation) {
            capturedCallback =
                invocation.positionalArguments[1] as void Function(Event);
            return 'test-sub-id';
          });

          when(
            () => mockNostrEventsDao.upsertEvent(any()),
          ).thenAnswer((_) async {});

          // Subscribe to get the stream
          final stream = clientWithCache.subscribe(filters);
          final receivedEvents = <Event>[];
          final subscription = stream.listen(receivedEvents.add);

          // Simulate receiving an event from nostr_sdk
          capturedCallback?.call(event);

          // Give async operations time to complete
          await Future<void>.delayed(Duration.zero);

          expect(receivedEvents, contains(event));
          verify(() => mockNostrEventsDao.upsertEvent(event)).called(1);

          await subscription.cancel();
        });

        test('does not cache when dbClient is null', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];
          final event = _createTestEvent();

          // Use client without cache
          void Function(Event)? capturedCallback;
          when(
            () => mockNostr.subscribe(
              any(),
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((invocation) {
            capturedCallback =
                invocation.positionalArguments[1] as void Function(Event);
            return 'test-sub-id';
          });

          final stream = client.subscribe(filters);
          final receivedEvents = <Event>[];
          final subscription = stream.listen(receivedEvents.add);

          capturedCallback?.call(event);
          await Future<void>.delayed(Duration.zero);

          expect(receivedEvents, contains(event));
          // Should not interact with DAO since client has no dbClient
          verifyNever(() => mockNostrEventsDao.upsertEvent(any()));

          await subscription.cancel();
        });

        test('still emits event even if caching fails', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];
          final event = _createTestEvent();

          void Function(Event)? capturedCallback;
          when(
            () => mockNostr.subscribe(
              any(),
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((invocation) {
            capturedCallback =
                invocation.positionalArguments[1] as void Function(Event);
            return 'test-sub-id';
          });

          // Make caching fail
          when(
            () => mockNostrEventsDao.upsertEvent(any()),
          ).thenThrow(Exception('Cache error'));

          final stream = clientWithCache.subscribe(filters);
          final receivedEvents = <Event>[];
          final subscription = stream.listen(receivedEvents.add);

          capturedCallback?.call(event);
          await Future<void>.delayed(Duration.zero);

          // Event should still be emitted even if caching failed
          expect(receivedEvents, contains(event));

          await subscription.cancel();
        });
      });

      group('queryEvents with cache-first', () {
        test('returns merged cache + websocket events', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];
          final cachedEvents = [
            _createTestEvent(content: 'cached 1'),
          ];
          final wsEvents = [
            _createTestEvent(content: 'from websocket'),
          ];

          when(
            () => mockNostrEventsDao.getEventsByFilter(any()),
          ).thenAnswer((_) async => cachedEvents);
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => wsEvents);
          when(
            () => mockNostrEventsDao.upsertEventsBatch(any()),
          ).thenAnswer((_) async {});

          final result = await clientWithCache.queryEvents(filters);

          // Cache + WebSocket results merged
          expect(result.length, 2);
          verify(
            () => mockNostrEventsDao.getEventsByFilter(filters.first),
          ).called(1);
        });

        test('queries websocket when cache is empty', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];
          final wsEvents = [_createTestEvent(content: 'from websocket')];

          when(
            () => mockNostrEventsDao.getEventsByFilter(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => wsEvents);
          when(
            () => mockNostrEventsDao.upsertEventsBatch(any()),
          ).thenAnswer((_) async {});

          final result = await clientWithCache.queryEvents(filters);

          expect(result, equals(wsEvents));
          verify(
            () => mockNostrEventsDao.upsertEventsBatch(wsEvents),
          ).called(1);
        });

        test('returns empty when both cache and websocket are empty', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];

          when(
            () => mockNostrEventsDao.getEventsByFilter(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => []);

          final result = await clientWithCache.queryEvents(filters);

          expect(result, isEmpty);
          verify(() => mockNostrEventsDao.getEventsByFilter(any())).called(1);
        });

        test('works without dbClient (backward compat)', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];
          final wsEvents = [_createTestEvent(content: 'from websocket')];

          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => wsEvents);

          // Using client without cache
          final result = await client.queryEvents(filters);

          expect(result, equals(wsEvents));
          verifyNever(() => mockNostrEventsDao.getEventsByFilter(any()));
          verifyNever(() => mockNostrEventsDao.upsertEventsBatch(any()));
        });

        test('skips cache when multiple filters provided', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
            Filter(kinds: [EventKind.metadata], limit: 5),
          ];
          final wsEvents = [_createTestEvent(content: 'from websocket')];

          // Cache should not be checked for multiple filters
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => wsEvents);
          when(
            () => mockNostrEventsDao.upsertEventsBatch(any()),
          ).thenAnswer((_) async {});

          final result = await clientWithCache.queryEvents(filters);

          expect(result, equals(wsEvents));
          // Cache should not be checked for multiple filters
          verifyNever(() => mockNostrEventsDao.getEventsByFilter(any()));
        });
      });

      group('fetchEventById with cache-first', () {
        test('returns cached event when available', () async {
          const eventId = 'test-event-id-12345';
          final cachedEvent = _createTestEvent(id: eventId);

          when(
            () => mockNostrEventsDao.getEventById(eventId),
          ).thenAnswer((_) async => cachedEvent);

          final result = await clientWithCache.fetchEventById(eventId);

          expect(result, equals(cachedEvent));
          verify(() => mockNostrEventsDao.getEventById(eventId)).called(1);
        });

        test('falls back to websocket when cache misses', () async {
          const eventId = 'test-event-id-12345';
          final wsEvent = _createTestEvent(id: eventId);

          when(
            () => mockNostrEventsDao.getEventById(eventId),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => [wsEvent]);
          when(
            () => mockNostrEventsDao.upsertEvent(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockNostrEventsDao.upsertEventsBatch(any()),
          ).thenAnswer((_) async {});

          final result = await clientWithCache.fetchEventById(eventId);

          expect(result, equals(wsEvent));
          // Should cache the websocket result
          verify(() => mockNostrEventsDao.upsertEvent(wsEvent)).called(1);
        });
      });

      group('fetchProfile with cache-first', () {
        test('returns cached profile when available', () async {
          const pubkey = testPublicKey;
          final cachedProfile = _createTestEvent(
            pubkey: pubkey,
            kind: EventKind.metadata,
            content: '{"name":"Cached User"}',
          );

          when(
            () => mockNostrEventsDao.getProfileByPubkey(pubkey),
          ).thenAnswer((_) async => cachedProfile);

          final result = await clientWithCache.fetchProfile(pubkey);

          expect(result, equals(cachedProfile));
          verify(() => mockNostrEventsDao.getProfileByPubkey(pubkey)).called(1);
        });

        test('falls back to websocket when cache misses', () async {
          const pubkey = testPublicKey;
          final wsProfile = _createTestEvent(
            pubkey: pubkey,
            kind: EventKind.metadata,
            content: '{"name":"WebSocket User"}',
          );

          when(
            () => mockNostrEventsDao.getProfileByPubkey(pubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => [wsProfile]);
          when(
            () => mockNostrEventsDao.upsertEvent(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockNostrEventsDao.upsertEventsBatch(any()),
          ).thenAnswer((_) async {});

          final result = await clientWithCache.fetchProfile(pubkey);

          expect(result, equals(wsProfile));
          // Should cache the websocket result
          verify(() => mockNostrEventsDao.upsertEvent(wsProfile)).called(1);
        });
      });
    });

    group('state properties', () {
      test(
        'isInitialized returns false when relay manager not initialized',
        () {
          when(() => mockRelayManager.isInitialized).thenReturn(false);
          expect(client.isInitialized, isFalse);
        },
      );

      test('isInitialized returns true when relay manager is initialized', () {
        when(() => mockRelayManager.isInitialized).thenReturn(true);
        expect(client.isInitialized, isTrue);
      });

      test('isDisposed returns false before dispose', () {
        expect(client.isDisposed, isFalse);
      });

      test('isDisposed returns true after dispose', () async {
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        await client.dispose();

        expect(client.isDisposed, isTrue);
      });

      test('hasKeys returns true when public key is not empty', () {
        when(() => mockNostr.publicKey).thenReturn(testPublicKey);

        expect(client.hasKeys, isTrue);
      });

      test('hasKeys returns false when public key is empty', () {
        when(() => mockNostr.publicKey).thenReturn('');

        expect(client.hasKeys, isFalse);
      });
    });

    group('relay convenience properties', () {
      test('configuredRelayCount returns count from manager', () {
        when(() => mockRelayManager.configuredRelayCount).thenReturn(3);

        expect(client.configuredRelayCount, equals(3));
        verify(() => mockRelayManager.configuredRelayCount).called(1);
      });

      test('configuredRelays returns list from manager', () {
        final expectedRelays = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ];
        when(
          () => mockRelayManager.configuredRelays,
        ).thenReturn(expectedRelays);

        expect(client.configuredRelays, equals(expectedRelays));
        verify(() => mockRelayManager.configuredRelays).called(1);
      });
    });

    group('searchVideos', () {
      test('returns stream of video events matching query', () async {
        const query = 'test video';
        final videoEvent = _createTestEvent(
          kind: 34236,
          content: 'Test video content',
        );

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((invocation) {
          // Get the callback and call it with test event
          final callback =
              invocation.positionalArguments[1] as void Function(Event);
          unawaited(Future.microtask(() => callback(videoEvent)));
          return 'search-sub-id';
        });

        final stream = client.searchVideos(query);
        final events = await stream.take(1).toList();

        expect(events, hasLength(1));
        expect(events.first.kind, equals(34236));
      });

      test('passes correct filter parameters', () async {
        const query = 'test';
        final since = DateTime(2024);
        final until = DateTime(2024, 12, 31);
        const limit = 50;

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenReturn('search-sub-id');

        client.searchVideos(
          query,
          since: since,
          until: until,
          limit: limit,
        );

        // Verify subscribe was called with filter containing search
        final captured = verify(
          () => mockNostr.subscribe(
            captureAny(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).captured;

        final filters = captured.first as List<Map<String, dynamic>>;
        expect(filters.first['search'], equals(query));
        expect(filters.first['kinds'], contains(34236));
        expect(filters.first['limit'], equals(limit));
      });
    });

    group('searchUsers', () {
      test('returns stream of profile events matching query', () async {
        const query = 'test user';
        final profileEvent = _createTestEvent(
          kind: EventKind.metadata,
          content: '{"name": "Test User"}',
        );

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((invocation) {
          final callback =
              invocation.positionalArguments[1] as void Function(Event);
          unawaited(Future.microtask(() => callback(profileEvent)));
          return 'search-sub-id';
        });

        final stream = client.searchUsers(query);
        final events = await stream.take(1).toList();

        expect(events, hasLength(1));
        expect(events.first.kind, equals(EventKind.metadata));
      });

      test('uses metadata kind filter', () async {
        const query = 'user';

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenReturn('search-sub-id');

        client.searchUsers(query);

        final captured = verify(
          () => mockNostr.subscribe(
            captureAny(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).captured;

        final filters = captured.first as List<Map<String, dynamic>>;
        expect(filters.first['search'], equals(query));
        expect(filters.first['kinds'], contains(EventKind.metadata));
      });
    });

    group('countEvents', () {
      test('returns count from relay COUNT response', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], authors: [testPublicKey]),
        ];
        const countResponse = CountResponse(count: 42);

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => countResponse);

        final result = await client.countEvents(filters);

        expect(result.count, equals(42));
        expect(result.approximate, isFalse);
        expect(result.source, equals(CountSource.websocket));
      });

      test('handles approximate counts', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        const countResponse = CountResponse(count: 1000, approximate: true);

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => countResponse);

        final result = await client.countEvents(filters);

        expect(result.count, equals(1000));
        expect(result.approximate, isTrue);
        expect(result.source, equals(CountSource.websocket));
      });

      test('falls back to queryEvents when COUNT not supported', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        final events = [
          _createTestEvent(),
          _createTestEvent(),
          _createTestEvent(),
        ];

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(CountNotSupportedException('Not supported'));
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        final result = await client.countEvents(filters);

        expect(result.count, equals(3));
        expect(result.approximate, isFalse);
        expect(result.source, equals(CountSource.clientSide));
      });

      test('passes subscriptionId parameter', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        const customId = 'my-count-sub';

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const CountResponse(count: 10));

        await client.countEvents(filters, subscriptionId: customId);

        verify(
          () => mockNostr.countEvents(
            any(),
            id: customId,
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test('passes timeout parameter', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        const customTimeout = Duration(seconds: 5);

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const CountResponse(count: 10));

        await client.countEvents(filters, timeout: customTimeout);

        verify(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: customTimeout,
          ),
        ).called(1);
      });

      test('passes tempRelays parameter', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        final tempRelays = ['wss://temp.example.com'];

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const CountResponse(count: 10));

        await client.countEvents(filters, tempRelays: tempRelays);

        verify(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: tempRelays,
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test('passes relayTypes parameter', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        final relayTypes = [RelayType.normal];

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const CountResponse(count: 10));

        await client.countEvents(filters, relayTypes: relayTypes);

        verify(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: relayTypes,
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test('converts Filter objects to JSON', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], authors: [testPublicKey]),
        ];

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const CountResponse(count: 5));

        await client.countEvents(filters);

        final captured = verify(
          () => mockNostr.countEvents(
            captureAny(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).captured;

        final capturedFilters = captured.first as List<Map<String, dynamic>>;
        expect(capturedFilters.first['kinds'], contains(EventKind.textNote));
        expect(capturedFilters.first['authors'], contains(testPublicKey));
      });
    });
  });
}
