// ABOUTME: Tests for FollowRepository's CacheSync-backed watcher methods
// ABOUTME: Covers cache emission, live emission, count derivation, forceRefresh

import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';

import '../../../cache_sync/test/fake_cache_dao.dart';

class _MockNostrClient extends Mock implements NostrClient {}

/// Subclass that overrides the data-source methods wrapped by the cached
/// watchers, so tests can drive deterministic input without standing up a
/// full Nostr stack.
class _TestableFollowRepository extends FollowRepository {
  _TestableFollowRepository({
    required super.nostrClient,
    required this.myFollowersStream,
    required this.myFollowingStream,
    required this.othersFollowersResult,
    required this.othersFollowingResult,
  }) : super(indexerRelayUrls: const []);

  final Stream<FollowersSnapshot> myFollowersStream;
  final Stream<FollowingSnapshot> myFollowingStream;
  final List<String> othersFollowersResult;
  final FollowingSnapshot othersFollowingResult;

  int getFollowersCallCount = 0;
  int getOthersFollowingCallCount = 0;

  @override
  Stream<FollowersSnapshot> watchMyFollowers() => myFollowersStream;

  @override
  Stream<FollowingSnapshot> watchMyFollowing() => myFollowingStream;

  @override
  Future<List<String>> getFollowers(String pubkey) async {
    getFollowersCallCount++;
    return othersFollowersResult;
  }

  @override
  Future<FollowingSnapshot> getOthersFollowing(String pubkey) async {
    getOthersFollowingCallCount++;
    return othersFollowingResult;
  }
}

void main() {
  late FakeCacheDao dao;
  late _MockNostrClient mockNostrClient;

  setUp(() async {
    dao = FakeCacheDao();
    await CacheSync.init(dao: dao);
    mockNostrClient = _MockNostrClient();
  });

  group('FollowRepository.watchMyFollowersCached', () {
    test('emits live result when cache is empty', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersStream: Stream.value(
          const FollowersSnapshot(pubkeys: ['a', 'b'], count: 2),
        ),
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: [],
          count: 0,
        ),
      );

      final events = await repo.watchMyFollowersCached().take(1).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['a', 'b']);
      expect(events[0].data.count, 2);
    });

    test('emits cached then live when cache is populated', () async {
      await dao.write(
        key: 'my_followers',
        payload: const FollowersSnapshot(
          pubkeys: ['cached'],
          count: 1,
        ).toJson(),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersStream: Stream.value(
          const FollowersSnapshot(pubkeys: ['live'], count: 1),
        ),
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: [],
          count: 0,
        ),
      );

      final events = await repo.watchMyFollowersCached().take(2).toList();

      expect(events, hasLength(2));
      expect(events[0].isLive, isFalse);
      expect(events[0].data.pubkeys, ['cached']);
      expect(events[1].isLive, isTrue);
      expect(events[1].data.pubkeys, ['live']);
    });
  });

  group('FollowRepository.watchMyFollowingCached', () {
    test('emits live result from underlying watchMyFollowing', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersStream: const Stream.empty(),
        myFollowingStream: Stream.value(
          const FollowingSnapshot(pubkeys: ['x'], count: 1),
        ),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: [],
          count: 0,
        ),
      );

      final events = await repo.watchMyFollowingCached().take(1).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['x']);
    });
  });

  group('FollowRepository.watchOthersFollowersCached', () {
    test('derives count from list length', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersStream: const Stream.empty(),
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['p1', 'p2', 'p3'],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: [],
          count: 0,
        ),
      );

      final events = await repo
          .watchOthersFollowersCached('target')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].data.pubkeys, ['p1', 'p2', 'p3']);
      expect(events[0].data.count, 3);
    });

    test('emits cached then live when cache is populated', () async {
      await dao.write(
        key: 'others_followers_target',
        payload: const FollowersSnapshot(pubkeys: ['stale'], count: 1).toJson(),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersStream: const Stream.empty(),
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['fresh'],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: [],
          count: 0,
        ),
      );

      final events = await repo
          .watchOthersFollowersCached('target')
          .take(2)
          .toList();

      expect(events, hasLength(2));
      expect(events[0].isLive, isFalse);
      expect(events[0].data.pubkeys, ['stale']);
      expect(events[1].isLive, isTrue);
      expect(events[1].data.pubkeys, ['fresh']);
    });

    test('forceRefresh skips cached emission', () async {
      await dao.write(
        key: 'others_followers_target',
        payload: const FollowersSnapshot(pubkeys: ['stale'], count: 1).toJson(),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersStream: const Stream.empty(),
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['fresh'],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: [],
          count: 0,
        ),
      );

      final events = await repo
          .watchOthersFollowersCached('target', forceRefresh: true)
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['fresh']);
    });

    test('uses pubkey-scoped cache key', () async {
      await dao.write(
        key: 'others_followers_alice',
        payload: const FollowersSnapshot(
          pubkeys: ['alice_cached'],
          count: 1,
        ).toJson(),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersStream: const Stream.empty(),
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['bob_live'],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: [],
          count: 0,
        ),
      );

      // Querying 'bob' must NOT see 'alice's cache.
      final events = await repo
          .watchOthersFollowersCached('bob')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['bob_live']);
    });
  });

  group('FollowRepository.watchOthersFollowingCached', () {
    test('emits live FollowingSnapshot from getOthersFollowing', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersStream: const Stream.empty(),
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['f1', 'f2'],
          count: 2,
        ),
      );

      final events = await repo
          .watchOthersFollowingCached('target')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['f1', 'f2']);
      expect(events[0].data.count, 2);
    });

    test('forceRefresh skips cached emission', () async {
      await dao.write(
        key: 'others_following_target',
        payload: const FollowingSnapshot(
          pubkeys: ['stale'],
          count: 1,
        ).toJson(),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersStream: const Stream.empty(),
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['fresh'],
          count: 1,
        ),
      );

      final events = await repo
          .watchOthersFollowingCached('target', forceRefresh: true)
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['fresh']);
    });
  });
}
