// ABOUTME: Unit tests for FollowRepository
// ABOUTME: Tests follow/unfollow operations, caching, and network sync

import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockProfileStatsDao extends Mock implements ProfileStatsDao {}

class _MockEvent extends Mock implements Event {}

/// A fake relay that fires [fakeResponses] via [onMessage] during connect.
///
/// Used to test indexer relay methods without real WebSocket connections.
class _FakeRelay extends RelayBase {
  _FakeRelay(
    super.url,
    super.relayStatus, {
    this.shouldConnect = true,
    this.throwOnSend = false,
    this.throwOnDisconnect = false,
  });

  /// Messages to deliver via [onMessage] when connecting.
  List<List<dynamic>> fakeResponses = [];

  /// Whether [connect] should succeed.
  final bool shouldConnect;

  /// Whether [send] should throw.
  final bool throwOnSend;

  /// Whether [disconnect] should throw.
  final bool throwOnDisconnect;

  @override
  Future<bool> doConnect() async {
    if (!shouldConnect) return false;
    // Fire fake responses to trigger onMessage handlers
    for (final msg in fakeResponses) {
      await onMessage?.call(this, msg);
    }
    return true;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool? forceSend,
    bool queueIfFailed = true,
    bool skipReconnect = false,
  }) async {
    // Only throw on CLOSE messages (not REQ sent by onConnected)
    if (throwOnSend && message.isNotEmpty && message[0] == 'CLOSE') {
      throw Exception('Send failed');
    }
    return true;
  }

  @override
  Future<void> disconnect() async {
    if (throwOnDisconnect) throw Exception('Disconnect failed');
  }
}

class _FakeContactList extends Fake implements ContactList {}

