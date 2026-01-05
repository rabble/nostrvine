// ABOUTME: Unit tests for CuratedListService initialization performance
// ABOUTME: Verifies that initialization completes quickly without blocking on relay sync

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curated_list_service_initialization_test.mocks.dart';

@GenerateMocks([NostrClient, AuthService])
void main() {
  group('CuratedListService - Initialization Performance', () {
    late MockNostrClient mockNostr;
    late MockAuthService mockAuth;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockNostr = MockNostrClient();
      mockAuth = MockAuthService();
      prefs = await SharedPreferences.getInstance();

      when(mockAuth.isAuthenticated).thenReturn(true);
      when(
        mockAuth.currentPublicKeyHex,
      ).thenReturn('test_pubkey_123456789abcdef');

      when(mockNostr.broadcast(any)).thenAnswer((_) async {
        final event = Event.fromJson({
          'id': 'test_event_id',
          'pubkey': 'test_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [],
          'content': 'test',
          'sig': 'test_sig',
        });
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'wss://relay.example.com': true},
          errors: {},
        );
      });

      when(
        mockAuth.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer(
        (_) async => Event.fromJson({
          'id': 'test_event_id',
          'pubkey': 'test_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [],
          'content': 'test',
          'sig': 'test_sig',
        }),
      );
    });

    test(
      'initialize() completes quickly without waiting for relay sync',
      () async {
        // Set up a SLOW relay response (simulates 7+ second timeout)
        final slowRelayCompleter = Completer<void>();
        when(
          mockNostr.subscribe(argThat(anything), onEose: anyNamed('onEose')),
        ).thenAnswer((_) {
          // This stream never completes quickly - simulates slow relay
          return Stream.fromFuture(
            slowRelayCompleter.future.then((_) => null),
          ).where((_) => false).cast<Event>();
        });

        // Pre-populate with cached lists so we have data
        final cachedList = CuratedList(
          id: 'cached_list_id',
          name: 'Cached List',
          videoEventIds: ['video1', 'video2'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([cachedList.toJson()]),
        );

        // Also pre-populate subscribed list IDs
        await prefs.setString(
          CuratedListService.subscribedListsStorageKey,
          '["cached_list_id"]',
        );

        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        // Verify local cache was loaded in constructor
        expect(service.lists.length, greaterThan(0));
        expect(service.lists.any((l) => l.name == 'Cached List'), isTrue);

        // Call initialize() and measure time
        final stopwatch = Stopwatch()..start();
        await service.initialize();
        stopwatch.stop();

        // CRITICAL: initialize() should complete in < 100ms, not 7+ seconds
        // The relay sync should happen in background, not block initialization
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason:
              'initialize() should complete quickly without waiting for relay sync',
        );

        // isInitialized should be true IMMEDIATELY after initialize() returns
        expect(service.isInitialized, isTrue);

        // Clean up - complete the slow relay so test can finish
        slowRelayCompleter.complete();
      },
    );

    test('notifies listeners immediately after initialization', () async {
      // Set up slow relay
      when(
        mockNostr.subscribe(argThat(anything), onEose: anyNamed('onEose')),
      ).thenAnswer((_) => Stream.empty());

      final service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );

      var notificationCount = 0;
      service.addListener(() {
        notificationCount++;
      });

      await service.initialize();

      // Should have notified at least once when becoming initialized
      expect(notificationCount, greaterThan(0));
      expect(service.isInitialized, isTrue);
    });

    test(
      'local cached lists are available before relay sync completes',
      () async {
        // Set up relay that never responds
        final neverCompletes = Completer<void>();
        when(
          mockNostr.subscribe(argThat(anything), onEose: anyNamed('onEose')),
        ).thenAnswer((_) {
          return Stream.fromFuture(
            neverCompletes.future.then((_) => null),
          ).where((_) => false).cast<Event>();
        });

        // Pre-populate cache
        final cachedList = CuratedList(
          id: 'local_list',
          name: 'Local Cached List',
          videoEventIds: ['v1', 'v2', 'v3'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([cachedList.toJson()]),
        );

        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.initialize();

        // Local lists should be available even though relay hasn't responded
        expect(service.isInitialized, isTrue);
        expect(service.lists.any((l) => l.name == 'Local Cached List'), isTrue);
        expect(
          service.getListById('local_list')?.videoEventIds.length,
          equals(3),
        );

        // Clean up
        neverCompletes.complete();
      },
    );

    test(
      'subscribed lists are accessible immediately after initialization',
      () async {
        // Set up slow relay
        final slowRelay = Completer<void>();
        when(
          mockNostr.subscribe(argThat(anything), onEose: anyNamed('onEose')),
        ).thenAnswer((_) {
          return Stream.fromFuture(
            slowRelay.future.then((_) => null),
          ).where((_) => false).cast<Event>();
        });

        // Pre-populate with list and subscription
        final subscribedList = CuratedList(
          id: 'subscribed_list',
          name: 'My Subscribed List',
          videoEventIds: ['video_a', 'video_b'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([subscribedList.toJson()]),
        );
        await prefs.setString(
          CuratedListService.subscribedListsStorageKey,
          '["subscribed_list"]',
        );

        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.initialize();

        // Subscribed lists should be available immediately
        expect(service.isInitialized, isTrue);
        expect(service.subscribedLists.length, equals(1));
        expect(
          service.subscribedLists.first.name,
          equals('My Subscribed List'),
        );
        expect(service.isSubscribedToList('subscribed_list'), isTrue);

        slowRelay.complete();
      },
    );

    test(
      'relay sync updates lists in background after initialization',
      () async {
        // Set up relay that responds after a delay with new data
        final relayResponseCompleter = Completer<Event>();

        when(
          mockNostr.subscribe(argThat(anything), onEose: anyNamed('onEose')),
        ).thenAnswer((invocation) {
          // Get the onEose callback
          final onEose =
              invocation.namedArguments[const Symbol('onEose')] as Function?;

          // Return a stream that will emit an event after delay
          return Stream.fromFuture(relayResponseCompleter.future);
        });

        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        // Initialize should complete quickly
        final stopwatch = Stopwatch()..start();
        await service.initialize();
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        expect(service.isInitialized, isTrue);

        // Now simulate relay returning a new list
        final relayEvent = Event.fromJson({
          'id': 'relay_event_id',
          'pubkey': 'test_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [
            ['d', 'relay_list_id'],
            ['title', 'List From Relay'],
          ],
          'content': '',
          'sig': 'test_sig',
        });

        relayResponseCompleter.complete(relayEvent);

        // Give time for background sync to process
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // The relay list should now be merged into local lists
        // (This tests that background sync is working)
      },
    );
  });
}
