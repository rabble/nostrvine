// ABOUTME: Unit tests for FollowRepository
// ABOUTME: Tests follow/unfollow operations, caching, and network sync

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockEvent extends Mock implements Event {}

class _FakeContactList extends Fake implements ContactList {}

void main() {
  group('FollowRepository', () {
    late FollowRepository repository;
    late _MockNostrClient mockNostrClient;
    late _MockPersonalEventCacheService mockPersonalEventCache;

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
      mockPersonalEventCache = _MockPersonalEventCacheService();

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

      // Default personal event cache setup
      when(() => mockPersonalEventCache.isInitialized).thenReturn(false);

      repository = FollowRepository(
        nostrClient: mockNostrClient,
        personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        // Should not throw, just log warning and continue
        await repository.initialize();

        expect(repository.isInitialized, isTrue);
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
            3,
            stalePubkeys.map((p) => ['p', p]).toList(),
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 100,
          );
          when(() => mockPersonalEventCache.isInitialized).thenReturn(true);
          when(
            () => mockPersonalEventCache.getEventsByKind(3),
          ).thenReturn([staleEvent]);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            personalEventCache: mockPersonalEventCache,
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
            3,
            cachePubkeys.map((p) => ['p', p]).toList(),
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
          );
          when(() => mockPersonalEventCache.isInitialized).thenReturn(true);
          when(
            () => mockPersonalEventCache.getEventsByKind(3),
          ).thenReturn([cacheEvent]);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            personalEventCache: mockPersonalEventCache,
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

        when(
          () => mockPersonalEventCache.cacheUserEvent(any()),
        ).thenReturn(null);

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

        when(
          () => mockPersonalEventCache.cacheUserEvent(any()),
        ).thenReturn(null);

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

        when(
          () => mockPersonalEventCache.cacheUserEvent(any()),
        ).thenReturn(null);

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

        when(
          () => mockPersonalEventCache.cacheUserEvent(any()),
        ).thenReturn(null);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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

        when(
          () => mockPersonalEventCache.cacheUserEvent(any()),
        ).thenReturn(null);

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

        when(
          () => mockPersonalEventCache.cacheUserEvent(any()),
        ).thenReturn(null);

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

      test('returns empty list on timeout', () {
        fakeAsync((async) {
          // Simulate a slow query that exceeds the repository's internal
          // 8-second timeout.
          when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(seconds: 15));
            return [];
          });

          List<String>? followers;
          repository.getFollowers(testTargetPubkey).then((r) => followers = r);

          // Advance past the 8s _fetchFollowersTimeout
          async.elapse(const Duration(seconds: 9));
          async.flushMicrotasks();

          expect(followers, isEmpty);
        });
      });
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

        // Override subscribe to distinguish initialization from real-time:
        //   - Init relay query (no subscriptionId) → empty stream so it
        //     completes immediately instead of waiting 5s fallback timeout
        //   - Real-time sync (with subscriptionId) → broadcast stream
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
        ).thenAnswer((invocation) {
          final subscriptionId =
              invocation.namedArguments[#subscriptionId] as String?;
          if (subscriptionId == null) {
            return const Stream<Event>.empty();
          }
          return realTimeStreamController.stream;
        });
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
        await Future<void>.delayed(Duration.zero);

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
        await Future<void>.delayed(Duration.zero);

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
        await Future<void>.delayed(Duration.zero);

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
        await Future<void>.delayed(Duration.zero);

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
        await Future<void>.delayed(Duration.zero);

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
        await Future<void>.delayed(Duration.zero);

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
        await Future<void>.delayed(Duration.zero);

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
            personalEventCache: mockPersonalEventCache,
            indexerRelayUrls: const [],
          );

          // Mock sendContactList for the merge broadcast
          when(
            () => mockNostrClient.sendContactList(any(), any()),
          ).thenAnswer(
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
          await Future<void>.delayed(Duration.zero);

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

      test(
        'accepts drastic reduction when remote is a subset (legitimate mass '
        'unfollow)',
        () async {
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
            personalEventCache: mockPersonalEventCache,
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
          await Future<void>.delayed(Duration.zero);

          // Should accept as-is (not merge) because no new pubkeys
          expect(repository.followingCount, 3);
        },
      );

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
            personalEventCache: mockPersonalEventCache,
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
          await Future<void>.delayed(Duration.zero);

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
          personalEventCache: mockPersonalEventCache,
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
        await Future<void>.delayed(Duration.zero);

        // Should accept the larger list
        expect(repository.followingCount, 10);
      });

      test(
        'skips merge protection when local list is below threshold',
        () async {
          // Seed with 1 follow (below _mergeMinFollows of 2)
          final seededPubkeys = [
            '0'.padLeft(64, '0'),
          ];
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey':
                '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
          });

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            personalEventCache: mockPersonalEventCache,
            indexerRelayUrls: const [],
          );

          await repository.initialize();
          expect(repository.followingCount, 1);

          // Remote event with a different follow — drastic but below threshold
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
          await Future<void>.delayed(Duration.zero);

          // Should replace (not merge) because local list is below threshold
          expect(repository.followingCount, 1);
          expect(repository.followingPubkeys, equals([testTargetPubkey]));
        },
      );

      test(
        'merges when small list (above threshold) receives buggy event with '
        'new pubkey',
        () async {
          // Seed with 3 follows (above _mergeMinFollows of 2)
          final seededPubkeys = List.generate(
            3,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey':
                '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
          });

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            personalEventCache: mockPersonalEventCache,
            indexerRelayUrls: const [],
          );

          // Mock sendContactList for the merge re-broadcast
          when(
            () => mockNostrClient.sendContactList(any(), any()),
          ).thenAnswer(
            (_) async => Event(
              testCurrentUserPubkey,
              3,
              [],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 200,
            ),
          );

          await repository.initialize();
          expect(repository.followingCount, 3);

          // Remote event with 1 new follow — drastic reduction + new pubkey
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
          await Future<void>.delayed(Duration.zero);

          // Should merge: all 3 original + 1 new = 4
          expect(repository.followingCount, 4);
          expect(repository.followingPubkeys, contains(testTargetPubkey));
          for (final pk in seededPubkeys) {
            expect(repository.followingPubkeys, contains(pk));
          }

          // Verify re-broadcast was triggered
          verify(() => mockNostrClient.sendContactList(any(), any())).called(1);
        },
      );

      test(
        'accepts legitimate unfollow on small list (subset, no new pubkeys)',
        () async {
          // Seed with 3 follows (above _mergeMinFollows of 2)
          final seededPubkeys = List.generate(
            3,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey':
                '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
          });

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            personalEventCache: mockPersonalEventCache,
            indexerRelayUrls: const [],
          );

          await repository.initialize();
          expect(repository.followingCount, 3);

          // Remote event with 1 of the original 3 — legitimate unfollow
          final remoteEvent = Event(
            testCurrentUserPubkey,
            3,
            [
              ['p', seededPubkeys.first],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
          );

          realTimeStreamController.add(remoteEvent);
          await Future<void>.delayed(Duration.zero);

          // Should accept as-is: no new pubkeys → legitimate mass unfollow
          expect(repository.followingCount, 1);
          expect(repository.followingPubkeys, equals([seededPubkeys.first]));
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
        await Future<void>.delayed(Duration.zero);

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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
          indexerRelayUrls: const [],
        );

        final result = await repo.getSocialCounts(testCurrentUserPubkey);

        expect(result, isNull);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
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
          personalEventCache: mockPersonalEventCache,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        expect(
          () => repo.getFollowingFromApi(pubkey: testCurrentUserPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });
    });
  });
}