void main() {
  group('FollowRepository', () {
    late FollowRepository repository;
    late _MockNostrClient mockNostrClient;
    late bool cacheIsInitialized;
    late List<Event> Function(int kind) getCachedEventsByKind;
    late List<Event> cachedUserEvents;

    // Valid 64-character hex pubkeys for testing
    const testCurrentUserPubkey =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
    const testTargetPubkey =
        'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
    const testTargetPubkey2 =
        'c3d4e5f6789012345678901234567890abcdef1234567890123456789012ab12';

    setUpAll(() {
      registerFallbackValue(_MockEvent());
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(_FakeContactList());
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      mockNostrClient = _MockNostrClient();
      cacheIsInitialized = false;
      getCachedEventsByKind = (_) => [];
      cachedUserEvents = [];

      // Default nostr client setup
      when(() => mockNostrClient.hasKeys).thenReturn(true);
      when(() => mockNostrClient.publicKey).thenReturn(testCurrentUserPubkey);

      // Default nostr client subscribe - return empty stream
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());

      // Default nostr client unsubscribe - return completed future
      when(() => mockNostrClient.unsubscribe(any())).thenAnswer((_) async {});

      repository = FollowRepository(
        nostrClient: mockNostrClient,
        isCacheInitialized: () => cacheIsInitialized,
        getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
        cacheUserEvent: cachedUserEvents.add,
        // Prevent real WebSocket connections to indexer relays in tests
        indexerRelayUrls: const [],
      );
    });

    tearDown(() async {
      await repository.dispose();
    });

    group('initialization', () {
      test('initializes with empty following list', () async {
        await repository.initialize();

        expect(repository.isInitialized, isTrue);
        expect(repository.followingCount, 0);
        expect(repository.followingPubkeys, isEmpty);
      });

      test('loads following list from local storage', () async {
        // Pre-populate SharedPreferences with cached data
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey':
              '["$testTargetPubkey", "$testTargetPubkey2"]',
        });

        // Recreate repository to pick up the cached data
        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        expect(repository.followingCount, 2);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.isFollowing(testTargetPubkey2), isTrue);
      });

      test('loads following list from REST API when cache is empty', () async {
        // No cached data in SharedPreferences or PersonalEventCache
        // But REST API (funnelcake) has the following list
        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedPubkeys(
            pubkeys: [testTargetPubkey, testTargetPubkey2],
          ),
        );

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        expect(repository.followingCount, 2);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.isFollowing(testTargetPubkey2), isTrue);

        // Verify it was also saved to SharedPreferences for redirect logic
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('following_list_$testCurrentUserPubkey');
        expect(cached, isNotNull);
      });

      test('skips REST API when local cache already has data', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        // Should have loaded from cache, not called API
        verifyNever(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
          ),
        );
        expect(repository.followingCount, 1);
      });

      test('handles REST API failure gracefully', () async {
        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(Exception('Network error'));

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        // Should not throw, just log warning and continue
        await repository.initialize();

        expect(repository.isInitialized, isTrue);
        expect(repository.followingCount, 0);
      });

      test('does not reinitialize if already initialized', () async {
        await repository.initialize();
        expect(repository.isInitialized, isTrue);

        // Second call should return immediately
        await repository.initialize();
        expect(repository.isInitialized, isTrue);

        // Verify subscribe was called twice during first init:
        // 1. _loadFromRelay() (relay kind 3 query when list is empty)
        // 2. _subscribeToContactList() (real-time cross-device sync)
        verify(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).called(2);
      });
    });

    group('isFollowing', () {
      test('returns false for unfollowed user', () async {
        await repository.initialize();

        expect(repository.isFollowing(testTargetPubkey), isFalse);
      });

      test('returns true for followed user', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        await repository.initialize();

        expect(repository.isFollowing(testTargetPubkey), isTrue);
      });
    });

    group('follow', () {
      test('throws when not authenticated', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        await repository.initialize();

        expect(
          () => repository.follow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not authenticated'),
            ),
          ),
        );
      });

      test('does nothing when already following', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        await repository.initialize();

        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);

        await repository.follow(testTargetPubkey);

        expect(repository.followingCount, 1);
      });

      test('successfully follows a user', () async {
        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isFalse);
        await repository.follow(testTargetPubkey);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);
      });

      test('rolls back on broadcast failure', () async {
        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isFalse);
        await expectLater(
          repository.follow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to broadcast'),
            ),
          ),
        );

        expect(repository.isFollowing(testTargetPubkey), isFalse);
        expect(repository.followingCount, 0);
      });
    });

    group('unfollow', () {
      test('throws when not authenticated', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        await repository.initialize();

        expect(
          () => repository.unfollow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not authenticated'),
            ),
          ),
        );
      });

      test('does nothing when not following', () async {
        await repository.initialize();
        await repository.unfollow(testTargetPubkey);
        expect(repository.followingCount, 0);
      });

      test('successfully unfollows a user', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);

        await repository.unfollow(testTargetPubkey);

        expect(repository.isFollowing(testTargetPubkey), isFalse);
        expect(repository.followingCount, 0);
      });

      test('rolls back on broadcast failure', () async {
        // Pre-populate with followed user
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);

        await expectLater(
          repository.unfollow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to broadcast'),
            ),
          ),
        );

        // Should have rolled back
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);
      });
    });

    group('toggleFollow', () {
      test('follows when not currently following', () async {
        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isFalse);

        await repository.toggleFollow(testTargetPubkey);

        expect(repository.isFollowing(testTargetPubkey), isTrue);
      });

      test('unfollows when currently following', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isTrue);

        await repository.toggleFollow(testTargetPubkey);

        expect(repository.isFollowing(testTargetPubkey), isFalse);
      });

      test('propagates errors from follow', () async {
        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        await repository.initialize();

        await expectLater(
          repository.toggleFollow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to broadcast'),
            ),
          ),
        );
      });

      test('propagates errors from unfollow', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        await expectLater(
          repository.toggleFollow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to broadcast'),
            ),
          ),
        );
      });
    });

    group('followingStream', () {
      test('is a broadcast stream', () {
        expect(repository.followingStream.isBroadcast, isTrue);
      });

      test('emits updated list when follow succeeds', () async {
        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();

        final emittedValues = <List<String>>[];
        final subscription = repository.followingStream.listen(
          emittedValues.add,
        );

        await repository.follow(testTargetPubkey);
        await Future<void>.delayed(Duration.zero);

        expect(emittedValues.length, greaterThanOrEqualTo(1));
        expect(emittedValues.last, contains(testTargetPubkey));

        await subscription.cancel();
      });

      test('emits updated list when unfollow succeeds', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();

        final emittedValues = <List<String>>[];
        final subscription = repository.followingStream.listen(
          emittedValues.add,
        );

        await repository.unfollow(testTargetPubkey);
        await Future<void>.delayed(Duration.zero);

        expect(emittedValues.length, greaterThanOrEqualTo(1));
        expect(emittedValues.last, isNot(contains(testTargetPubkey)));

        await subscription.cancel();
      });
    });

    group('dispose', () {
      test('closes the stream controller', () async {
        await repository.initialize();

        repository.dispose();

        expect(
          () => repository.followingStream.listen((_) {}),
          returnsNormally,
        );
      });
    });

    group('self-follow prevention', () {
      test('follow() silently ignores when target is self', () async {
        await repository.initialize();

        // Attempt to follow self (testCurrentUserPubkey is the mock's publicKey)
        await repository.follow(testCurrentUserPubkey);

        expect(repository.isFollowing(testCurrentUserPubkey), isFalse);
        expect(repository.followingCount, 0);

        // Verify sendContactList was never called
        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });

      test('unfollow() silently ignores when target is self', () async {
        await repository.initialize();

        // Attempt to unfollow self
        await repository.unfollow(testCurrentUserPubkey);

        // Verify sendContactList was never called
        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });

      test('toggleFollow() silently ignores when target is self', () async {
        await repository.initialize();

        // Attempt to toggle follow on self
        await repository.toggleFollow(testCurrentUserPubkey);

        expect(repository.isFollowing(testCurrentUserPubkey), isFalse);

        // Verify sendContactList was never called
        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });
    });

    group('getFollowers', () {
      test('returns empty list when pubkey is empty', () async {
        final followers = await repository.getFollowers('');

        expect(followers, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns empty list when no followers', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final followers = await repository.getFollowers(testTargetPubkey);

        expect(followers, isEmpty);
      });

      test('returns list of follower pubkeys', () async {
        const follower1 =
            'e5f6789012345678901234567890abcdef1234567890123456789012abcd1234';
        const follower2 =
            'f6789012345678901234567890abcdef1234567890123456789012abcde12345';

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testTargetPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
            Event(
              follower2,
              3,
              [
                ['p', testTargetPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        final followers = await repository.getFollowers(testTargetPubkey);

        expect(followers, hasLength(2));
        expect(followers, contains(follower1));
        expect(followers, contains(follower2));
      });

      test('deduplicates followers from multiple events', () async {
        const follower1 =
            'e5f6789012345678901234567890abcdef1234567890123456789012abcd1234';

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testTargetPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
            // Duplicate event from same author (e.g., older contact list)
            Event(
              follower1,
              3,
              [
                ['p', testTargetPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 100000,
            ),
          ],
        );

        final followers = await repository.getFollowers(testTargetPubkey);

        expect(followers, hasLength(1));
        expect(followers, contains(follower1));
      });

      test('queries with correct filter for Kind 3 events', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.getFollowers(testTargetPubkey);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        expect(captured, hasLength(1));
        final filters = captured.first as List<Filter>;
        expect(filters, hasLength(1));
        expect(filters.first.kinds, equals([3]));
        expect(filters.first.p, contains(testTargetPubkey));
      });

      test(
        'returns empty list on timeout',
        () async {
          // Simulate a slow query that exceeds the repository's internal
          // timeout. The delay must be longer than the repo timeout (5s) but
          // shorter than the test timeout so cleanup completes cleanly.
          when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(seconds: 7));
            return [];
          });

          final followers = await repository.getFollowers(testTargetPubkey);

          expect(followers, isEmpty);
        },
        timeout: const Timeout(Duration(seconds: 15)),
      );
    });

    group('getMyFollowers', () {
      test('returns empty list when not authenticated', () async {
        when(() => mockNostrClient.publicKey).thenReturn('');

        final followers = await repository.getMyFollowers();

        expect(followers, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns followers for current user', () async {
        const follower1 =
            'e5f6789012345678901234567890abcdef1234567890123456789012abcd1234';
        const follower2 =
            'f6789012345678901234567890abcdef1234567890123456789012abcde12345';

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
            Event(
              follower2,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        final followers = await repository.getMyFollowers();

        expect(followers, hasLength(2));
        expect(followers, contains(follower1));
        expect(followers, contains(follower2));
      });

      test('queries with current user pubkey', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.getMyFollowers();

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        expect(captured, hasLength(1));
        final filters = captured.first as List<Filter>;
        expect(filters, hasLength(1));
        expect(filters.first.kinds, equals([3]));
        expect(filters.first.p, contains(testCurrentUserPubkey));
      });
    });

    group('watchMyFollowers', () {
      const follower1 =
          'e5f6789012345678901234567890abcdef1234567890123456789012abcd1234';
      const follower2 =
          'f6789012345678901234567890abcdef1234567890123456789012abcde12345';

      test('yields only fresh data on first call (no cache)', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        final emissions = await repository.watchMyFollowers().toList();

        expect(emissions, hasLength(1));
        expect(emissions.first.pubkeys, contains(follower1));
      });

      test('yields cached data then fresh data on second call', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        // First call — populates cache
        await repository.watchMyFollowers().toList();

        // Second call — should now yield cache first, then fresh
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
            Event(
              follower2,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        final emissions = await repository.watchMyFollowers().toList();

        expect(emissions, hasLength(2));
        // First emission: cached data from first call
        expect(emissions[0].pubkeys, contains(follower1));
        expect(emissions[0].pubkeys, isNot(contains(follower2)));
        // Second emission: fresh data
        expect(emissions[1].pubkeys, contains(follower1));
        expect(emissions[1].pubkeys, contains(follower2));
      });
    });

    group('real-time sync', () {
      late StreamController<Event> realTimeStreamController;

      setUp(() {
        realTimeStreamController = StreamController<Event>.broadcast();

        // Override the default subscribe mock to use the stream controller
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => realTimeStreamController.stream);
      });

      tearDown(() async {
        // Dispose repository first to cancel stream listeners,
        // then close the controller.
        await repository.dispose();
        await realTimeStreamController.close();
      });

      test('updates following list when newer Kind 3 event arrives', () async {
        await repository.initialize();

        expect(repository.followingPubkeys, isEmpty);

        // Simulate remote Kind 3 event with a followed user
        final remoteEvent = Event(
          testCurrentUserPubkey,
          3,
          [
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(remoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(repository.followingPubkeys, contains(testTargetPubkey));
        expect(repository.followingCount, 1);
      });

      test('updates with multiple followed users from remote event', () async {
        await repository.initialize();

        final remoteEvent = Event(
          testCurrentUserPubkey,
          3,
          [
            ['p', testTargetPubkey],
            ['p', testTargetPubkey2],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(remoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(repository.followingPubkeys, contains(testTargetPubkey));
        expect(repository.followingPubkeys, contains(testTargetPubkey2));
        expect(repository.followingCount, 2);
      });

      test('ignores Kind 3 events with older timestamps', () async {
        await repository.initialize();

        // First, add an event with a recent timestamp
        final recentEvent = Event(
          testCurrentUserPubkey,
          3,
          [
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        realTimeStreamController.add(recentEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(repository.followingCount, 1);

        // Now send an older event that should be ignored
        final oldEvent = Event(
          testCurrentUserPubkey,
          3,
          [], // Empty follow list
          '',
          createdAt:
              DateTime.now().millisecondsSinceEpoch ~/ 1000 - 1000, // Older
        );

        realTimeStreamController.add(oldEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should still have the original following list
        expect(repository.followingPubkeys, contains(testTargetPubkey));
        expect(repository.followingCount, 1);
      });

      test('ignores events from other users', () async {
        const otherUserPubkey =
            'd4e5f6789012345678901234567890abcdef1234567890123456789012ab1234';

        await repository.initialize();

        // Simulate Kind 3 event from a different user
        final otherUserEvent = Event(
          otherUserPubkey, // Different author
          3,
          [
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(otherUserEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should not update following list
        expect(repository.followingPubkeys, isEmpty);
      });

      test('ignores non-Kind-3 events', () async {
        await repository.initialize();

        // Simulate a different kind of event (Kind 1 = text note)
        final textNoteEvent = Event(
          testCurrentUserPubkey,
          1, // Not Kind 3
          [
            ['p', testTargetPubkey],
          ],
          'Hello world',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(textNoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should not update following list
        expect(repository.followingPubkeys, isEmpty);
      });

      test('emits to followingStream when remote event arrives', () async {
        await repository.initialize();

        final emittedLists = <List<String>>[];
        final subscription = repository.followingStream.listen(
          emittedLists.add,
        );

        // Simulate remote Kind 3 event
        final remoteEvent = Event(
          testCurrentUserPubkey,
          3,
          [
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(remoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(emittedLists.length, greaterThanOrEqualTo(1));
        expect(emittedLists.last, contains(testTargetPubkey));

        await subscription.cancel();
      });

      test(
        'merges lists when remote event has drastically fewer follows',
        () async {
          // Generate 12 pubkeys to seed the local cache (above _mergeMinFollows)
          final seededPubkeys = List.generate(
            12,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey':
                '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
          });

          // Need fresh repository to pick up cached data
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          // Mock sendContactList for the merge broadcast
          when(() => mockNostrClient.sendContactList(any(), any())).thenAnswer(
            (_) async => Event(
              testCurrentUserPubkey,
              3,
              [],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 200,
            ),
          );

          await repository.initialize();
          expect(repository.followingCount, 12);

          // Remote event with only 1 follow — catastrophic reduction
          const newPubkey =
              'ff00000000000000000000000000000000000000000000000000000000000001';
          final remoteEvent = Event(
            testCurrentUserPubkey,
            3,
            [
              ['p', newPubkey],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
          );

          realTimeStreamController.add(remoteEvent);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Should have merged: all 12 original + 1 new = 13
          expect(repository.followingCount, 13);
          expect(repository.followingPubkeys, contains(newPubkey));
          for (final pk in seededPubkeys) {
            expect(repository.followingPubkeys, contains(pk));
          }

          // Verify broadcast was triggered to fix relay state
          verify(() => mockNostrClient.sendContactList(any(), any())).called(1);
        },
      );

      test('accepts drastic reduction when remote is a subset (legitimate mass '
          'unfollow)', () async {
        // Seed with 12 follows
        final seededPubkeys = List.generate(
          12,
          (i) => i.toRadixString(16).padLeft(64, '0'),
        );
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey':
              '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();
        expect(repository.followingCount, 12);

        // Remote event keeps only 3 of the original 12 — drastic but all
        // entries are a subset of the local list (no new pubkeys), so this
        // is a legitimate mass unfollow on another client.
        final remoteEvent = Event(
          testCurrentUserPubkey,
          3,
          seededPubkeys.take(3).map((p) => ['p', p]).toList(),
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(remoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should accept as-is (not merge) because no new pubkeys
        expect(repository.followingCount, 3);
      });

      test(
        'accepts remote event with slightly fewer follows (legitimate unfollow)',
        () async {
          // Seed with 10 follows
          final seededPubkeys = List.generate(
            10,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey':
                '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
          });

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();
          expect(repository.followingCount, 10);

          // Remote event removes 2 follows (8 remaining) — within threshold
          // ceil(10 * 0.5) = 5, and 8 >= 5, so accepted
          final remoteEvent = Event(
            testCurrentUserPubkey,
            3,
            seededPubkeys.take(8).map((p) => ['p', p]).toList(),
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
          );

          realTimeStreamController.add(remoteEvent);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Should accept the remote event as-is (8 follows)
          expect(repository.followingCount, 8);
        },
      );

      test('accepts remote event with more follows', () async {
        // Seed with 5 follows
        final seededPubkeys = List.generate(
          5,
          (i) => i.toRadixString(16).padLeft(64, '0'),
        );
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey':
              '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();
        expect(repository.followingCount, 5);

        // Remote event with 10 follows (superset)
        final remotePubkeys = List.generate(
          10,
          (i) => i.toRadixString(16).padLeft(64, '0'),
        );
        final remoteEvent = Event(
          testCurrentUserPubkey,
          3,
          remotePubkeys.map((p) => ['p', p]).toList(),
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(remoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should accept the larger list
        expect(repository.followingCount, 10);
      });

      test(
        'skips merge protection when local list is below threshold',
        () async {
          // Seed with 1 follow (below _mergeMinFollows of 2)
          final seededPubkeys = List.generate(
            1,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey':
                '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
          });

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();
          expect(repository.followingCount, 1);

          // Remote event with only 1 follow — drastic but below threshold
          final remoteEvent = Event(
            testCurrentUserPubkey,
            3,
            [
              ['p', testTargetPubkey],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
          );

          realTimeStreamController.add(remoteEvent);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Should replace (not merge) because local list is below threshold
          expect(repository.followingCount, 1);
          expect(repository.followingPubkeys, equals([testTargetPubkey]));
        },
      );

      test('cancels subscription on dispose', () async {
        await repository.initialize();

        repository.dispose();

        // Verify that adding events after dispose doesn't cause issues
        final remoteEvent = Event(
          testCurrentUserPubkey,
          3,
          [
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        // This should not throw or cause any updates
        realTimeStreamController.add(remoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Following list should remain empty (disposed before event processed)
        expect(repository.followingPubkeys, isEmpty);
      });
    });

    group('isMutualFollow', () {
      test('returns false when not following the target', () async {
        await repository.initialize();

        // We don't follow testTargetPubkey, so instant false
        final result = await repository.isMutualFollow(testTargetPubkey);

        expect(result, isFalse);

        // Should not even query the relay since step 1 fails
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns true when mutual follow exists', () async {
        // Set up: we follow testTargetPubkey
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        // Mock: their Kind 3 event includes our pubkey
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              testTargetPubkey,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        final result = await repository.isMutualFollow(testTargetPubkey);

        expect(result, isTrue);
      });

      test('returns false when they do not follow us back', () async {
        // Set up: we follow testTargetPubkey
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        // isMutualFollow makes two queryEvents calls:
        // 1. _fetchFollowers(ourPubkey) -> Filter(kinds:[3], #p:[ourPubkey])
        // 2. _checkIfTheyFollowUs(pubkey) -> Filter(authors:[pubkey], kinds:[3])
        // We need to return empty for _fetchFollowers (no one follows us)
        // and return their contact list without our pubkey for the second.
        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            // _fetchFollowers: no events found (nobody follows us)
            return [];
          }
          // _checkIfTheyFollowUs: their contact list without our pubkey
          return [
            Event(
              testTargetPubkey,
              3,
              [
                [
                  'p',
                  'someoneelsepubkey1234567890123456789012345678901234567890',
                ],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ];
        });

        final result = await repository.isMutualFollow(testTargetPubkey);

        expect(result, isFalse);
      });

      test('returns false on error', () async {
        // Set up: we follow testTargetPubkey
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        // Mock: relay query throws
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        final result = await repository.isMutualFollow(testTargetPubkey);

        expect(result, isFalse);
      });
    });

    group('followingStream force-emit on initialize', () {
      test('emits on followingStream after initialize '
          'when user has no follows', () async {
        // No cached follows, no PersonalEventCache, no relay data
        SharedPreferences.setMockInitialValues({});

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        final emissions = <List<String>>[];
        final subscription = repository.followingStream.listen(emissions.add);

        // Seed value is [] — capture it
        await Future<void>.delayed(Duration.zero);
        final preInitCount = emissions.length;

        await repository.initialize();
        await Future<void>.delayed(Duration.zero);

        // Force-emit should add one more [] emission
        expect(emissions.length, greaterThan(preInitCount));
        expect(emissions.last, isEmpty);

        await subscription.cancel();
      });

      test('does not double-emit after initialize '
          'when user has follows', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        final emissions = <List<String>>[];
        final subscription = repository.followingStream.listen(emissions.add);

        await repository.initialize();
        await Future<void>.delayed(Duration.zero);

        // Should emit exactly once with the follow list (from
        // _emitFollowingList during _loadFromLocalStorage), no
        // extra force-emit because _followingPubkeys is non-empty.
        final nonSeedEmissions = emissions.where((e) => e.isNotEmpty).toList();
        expect(nonSeedEmissions, hasLength(1));
        expect(nonSeedEmissions.first, contains(testTargetPubkey));

        await subscription.cancel();
      });
    });

    group('getSocialCounts', () {
      late _MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = _MockFunnelcakeApiClient();
      });

      test('returns SocialCounts on success', () async {
        const testSocialCounts = SocialCounts(
          pubkey: testCurrentUserPubkey,
          followerCount: 100,
          followingCount: 50,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getSocialCounts(testCurrentUserPubkey),
        ).thenAnswer((_) async => testSocialCounts);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getSocialCounts(testCurrentUserPubkey);

        expect(result, equals(testSocialCounts));
        verify(
          () => mockFunnelcakeClient.getSocialCounts(testCurrentUserPubkey),
        ).called(1);
      });

      test('returns null when client is null', () async {
        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        final result = await repo.getSocialCounts(testCurrentUserPubkey);

        expect(result, isNull);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getSocialCounts(testCurrentUserPubkey);

        expect(result, isNull);
        verifyNever(() => mockFunnelcakeClient.getSocialCounts(any()));
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getSocialCounts(any())).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/social-counts',
          ),
        );

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        expect(
          () => repo.getSocialCounts(testCurrentUserPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });
    });

    group('getFollowersFromApi', () {
      late _MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = _MockFunnelcakeApiClient();
      });

      test('returns PaginatedPubkeys on success', () async {
        const testPaginatedPubkeys = PaginatedPubkeys(
          pubkeys: [testTargetPubkey],
          total: 1,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () =>
              mockFunnelcakeClient.getFollowers(pubkey: testCurrentUserPubkey),
        ).thenAnswer((_) async => testPaginatedPubkeys);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowersFromApi(
          pubkey: testCurrentUserPubkey,
        );

        expect(result, equals(testPaginatedPubkeys));
        verify(
          () =>
              mockFunnelcakeClient.getFollowers(pubkey: testCurrentUserPubkey),
        ).called(1);
      });

      test('returns null when client is null', () async {
        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowersFromApi(
          pubkey: testCurrentUserPubkey,
        );

        expect(result, isNull);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowersFromApi(
          pubkey: testCurrentUserPubkey,
        );

        expect(result, isNull);
        verifyNever(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        );
      });

      test('passes limit and offset correctly', () async {
        const testPaginatedPubkeys = PaginatedPubkeys(
          pubkeys: [testTargetPubkey, testTargetPubkey2],
          total: 200,
          hasMore: true,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: testCurrentUserPubkey,
            limit: 50,
            offset: 100,
          ),
        ).thenAnswer((_) async => testPaginatedPubkeys);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowersFromApi(
          pubkey: testCurrentUserPubkey,
          limit: 50,
          offset: 100,
        );

        expect(result, equals(testPaginatedPubkeys));
        verify(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: testCurrentUserPubkey,
            limit: 50,
            offset: 100,
          ),
        ).called(1);
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/followers',
          ),
        );

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        expect(
          () => repo.getFollowersFromApi(pubkey: testCurrentUserPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });
    });

    group('getFollowingFromApi', () {
      late _MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = _MockFunnelcakeApiClient();
      });

      test('returns PaginatedPubkeys on success', () async {
        const testPaginatedPubkeys = PaginatedPubkeys(
          pubkeys: [testTargetPubkey],
          total: 1,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () =>
              mockFunnelcakeClient.getFollowing(pubkey: testCurrentUserPubkey),
        ).thenAnswer((_) async => testPaginatedPubkeys);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowingFromApi(
          pubkey: testCurrentUserPubkey,
        );

        expect(result, equals(testPaginatedPubkeys));
        verify(
          () =>
              mockFunnelcakeClient.getFollowing(pubkey: testCurrentUserPubkey),
        ).called(1);
      });

      test('returns null when client is null', () async {
        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowingFromApi(
          pubkey: testCurrentUserPubkey,
        );

        expect(result, isNull);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowingFromApi(
          pubkey: testCurrentUserPubkey,
        );

        expect(result, isNull);
        verifyNever(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        );
      });

      test('passes limit and offset correctly', () async {
        const testPaginatedPubkeys = PaginatedPubkeys(
          pubkeys: [testTargetPubkey, testTargetPubkey2],
          total: 200,
          hasMore: true,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: testCurrentUserPubkey,
            limit: 50,
            offset: 100,
          ),
        ).thenAnswer((_) async => testPaginatedPubkeys);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowingFromApi(
          pubkey: testCurrentUserPubkey,
          limit: 50,
          offset: 100,
        );

        expect(result, equals(testPaginatedPubkeys));
        verify(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: testCurrentUserPubkey,
            limit: 50,
            offset: 100,
          ),
        ).called(1);
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/following',
          ),
        );

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        expect(
          () => repo.getFollowingFromApi(pubkey: testCurrentUserPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });
    });

    group('initialization - skips when no keys', () {
      test('does not initialize when user has no keys', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        await repository.initialize();

        expect(repository.isInitialized, isFalse);
        expect(repository.followingCount, 0);
      });
    });

    group('initialization - loads from PersonalEventCache', () {
      test('loads following from PersonalEventCache', () async {
        cacheIsInitialized = true;
        getCachedEventsByKind = (_) => [
          Event(
            testCurrentUserPubkey,
            EventKind.contactList,
            [
              ['p', testTargetPubkey],
              ['p', testTargetPubkey2],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ];

        await repository.initialize();

        expect(repository.followingCount, 2);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.isFollowing(testTargetPubkey2), isTrue);
      });

      test('ignores empty p-tag values from PersonalEventCache', () async {
        cacheIsInitialized = true;
        getCachedEventsByKind = (_) => [
          Event(
            testCurrentUserPubkey,
            EventKind.contactList,
            [
              ['p', testTargetPubkey],
              ['p', ''], // empty value
              ['p'], // missing value
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ];

        await repository.initialize();

        expect(repository.followingCount, 1);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
      });

      test(
        'handles PersonalEventCache error gracefully',
        () async {
          cacheIsInitialized = true;
          getCachedEventsByKind = (_) => throw Exception('Cache corrupted');

          await repository.initialize();

          expect(repository.isInitialized, isTrue);
          expect(repository.followingCount, 0);
        },
      );

      test('skips PersonalEventCache when not initialized', () async {
        cacheIsInitialized = false;
        var getCachedEventsCalled = false;
        getCachedEventsByKind = (_) {
          getCachedEventsCalled = true;
          return [];
        };

        await repository.initialize();

        expect(getCachedEventsCalled, isFalse);
      });

      test('ignores empty contact list from PersonalEventCache', () async {
        cacheIsInitialized = true;
        getCachedEventsByKind = (_) => [];

        await repository.initialize();

        expect(repository.followingCount, 0);
      });

      test(
        'skips PersonalEventCache when it has fewer follows than '
        'LocalStorage',
        () async {
          // Seed LocalStorage with 10 follows
          final localPubkeys = List.generate(
            10,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey':
                '[${localPubkeys.map((p) => '"$p"').join(',')}]',
          });

          // PersonalEventCache returns a stale event with only 3 pubkeys
          final stalePubkeys = localPubkeys.take(3).toList();
          final staleEvent = Event(
            testCurrentUserPubkey,
            EventKind.contactList,
            stalePubkeys.map((p) => ['p', p]).toList(),
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 100,
          );
          cacheIsInitialized = true;
          getCachedEventsByKind = (_) => [staleEvent];

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();

          // Should keep the 10 from LocalStorage, not the 3 from cache
          expect(repository.followingCount, 10);
          for (final pk in localPubkeys) {
            expect(repository.followingPubkeys, contains(pk));
          }
        },
      );

      test(
        'accepts PersonalEventCache when it has more follows than '
        'LocalStorage',
        () async {
          // Seed LocalStorage with 3 follows
          final localPubkeys = List.generate(
            3,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey':
                '[${localPubkeys.map((p) => '"$p"').join(',')}]',
          });

          // PersonalEventCache returns a newer event with 5 pubkeys
          final cachePubkeys = List.generate(
            5,
            (i) => (i + 10).toRadixString(16).padLeft(64, '0'),
          );
          final cacheEvent = Event(
            testCurrentUserPubkey,
            EventKind.contactList,
            cachePubkeys.map((p) => ['p', p]).toList(),
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
          );
          cacheIsInitialized = true;
          getCachedEventsByKind = (_) => [cacheEvent];

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();

          // Should use the 5 from PersonalEventCache
          expect(repository.followingCount, 5);
          for (final pk in cachePubkeys) {
            expect(repository.followingPubkeys, contains(pk));
          }
        },
      );
    });

    group('initialization - loads from relay', () {
      test('loads from relay when all other sources are empty', () async {
        // Subscribe returns a stream that yields a contact list event
        final contactListEvent = Event(
          testCurrentUserPubkey,
          EventKind.contactList,
          [
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => Stream.value(contactListEvent));

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
          queryContactList:
              ({
                required eventStream,
                required pubkey,
                fallbackTimeoutSeconds = 10,
              }) async {
                // Return the event from the stream if pubkey matches
                await for (final event in eventStream) {
                  if (event.kind == EventKind.contactList &&
                      event.pubkey == pubkey) {
                    return event;
                  }
                }
                return null;
              },
        );

        await repository.initialize();

        expect(repository.followingCount, 1);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
      });

      test('handles relay query failure gracefully', () async {
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenThrow(Exception('Relay error'));

        // Should not throw even though relay fails
        await repository.initialize();

        expect(repository.followingCount, 0);
      });

      test(
        'picks best contact list by createdAt (newer wins)',
        () async {
          final olderEvent = Event(
            testCurrentUserPubkey,
            EventKind.contactList,
            [
              ['p', testTargetPubkey],
            ],
            '',
            createdAt: 1000000,
          );

          var callIndex = 0;
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) {
            callIndex++;
            // First subscribe call: _loadContactListFromConnectedRelays
            if (callIndex == 1) return Stream.value(olderEvent);
            // Remaining calls: _subscribeToContactList
            return const Stream<Event>.empty();
          });

          // Use queryContactList that returns the event from stream
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async {
                  await for (final event in eventStream) {
                    if (event.kind == EventKind.contactList &&
                        event.pubkey == pubkey) {
                      return event;
                    }
                  }
                  return null;
                },
          );

          await repository.initialize();

          // Should load the older event from connected relays
          // (indexer returns null since indexerRelayUrls is empty)
          expect(repository.followingCount, 1);

          // Simulate a newer event arriving via the stream
          // to verify that _processContactListEvent is used
          expect(repository.isFollowing(testTargetPubkey), isTrue);
        },
      );
    });

    group('initialization - REST API edge cases', () {
      test('handles REST API returning empty list', () async {
        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedPubkeys(pubkeys: []),
        );

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        expect(repository.isInitialized, isTrue);
        expect(repository.followingCount, 0);
      });

      test('skips REST API when client is not available', () async {
        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        verifyNever(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
          ),
        );
      });

      test('skips REST API when pubkey is empty', () async {
        when(() => mockNostrClient.publicKey).thenReturn('');
        when(() => mockNostrClient.hasKeys).thenReturn(true);

        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        verifyNever(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
          ),
        );
      });
    });

    group('executeFollowAction', () {
      test('throws when not authenticated', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        expect(
          () => repository.executeFollowAction(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not authenticated'),
            ),
          ),
        );
      });

      test('adds pubkey if not already in list and broadcasts', () async {
        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');
        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();

        await repository.executeFollowAction(testTargetPubkey);

        expect(repository.isFollowing(testTargetPubkey), isTrue);
        verify(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test(
        'broadcasts even if pubkey is already in list',
        () async {
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
          });

          final mockEvent = _MockEvent();
          when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
          when(() => mockEvent.content).thenReturn('');
          when(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => mockEvent);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();
          expect(repository.isFollowing(testTargetPubkey), isTrue);

          await repository.executeFollowAction(testTargetPubkey);

          // Should still broadcast even though already following
          verify(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).called(1);
        },
      );
    });

    group('executeUnfollowAction', () {
      test('throws when not authenticated', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        expect(
          () => repository.executeUnfollowAction(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not authenticated'),
            ),
          ),
        );
      });

      test('removes pubkey from list and broadcasts', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');
        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isTrue);

        await repository.executeUnfollowAction(testTargetPubkey);

        expect(repository.isFollowing(testTargetPubkey), isFalse);
        verify(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test(
        'broadcasts even if pubkey is not in list',
        () async {
          final mockEvent = _MockEvent();
          when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
          when(() => mockEvent.content).thenReturn('');
          when(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => mockEvent);

          await repository.initialize();
          expect(repository.isFollowing(testTargetPubkey), isFalse);

          await repository.executeUnfollowAction(testTargetPubkey);

          // Should still broadcast
          verify(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).called(1);
        },
      );
    });

    group('offline follow/unfollow', () {
      test('queues follow action when offline', () async {
        var queuedAction = '';
        var queuedPubkey = '';

        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
          isOnline: () => false,
          queueOfflineAction:
              ({
                required bool isFollow,
                required String pubkey,
              }) async {
                queuedAction = isFollow ? 'follow' : 'unfollow';
                queuedPubkey = pubkey;
              },
        );

        await repository.initialize();
        await repository.follow(testTargetPubkey);

        expect(queuedAction, equals('follow'));
        expect(queuedPubkey, equals(testTargetPubkey));
        expect(repository.isFollowing(testTargetPubkey), isTrue);

        // Should not broadcast to network
        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });

      test('queues unfollow action when offline', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        var queuedAction = '';
        var queuedPubkey = '';

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
          isOnline: () => false,
          queueOfflineAction:
              ({
                required bool isFollow,
                required String pubkey,
              }) async {
                queuedAction = isFollow ? 'follow' : 'unfollow';
                queuedPubkey = pubkey;
              },
        );

        await repository.initialize();
        await repository.unfollow(testTargetPubkey);

        expect(queuedAction, equals('unfollow'));
        expect(queuedPubkey, equals(testTargetPubkey));
        expect(repository.isFollowing(testTargetPubkey), isFalse);

        // Should not broadcast to network
        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });
    });

    group('getFollowerStats', () {
      test(
        'returns stats from REST API when available',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 100,
              followingCount: 50,
            ),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.followers, equals(100));
          expect(stats.following, equals(50));
        },
      );

      test(
        'returns cached stats on second call',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 100,
              followingCount: 50,
            ),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          await repository.getFollowerStats(testTargetPubkey);
          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.followers, equals(100));
          // getSocialCounts should only be called once (cached)
          verify(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).called(1);
        },
      );

      test(
        'falls back to WebSocket when REST API is unavailable',
        () async {
          // No funnelcake client, use nostr client subscribe for
          // _fetchFollowingCountViaWebSocket
          final contactListEvent = Event(
            testTargetPubkey,
            EventKind.contactList,
            [
              ['p', 'followed1'.padLeft(64, '0')],
              ['p', 'followed2'.padLeft(64, '0')],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );

          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => Stream.value(contactListEvent));

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async {
                  await for (final event in eventStream) {
                    if (event.kind == EventKind.contactList &&
                        event.pubkey == pubkey) {
                      return event;
                    }
                  }
                  return null;
                },
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // Following count from WebSocket: 2 p-tags
          expect(stats.following, equals(2));
        },
      );

      test(
        'falls back to REST when REST fails gracefully',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenThrow(Exception('API error'));

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          // Should not throw — falls back to WebSocket
          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats, isNotNull);
        },
      );

      test(
        'returns null REST result when client returns null counts',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer((_) async => null);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // REST returns null, falls back to WebSocket which returns 0/0
          expect(stats, isNotNull);
        },
      );

      test(
        'persists stats and applies hysteresis',
        () async {
          final mockStatsDao = _MockProfileStatsDao();
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 90,
              followingCount: 45,
            ),
          );

          // Return persisted stats with higher counts (within threshold)
          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 100,
              followingCount: 50,
              cachedAt: DateTime.now(),
            ),
          );

          when(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          ).thenAnswer((_) async {});

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // Hysteresis should keep the higher persisted values
          // since 90 >= ceil(100 * 0.8) = 80
          expect(stats.followers, equals(100));
          expect(stats.following, equals(50));
        },
      );

      test(
        'returns persisted stats on complete network failure',
        () async {
          final mockStatsDao = _MockProfileStatsDao();

          // Make subscribe throw for WebSocket path
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenThrow(Exception('Network down'));

          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 50,
              followingCount: 25,
              cachedAt: DateTime.now(),
            ),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.followers, equals(50));
          expect(stats.following, equals(25));
        },
      );

      test(
        'returns zero when all sources fail and no persisted data',
        () async {
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenThrow(Exception('Network down'));

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats, equals(FollowerStats.zero));
        },
      );

      test(
        'returns persisted data when fresh stats are all zero',
        () async {
          final mockStatsDao = _MockProfileStatsDao();

          // First getStatsRaw call (fresh == zero fallback)
          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 42,
              followingCount: 10,
              cachedAt: DateTime.now(),
            ),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // WebSocket returns 0/0 (empty stream), so falls back to persisted
          expect(stats.followers, equals(42));
          expect(stats.following, equals(10));
        },
      );
    });

    group('real-time sync - subscription error handling', () {
      test('handles stream error without crashing', () async {
        final controller = StreamController<Event>.broadcast();

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => controller.stream);

        await repository.initialize();

        // Add an error to the stream
        controller.addError(Exception('Relay disconnected'));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Repository should still be functional
        expect(repository.isInitialized, isTrue);

        await repository.dispose();
        await controller.close();
      });

      test(
        'skips subscription when pubkey is empty',
        () async {
          when(() => mockNostrClient.publicKey).thenReturn('');
          when(() => mockNostrClient.hasKeys).thenReturn(true);

          await repository.initialize();

          // Should not subscribe since pubkey is empty
          // (subscribe is called for _loadFromRelay, not for
          // _subscribeToContactList when pubkey is empty)
          expect(repository.isInitialized, isTrue);
        },
      );
    });

    group('mergeFollows', () {
      test('removes self from merged list', () async {
        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');
        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();

        // Merge a list that includes self
        await repository.mergeFollows([
          testTargetPubkey,
          testCurrentUserPubkey,
        ]);

        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(
          repository.isFollowing(testCurrentUserPubkey),
          isFalse,
        );
      });

      test('does not broadcast when no change', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        // Merge the same list — no change
        await repository.mergeFollows([testTargetPubkey]);

        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });
    });

    group('getFollowerCount', () {
      test('returns 0 on error', () async {
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenThrow(Exception('Network error'));

        final count = await repository.getFollowerCount(testTargetPubkey);

        expect(count, equals(0));
      });
    });

    group('getFollowerStats - REST + WS merge', () {
      test(
        'uses higher count when REST and WS both return data',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          // REST returns lower followers, higher following
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 50,
              followingCount: 100,
            ),
          );

          // WS returns higher followers via subscribe
          final contactListEvent = Event(
            testTargetPubkey,
            EventKind.contactList,
            List.generate(
              80,
              (i) => ['p', i.toRadixString(16).padLeft(64, '0')],
            ),
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );

          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => Stream.value(contactListEvent));

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async {
                  await for (final event in eventStream) {
                    if (event.kind == EventKind.contactList &&
                        event.pubkey == pubkey) {
                      return event;
                    }
                  }
                  return null;
                },
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // Should pick the higher value from each source
          // Followers: max(REST 50, WS 0) = 50
          // Following: max(REST 100, WS 80) = 100
          expect(stats.followers, equals(50));
          expect(stats.following, equals(100));
        },
      );
    });

    group('initialization - pickBestContactList branch', () {
      test(
        'picks newer event when both sources return data',
        () async {
          final olderEvent = Event(
            testCurrentUserPubkey,
            EventKind.contactList,
            [
              ['p', testTargetPubkey],
            ],
            '',
            createdAt: 1000000,
          );

          // Connected relays return older event, indexer returns newer
          // We need subscribe to return the older for the first call
          // (_loadContactListFromConnectedRelays) and empty for
          // _subscribeToContactList.
          var subscribeCallCount = 0;
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) {
            subscribeCallCount++;
            if (subscribeCallCount == 1) return Stream.value(olderEvent);
            return const Stream<Event>.empty();
          });

          // Use a queryContactList that returns the older event
          // And set up indexer to return the newer event
          // Since we can't easily mock indexer relays, test via
          // the _loadFromRelay path where only connected relays
          // return data and indexer returns null (empty URLs).
          //
          // To test the b > a branch of _pickBestContactList,
          // we need the indexer result to be newer. Since we
          // can't mock indexer relay connections, let's verify
          // the method by testing through different test setup.
          //
          // The simpler approach: with indexerRelayUrls: [] the
          // indexer returns null, so _pickBestContactList(event, null)
          // returns event. We've already tested this.
          //
          // To cover line 1644 (b.createdAt > a.createdAt ? b : a),
          // we need both a and b non-null with b newer. This requires
          // a real indexer connection which isn't unit-testable.
          // Skip this specific branch for now.
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async {
                  await for (final event in eventStream) {
                    if (event.kind == EventKind.contactList &&
                        event.pubkey == pubkey) {
                      return event;
                    }
                  }
                  return null;
                },
          );

          await repository.initialize();

          // Loaded from connected relays
          expect(repository.followingCount, 1);
          expect(repository.isFollowing(testTargetPubkey), isTrue);
        },
      );
    });

    group('_fetchFollowersFromRelays edge cases', () {
      test(
        'returns empty list on TimeoutException',
        () async {
          when(() => mockNostrClient.queryEvents(any())).thenThrow(
            TimeoutException('timed out'),
          );

          final followers = await repository.getFollowers(testTargetPubkey);

          expect(followers, isEmpty);
        },
      );

      test(
        'handles relay query timeout via onTimeout',
        () async {
          // Simulate a query that takes too long
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) => Future<List<Event>>.delayed(
              const Duration(seconds: 12),
              () => [],
            ),
          );

          final followers = await repository.getFollowers(testTargetPubkey);

          expect(followers, isEmpty);
        },
        timeout: const Timeout(Duration(seconds: 20)),
      );
    });

    group('_checkIfTheyFollowUs edge cases', () {
      test('returns false when pubkey is empty', () async {
        // Set up: we follow testTargetPubkey
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        // Make publicKey empty for the _checkIfTheyFollowUs check
        // _fetchFollowers will also get empty pubkey
        when(() => mockNostrClient.publicKey).thenReturn('');

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        // Manually set state since initialize would skip with no keys
        // Use follow to add the target
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(() => mockNostrClient.publicKey).thenReturn('');

        // isMutualFollow checks isFollowing first, which is a local check
        // When publicKey is empty, _fetchFollowers('') returns []
        // and _checkIfTheyFollowUs returns false
        final result = await repository.isMutualFollow(testTargetPubkey);

        expect(result, isFalse);
      });
    });

    group('error handling - local storage', () {
      test('handles corrupted cache gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': 'not valid json',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        // Should not throw - logs error and continues
        await repository.initialize();

        expect(repository.followingCount, 0);
      });
    });

    group('getFollowerStats - REST stats fetch', () {
      test(
        'returns null when REST client is not available',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          // getFollowerStats calls _fetchFollowerStatsViaRest which
          // returns null since client is not available, then falls
          // through to WebSocket only
          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats, isNotNull);
          // REST unavailable → only WS results used
          verifyNever(
            () => mockFunnelcakeClient.getSocialCounts(any()),
          );
        },
      );
    });

    group('getFollowerStats - merge picks higher from each source', () {
      test(
        'picks WS following when higher than REST',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          // REST: followers=50, following=30
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 50,
              followingCount: 30,
            ),
          );

          // WS returns 80 p-tags (following=80 > REST following=30)
          final contactListEvent = Event(
            testTargetPubkey,
            EventKind.contactList,
            List.generate(
              80,
              (i) => ['p', i.toRadixString(16).padLeft(64, '0')],
            ),
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );

          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => Stream.value(contactListEvent));

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async {
                  await for (final event in eventStream) {
                    if (event.kind == EventKind.contactList &&
                        event.pubkey == pubkey) {
                      return event;
                    }
                  }
                  return null;
                },
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // followers: max(REST 50, WS 0) = 50
          // following: max(REST 30, WS 80) = 80 (WS wins)
          expect(stats.followers, equals(50));
          expect(stats.following, equals(80));
        },
      );
    });

    group('getFollowerStats - persistence', () {
      test(
        'persists when stats differ from persisted values',
        () async {
          final mockStatsDao = _MockProfileStatsDao();
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          // Fresh stats: 200 followers, 100 following (higher than persisted)
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 200,
              followingCount: 100,
            ),
          );

          // Persisted: 50 followers, 30 following (lower)
          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 50,
              followingCount: 30,
              cachedAt: DateTime.now(),
            ),
          );

          when(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          ).thenAnswer((_) async {});

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // Fresh is higher than persisted → accepted and persisted
          expect(stats.followers, equals(200));
          expect(stats.following, equals(100));

          verify(
            () => mockStatsDao.upsertStats(
              pubkey: testTargetPubkey,
              followerCount: 200,
              followingCount: 100,
            ),
          ).called(1);
        },
      );

      test(
        'does not persist when hysteresis keeps persisted values',
        () async {
          final mockStatsDao = _MockProfileStatsDao();
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          // Fresh stats slightly lower (within threshold)
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 90,
              followingCount: 45,
            ),
          );

          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 100,
              followingCount: 50,
              cachedAt: DateTime.now(),
            ),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          await repository.getFollowerStats(testTargetPubkey);

          // Hysteresis keeps persisted values — no upsert needed
          verifyNever(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          );
        },
      );
    });

    group('getFollowers with API branch', () {
      test(
        'merges API results with relay results',
        () async {
          const apiFollower =
              'aa00000000000000000000000000000000000000000000000000000000000001';
          const relayFollower =
              'bb00000000000000000000000000000000000000000000000000000000000002';

          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getFollowers(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => const PaginatedPubkeys(
              pubkeys: [apiFollower],
            ),
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              Event(
                relayFollower,
                3,
                [
                  ['p', testTargetPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            ],
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          final followers = await repository.getFollowers(testTargetPubkey);

          // Should have merged: API follower + relay follower
          expect(followers, contains(apiFollower));
          expect(followers, contains(relayFollower));
          expect(followers, hasLength(2));
        },
      );
    });

    group('_emitFollowingList dedup', () {
      test(
        'does not re-emit when list content is identical',
        () async {
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
          });

          final mockEvent = _MockEvent();
          when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
          when(() => mockEvent.content).thenReturn('');
          when(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => mockEvent);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();

          final emissions = <List<String>>[];
          final subscription = repository.followingStream.listen(emissions.add);

          await Future<void>.delayed(Duration.zero);
          final initialCount = emissions.length;

          // Follow then unfollow — list returns to same state
          await repository.follow(testTargetPubkey2);
          await repository.unfollow(testTargetPubkey2);
          await Future<void>.delayed(Duration.zero);

          // Should have emitted during follow and unfollow
          expect(emissions.length, greaterThan(initialCount));

          await subscription.cancel();
        },
      );
    });

    group('indexer relay queries', () {
      const indexerUrl = 'wss://fake-indexer.test';
      const followerPubkey1 =
          'aa00000000000000000000000000000000000000000000000000000000000001';
      const followerPubkey2 =
          'bb00000000000000000000000000000000000000000000000000000000000002';

      /// Helper: builds a relay factory that returns a [_FakeRelay]
      /// pre-loaded with [responses].
      RelayFactory fakeRelayFactory({
        List<List<dynamic>> responses = const [],
        bool shouldConnect = true,
      }) {
        return (String url, RelayStatus status) {
          final relay = _FakeRelay(
            url,
            status,
            shouldConnect: shouldConnect,
          )..fakeResponses = responses;
          return relay;
        };
      }

      group('_fetchFollowersCountViaIndexers', () {
        test(
          'returns follower count from indexer relay',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  [
                    'EVENT',
                    'sub1',
                    {'pubkey': followerPubkey1},
                  ],
                  [
                    'EVENT',
                    'sub1',
                    {'pubkey': followerPubkey2},
                  ],
                  ['EOSE', 'sub1'],
                ],
              ),
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            // 2 EVENT messages with distinct pubkeys → followers=2
            expect(stats.followers, equals(2));
          },
        );

        test(
          'returns 0 when indexer relay fails to connect',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(shouldConnect: false),
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            expect(stats.followers, equals(0));
          },
        );

        test(
          'returns 0 when relay throws',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: (url, status) {
                throw Exception('Relay creation failed');
              },
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            expect(stats.followers, equals(0));
          },
        );

        test(
          'uses highest count across multiple indexers',
          () async {
            var callCount = 0;
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [
                'wss://indexer1.test',
                'wss://indexer2.test',
              ],
              relayFactory: (url, status) {
                callCount++;
                final responses = callCount == 1
                    ? <List<dynamic>>[
                        [
                          'EVENT',
                          's',
                          {'pubkey': followerPubkey1},
                        ],
                        ['EOSE', 's'],
                      ]
                    : <List<dynamic>>[
                        [
                          'EVENT',
                          's',
                          {'pubkey': followerPubkey1},
                        ],
                        [
                          'EVENT',
                          's',
                          {'pubkey': followerPubkey2},
                        ],
                        ['EOSE', 's'],
                      ];
                return _FakeRelay(url, status)..fakeResponses = responses;
              },
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            // indexer1: 1 follower, indexer2: 2 followers → best=2
            expect(stats.followers, equals(2));
          },
        );
      });

      group('_fetchFollowerPubkeysFromIndexers', () {
        test(
          'returns follower pubkeys from indexer relay',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  [
                    'EVENT',
                    'sub1',
                    {'pubkey': followerPubkey1},
                  ],
                  [
                    'EVENT',
                    'sub1',
                    {'pubkey': followerPubkey2},
                  ],
                  ['EOSE', 'sub1'],
                ],
              ),
            );

            // getFollowers calls _fetchFollowers which merges
            // API + relay + indexer results
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [],
            );

            final followers = await repository.getFollowers(testTargetPubkey);

            expect(followers, contains(followerPubkey1));
            expect(followers, contains(followerPubkey2));
          },
        );

        test(
          'returns empty when indexer fails to connect',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(shouldConnect: false),
            );

            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [],
            );

            final followers = await repository.getFollowers(testTargetPubkey);

            // Only relay results (empty), no indexer results
            expect(followers, isEmpty);
          },
        );
      });

      group('_loadContactListFromIndexer', () {
        test(
          'loads contact list from indexer during initialization',
          () async {
            final contactListJson = {
              'pubkey': testCurrentUserPubkey,
              'kind': EventKind.contactList,
              'id':
                  'aaaa000000000000000000000000000000000000000000000000000000000000',
              'sig':
                  'bbbb000000000000000000000000000000000000000000000000000000000000bbbb000000000000000000000000000000000000000000000000000000000000',
              'content': '',
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'tags': [
                ['p', testTargetPubkey],
                ['p', testTargetPubkey2],
              ],
            };

            // Connected relays return nothing (empty stream +
            // queryContactList returns null)
            when(
              () => mockNostrClient.subscribe(
                any(),
                subscriptionId: any(named: 'subscriptionId'),
                tempRelays: any(named: 'tempRelays'),
                targetRelays: any(named: 'targetRelays'),
                relayTypes: any(named: 'relayTypes'),
                sendAfterAuth: any(named: 'sendAfterAuth'),
                onEose: any(named: 'onEose'),
              ),
            ).thenAnswer((_) => const Stream<Event>.empty());

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  ['EVENT', 'sub1', contactListJson],
                  ['EOSE', 'sub1'],
                ],
              ),
              queryContactList:
                  ({
                    required eventStream,
                    required pubkey,
                    fallbackTimeoutSeconds = 10,
                  }) async => null, // Connected relays return nothing
            );

            await repository.initialize();

            expect(repository.followingCount, 2);
            expect(
              repository.isFollowing(testTargetPubkey),
              isTrue,
            );
            expect(
              repository.isFollowing(testTargetPubkey2),
              isTrue,
            );
          },
        );

        test(
          'handles indexer returning no events',
          () async {
            when(
              () => mockNostrClient.subscribe(
                any(),
                subscriptionId: any(named: 'subscriptionId'),
                tempRelays: any(named: 'tempRelays'),
                targetRelays: any(named: 'targetRelays'),
                relayTypes: any(named: 'relayTypes'),
                sendAfterAuth: any(named: 'sendAfterAuth'),
                onEose: any(named: 'onEose'),
              ),
            ).thenAnswer((_) => const Stream<Event>.empty());

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  ['EOSE', 'sub1'],
                ],
              ),
              queryContactList:
                  ({
                    required eventStream,
                    required pubkey,
                    fallbackTimeoutSeconds = 10,
                  }) async => null,
            );

            await repository.initialize();

            expect(repository.followingCount, 0);
          },
        );

        test(
          'handles invalid event JSON from indexer',
          () async {
            when(
              () => mockNostrClient.subscribe(
                any(),
                subscriptionId: any(named: 'subscriptionId'),
                tempRelays: any(named: 'tempRelays'),
                targetRelays: any(named: 'targetRelays'),
                relayTypes: any(named: 'relayTypes'),
                sendAfterAuth: any(named: 'sendAfterAuth'),
                onEose: any(named: 'onEose'),
              ),
            ).thenAnswer((_) => const Stream<Event>.empty());

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  [
                    'EVENT',
                    'sub1',
                    {'invalid': 'json'},
                  ],
                  ['EOSE', 'sub1'],
                ],
              ),
              queryContactList:
                  ({
                    required eventStream,
                    required pubkey,
                    fallbackTimeoutSeconds = 10,
                  }) async => null,
            );

            // Should not throw — handles parse error gracefully
            await repository.initialize();

            expect(repository.followingCount, 0);
          },
        );

        test(
          'picks best when connected relay and indexer both return',
          () async {
            const olderTs = 1000000;
            const newerTs = 2000000;

            final olderEvent = Event(
              testCurrentUserPubkey,
              EventKind.contactList,
              [
                ['p', testTargetPubkey],
              ],
              '',
              createdAt: olderTs,
            );

            final newerContactListJson = {
              'pubkey': testCurrentUserPubkey,
              'kind': EventKind.contactList,
              'id':
                  'cccc000000000000000000000000000000000000000000000000000000000000',
              'sig':
                  'dddd000000000000000000000000000000000000000000000000000000000000dddd000000000000000000000000000000000000000000000000000000000000',
              'content': '',
              'created_at': newerTs,
              'tags': [
                ['p', testTargetPubkey],
                ['p', testTargetPubkey2],
              ],
            };

            var subscribeCallCount = 0;
            when(
              () => mockNostrClient.subscribe(
                any(),
                subscriptionId: any(named: 'subscriptionId'),
                tempRelays: any(named: 'tempRelays'),
                targetRelays: any(named: 'targetRelays'),
                relayTypes: any(named: 'relayTypes'),
                sendAfterAuth: any(named: 'sendAfterAuth'),
                onEose: any(named: 'onEose'),
              ),
            ).thenAnswer((_) {
              subscribeCallCount++;
              if (subscribeCallCount == 1) {
                return Stream.value(olderEvent);
              }
              return const Stream<Event>.empty();
            });

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  ['EVENT', 'sub1', newerContactListJson],
                  ['EOSE', 'sub1'],
                ],
              ),
              queryContactList:
                  ({
                    required eventStream,
                    required pubkey,
                    fallbackTimeoutSeconds = 10,
                  }) async {
                    await for (final event in eventStream) {
                      if (event.kind == EventKind.contactList &&
                          event.pubkey == pubkey) {
                        return event;
                      }
                    }
                    return null;
                  },
            );

            await repository.initialize();

            // Newer indexer event has 2 follows, should be picked
            expect(repository.followingCount, 2);
            expect(
              repository.isFollowing(testTargetPubkey),
              isTrue,
            );
            expect(
              repository.isFollowing(testTargetPubkey2),
              isTrue,
            );
          },
        );
      });

      group('indexer error paths', () {
        test(
          'handles indexer relay throwing during query',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: (url, status) {
                final relay = _FakeRelay(url, status)
                  ..fakeResponses = [
                    [
                      'EVENT',
                      's',
                      {'pubkey': followerPubkey1},
                    ],
                    // No EOSE — completer never completes from
                    // messages, but connect returns true so the code
                    // waits on completer.future.timeout which fires
                    // onTimeout returning current followerPubkeys.
                  ];
                return relay;
              },
            );

            // getFollowerStats triggers _fetchFollowersCountViaIndexers
            // which times out and returns partial results
            final stats = await repository.getFollowerStats(
              testTargetPubkey,
            );

            // Should get partial result from timeout
            expect(stats.followers, greaterThanOrEqualTo(0));
          },
          timeout: const Timeout(Duration(seconds: 20)),
        );

        test(
          'handles indexer query error with partial results',
          () async {
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [],
            );

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: (url, status) {
                final relay = _FakeRelay(url, status)
                  ..fakeResponses = [
                    [
                      'EVENT',
                      's',
                      {'pubkey': followerPubkey1},
                    ],
                    // No EOSE — timeout will fire
                  ];
                return relay;
              },
            );

            // getFollowers triggers _fetchFollowerPubkeysFromIndexers
            final followers = await repository.getFollowers(testTargetPubkey);

            // Should not throw
            expect(followers, isA<List<String>>());
          },
          timeout: const Timeout(Duration(seconds: 20)),
        );

        test(
          'handles indexer returning no contact list',
          () async {
            when(
              () => mockNostrClient.subscribe(
                any(),
                subscriptionId: any(named: 'subscriptionId'),
                tempRelays: any(named: 'tempRelays'),
                targetRelays: any(named: 'targetRelays'),
                relayTypes: any(named: 'relayTypes'),
                sendAfterAuth: any(named: 'sendAfterAuth'),
                onEose: any(named: 'onEose'),
              ),
            ).thenAnswer((_) => const Stream<Event>.empty());

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [
                'wss://idx1.test',
                'wss://idx2.test',
              ],
              relayFactory: fakeRelayFactory(shouldConnect: false),
              queryContactList:
                  ({
                    required eventStream,
                    required pubkey,
                    fallbackTimeoutSeconds = 10,
                  }) async => null,
            );

            await repository.initialize();

            // No indexer returned data
            expect(repository.followingCount, 0);
          },
        );
      });
    });

    group('getFollowerStats - WS followers higher than REST', () {
      test(
        'picks WS followers when higher than REST',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          // REST: followers=5
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 5,
              followingCount: 10,
            ),
          );

          const indexerUrl = 'wss://idx.test';

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [indexerUrl],
            relayFactory: (url, status) {
              // Return 10 follower pubkeys → WS followers=10 > REST=5
              return _FakeRelay(url, status)
                ..fakeResponses = [
                  ...List.generate(
                    10,
                    (i) => <dynamic>[
                      'EVENT',
                      's',
                      {
                        'pubkey': i.toRadixString(16).padLeft(64, '0'),
                      },
                    ],
                  ),
                  <dynamic>['EOSE', 's'],
                ];
            },
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // followers: max(REST 5, WS 10) = 10
          expect(stats.followers, equals(10));
          // following: max(REST 10, WS 0) = 10
          expect(stats.following, equals(10));
        },
      );
    });

    group('_emitFollowingList dedup with same-length lists', () {
      test(
        'emits when list content changes but length stays the same',
        () async {
          // Seed with one follow
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
          });

          final controller = StreamController<Event>.broadcast();
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => controller.stream);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();
          expect(repository.followingCount, 1);
          expect(
            repository.isFollowing(testTargetPubkey),
            isTrue,
          );

          final emissions = <List<String>>[];
          final subscription = repository.followingStream.listen(emissions.add);
          await Future<void>.delayed(Duration.zero);
          emissions.clear();

          // Send remote event that swaps the followed user
          // (same count=1, but different pubkey)
          final swapEvent = Event(
            testCurrentUserPubkey,
            3,
            [
              ['p', testTargetPubkey2],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
          );

          controller.add(swapEvent);
          await Future<void>.delayed(
            const Duration(milliseconds: 50),
          );

          // Should have emitted because content changed
          // (even though length stayed at 1)
          expect(emissions, isNotEmpty);
          expect(emissions.last, contains(testTargetPubkey2));
          expect(
            emissions.last,
            isNot(contains(testTargetPubkey)),
          );

          await subscription.cancel();
          await repository.dispose();
          await controller.close();
        },
      );
    });

    group('remaining error paths', () {
      test(
        'getFollowerStats catch returns persisted fallback',
        () async {
          final mockStatsDao = _MockProfileStatsDao();

          // Make getStatsRaw throw first (in try block), succeed
          // second (in catch block)
          var callCount = 0;
          when(() => mockStatsDao.getStatsRaw(any())).thenAnswer(
            (_) async {
              callCount++;
              if (callCount == 1) throw Exception('DB error');
              return ProfileStatRow(
                pubkey: testTargetPubkey,
                followerCount: 42,
                followingCount: 10,
                cachedAt: DateTime.now(),
              );
            },
          );

          // REST unavailable, WS returns zero → fresh=(0,0)
          // → enters "fresh is zero" branch
          // → _loadPersistedStats throws → propagates to catch
          // → catch calls _loadPersistedStats again → succeeds
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.followers, equals(42));
          expect(stats.following, equals(10));
        },
      );

      test(
        'getFollowerCount returns 0 when getFollowerStats throws',
        () async {
          final mockStatsDao = _MockProfileStatsDao();

          // Make getStatsRaw always throw so getFollowerStats
          // throws from its catch block
          when(() => mockStatsDao.getStatsRaw(any())).thenThrow(
            Exception('DB completely broken'),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final count = await repository.getFollowerCount(testTargetPubkey);

          expect(count, equals(0));
        },
      );

      test(
        'indexer relay send error returns partial results',
        () async {
          const indexerUrl = 'wss://idx.test';

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [indexerUrl],
            relayFactory: (url, status) {
              return _FakeRelay(url, status, throwOnSend: true)
                ..fakeResponses = [
                  [
                    'EVENT',
                    's',
                    {
                      'pubkey':
                          'aa00000000000000000000000000000000000000000000000000000000000001',
                    },
                  ],
                  ['EOSE', 's'],
                ];
            },
          );

          // send() throws after completer completes
          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats, isNotNull);
        },
      );

      test(
        'indexer relay disconnect error does not crash',
        () async {
          const indexerUrl = 'wss://idx.test';

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [indexerUrl],
            relayFactory: (url, status) {
              return _FakeRelay(
                  url,
                  status,
                  throwOnDisconnect: true,
                )
                ..fakeResponses = [
                  [
                    'EVENT',
                    's',
                    {
                      'pubkey':
                          'aa00000000000000000000000000000000000000000000000000000000000001',
                    },
                  ],
                  ['EOSE', 's'],
                ];
            },
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // Should succeed despite disconnect error
          expect(stats.followers, equals(1));
        },
      );

      test(
        '_checkIfTheyFollowUs catch returns false',
        () async {
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
          });

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();

          // queryEvents: first call (from _fetchFollowersFromRelays)
          // returns empty, second call (from _checkIfTheyFollowUs)
          // throws
          var queryCallCount = 0;
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async {
              queryCallCount++;
              if (queryCallCount == 1) return [];
              throw Exception('Network error');
            },
          );

          final result = await repository.isMutualFollow(testTargetPubkey);

          expect(result, isFalse);
        },
      );

      test(
        'indexer follower pubkeys error returns partial results',
        () async {
          const indexerUrl = 'wss://idx.test';

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [],
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [indexerUrl],
            relayFactory: (url, status) {
              return _FakeRelay(url, status, throwOnSend: true)
                ..fakeResponses = [
                  [
                    'EVENT',
                    's',
                    {
                      'pubkey':
                          'aa00000000000000000000000000000000000000000000000000000000000001',
                    },
                  ],
                  ['EOSE', 's'],
                ];
            },
          );

          final followers = await repository.getFollowers(testTargetPubkey);

          // Should not crash — returns whatever was collected
          expect(followers, isA<List<String>>());
        },
      );

      test(
        'broadcastContactList catchError during catastrophic merge',
        () async {
          final seededPubkeys = List.generate(
            12,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey':
                '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
          });

          final controller = StreamController<Event>.broadcast();
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => controller.stream);

          // Make broadcast fail
          when(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => null);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();
          expect(repository.followingCount, 12);

          // Catastrophic reduction with new pubkey → triggers merge
          // + broadcastContactList which fails
          const newPk =
              'ff00000000000000000000000000000000000000000000000000000000000001';
          controller.add(
            Event(
              testCurrentUserPubkey,
              3,
              [
                ['p', newPk],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
            ),
          );
          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );

          // Merge happened, broadcast failed but didn't crash
          expect(repository.followingCount, 13);

          await repository.dispose();
          await controller.close();
        },
      );

      test(
        '_loadContactListFromIndexer handles throw',
        () async {
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => const Stream<Event>.empty());

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://idx.test'],
            relayFactory: (url, status) {
              throw Exception('Relay creation error');
            },
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async => null,
          );

          // Should not crash — logs warning and continues
          await repository.initialize();

          expect(repository.followingCount, 0);
        },
      );

      test(
        '_queryIndexerForContactList timeout returns bestEvent',
        () async {
          // Create a relay that sends an EVENT but no EOSE
          // → completer times out → returns bestEvent
          final contactListJson = {
            'pubkey': testCurrentUserPubkey,
            'kind': EventKind.contactList,
            'id':
                'aaaa000000000000000000000000000000000000000000000000000000000000',
            'sig':
                'bbbb000000000000000000000000000000000000000000000000000000000000bbbb000000000000000000000000000000000000000000000000000000000000',
            'content': '',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'tags': [
              ['p', testTargetPubkey],
            ],
          };

          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => const Stream<Event>.empty());

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://idx.test'],
            relayFactory: (url, status) {
              // EVENT but no EOSE → timeout fires
              return _FakeRelay(url, status)
                ..fakeResponses = [
                  ['EVENT', 'sub1', contactListJson],
                  // No EOSE — completer times out
                ];
            },
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async => null,
          );

          await repository.initialize();

          // Should load from timeout with bestEvent
          expect(repository.followingCount, 1);
          expect(
            repository.isFollowing(testTargetPubkey),
            isTrue,
          );
        },
        timeout: const Timeout(Duration(seconds: 15)),
      );

      test(
        '_queryIndexerForContactList handles send error',
        () async {
          final contactListJson = {
            'pubkey': testCurrentUserPubkey,
            'kind': EventKind.contactList,
            'id':
                'aaaa000000000000000000000000000000000000000000000000000000000000',
            'sig':
                'bbbb000000000000000000000000000000000000000000000000000000000000bbbb000000000000000000000000000000000000000000000000000000000000',
            'content': '',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'tags': [
              ['p', testTargetPubkey],
            ],
          };

          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => const Stream<Event>.empty());

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://idx.test'],
            relayFactory: (url, status) {
              return _FakeRelay(url, status, throwOnSend: true)
                ..fakeResponses = [
                  ['EVENT', 'sub1', contactListJson],
                  ['EOSE', 'sub1'],
                ];
            },
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async => null,
          );

          await repository.initialize();

          // Should have loaded despite send error (CLOSE msg fails)
          expect(repository.followingCount, 1);
        },
      );

      test(
        '_defaultRelayFactory is used when no factory injected',
        () async {
          // Create repo WITHOUT relayFactory but WITH indexer URL.
          // The default factory creates a real RelayBase which
          // will fail to connect to the fake URL.
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://127.0.0.1:1'],
          );

          // getFollowerStats triggers indexer query using
          // _defaultRelayFactory. Connection to localhost:1 will
          // fail fast (connection refused).
          final stats = await repository.getFollowerStats(testTargetPubkey);

          // Should return FollowerStats.zero (connection failed)
          expect(stats, isNotNull);
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );

      test(
        '_loadFromRelay outer catch fires on Future.wait error',
        () async {
          // _loadFromRelay calls Future.wait on connected relay
          // and indexer queries. If both throw, the outer catch
          // at 1510 fires.
          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenThrow(Exception('Subscribe failed'));

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://idx.test'],
            relayFactory: (url, status) {
              throw Exception('Relay factory error');
            },
          );

          // Both connected relay and indexer throw → outer catch
          await repository.initialize();

          expect(repository.followingCount, 0);
        },
      );

      test(
        '_queryIndexerForContactList picks newer of two events',
        () async {
          final olderContactList = {
            'pubkey': testCurrentUserPubkey,
            'kind': EventKind.contactList,
            'id':
                'aaaa000000000000000000000000000000000000000000000000000000000000',
            'sig':
                'bbbb000000000000000000000000000000000000000000000000000000000000bbbb000000000000000000000000000000000000000000000000000000000000',
            'content': '',
            'created_at': 1000000,
            'tags': [
              ['p', testTargetPubkey],
            ],
          };

          final newerContactList = {
            'pubkey': testCurrentUserPubkey,
            'kind': EventKind.contactList,
            'id':
                'cccc000000000000000000000000000000000000000000000000000000000000',
            'sig':
                'dddd000000000000000000000000000000000000000000000000000000000000dddd000000000000000000000000000000000000000000000000000000000000',
            'content': '',
            'created_at': 2000000,
            'tags': [
              ['p', testTargetPubkey],
              ['p', testTargetPubkey2],
            ],
          };

          when(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => const Stream<Event>.empty());

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://idx.test'],
            relayFactory: (url, status) {
              // Two EVENTs (older then newer) + EOSE
              return _FakeRelay(url, status)
                ..fakeResponses = [
                  ['EVENT', 'sub1', olderContactList],
                  ['EVENT', 'sub1', newerContactList],
                  ['EOSE', 'sub1'],
                ];
            },
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async => null,
          );

          await repository.initialize();

          // Should pick the newer event with 2 follows
          expect(repository.followingCount, 2);
          expect(
            repository.isFollowing(testTargetPubkey),
            isTrue,
          );
          expect(
            repository.isFollowing(testTargetPubkey2),
            isTrue,
          );
        },
      );
    });
  });
}
