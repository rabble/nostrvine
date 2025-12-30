// ABOUTME: Unit tests for FollowRepository
// ABOUTME: Tests follow/unfollow operations, caching, and network sync

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

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
      );
    });

    tearDown(() {
      repository.dispose();
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
        );

        await repository.initialize();

        expect(repository.followingCount, 2);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.isFollowing(testTargetPubkey2), isTrue);
      });

      test('does not reinitialize if already initialized', () async {
        await repository.initialize();
        expect(repository.isInitialized, isTrue);

        // Second call should return immediately
        await repository.initialize();
        expect(repository.isInitialized, isTrue);

        // Verify subscribe was called once during first init
        // for real-time cross-device sync subscription
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
        ).called(1);
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
  });
}
