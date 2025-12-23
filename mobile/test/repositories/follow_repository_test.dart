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

        // Verify subscribe was only called once during first init
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
  });
}
