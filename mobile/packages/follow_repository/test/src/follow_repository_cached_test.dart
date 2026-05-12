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
    required this.myFollowingStream,
    required this.othersFollowersResult,
    required this.othersFollowingResult,
    this.myFollowersResult = const [],
    this.myFollowerCountResult = 0,
    this.othersFollowerCountResult = 0,
    Stream<FollowersSnapshot>? myFollowersStream,
  }) : _myFollowersStream = myFollowersStream,
       super(indexerRelayUrls: const []);

  final List<String> myFollowersResult;
  final int myFollowerCountResult;
  final int othersFollowerCountResult;
  // Injected only in regression tests that need to simulate the two-phase
  // emission pattern of the production watchMyFollowers() method.
  final Stream<FollowersSnapshot>? _myFollowersStream;
  final Stream<FollowingSnapshot> myFollowingStream;
  final List<String> othersFollowersResult;
  final FollowingSnapshot othersFollowingResult;

  int getFollowersCallCount = 0;
  int getMyFollowersCallCount = 0;
  int getOthersFollowingCallCount = 0;

  @override
  Future<List<String>> getMyFollowers() async {
    getMyFollowersCallCount++;
    return myFollowersResult;
  }

  @override
  Future<int> getMyFollowerCount() async => myFollowerCountResult;

  @override
  Stream<FollowersSnapshot> watchMyFollowers() {
    // When a custom stream is injected (regression tests), use it; otherwise
    // fall back to a single-value stream derived from myFollowersResult.
    return _myFollowersStream ??
        Stream.value(
          FollowersSnapshot(
            pubkeys: myFollowersResult,
            count: myFollowerCountResult,
          ),
        );
  }

  @override
  Stream<FollowingSnapshot> watchMyFollowing() => myFollowingStream;

  @override
  Future<List<String>> getFollowers(String pubkey) async {
    getFollowersCallCount++;
    return othersFollowersResult;
  }

  @override
  Future<int> getFollowerCount(String pubkey) async =>
      othersFollowerCountResult;

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
    when(() => mockNostrClient.publicKey).thenReturn('current-user');
  });

  group('FollowRepository.watchMyFollowersCached', () {
    test('emits live result when cache is empty', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersResult: const ['a', 'b'],
        myFollowerCountResult: 2,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo.watchMyFollowersCached().take(1).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['a', 'b']);
      expect(events[0].data.count, 2);
    });

    test('emits cached then live when cache is populated', () async {
      await dao.write(
        key: 'my_followers_current-user',
        payload: const FollowersSnapshot(
          pubkeys: ['cached'],
          count: 1,
        ).toJson(),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersResult: const ['live'],
        myFollowerCountResult: 1,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo.watchMyFollowersCached().take(2).toList();

      expect(events, hasLength(2));
      expect(events[0].isLive, isFalse);
      expect(events[0].data.pubkeys, ['cached']);
      expect(events[1].isLive, isTrue);
      expect(events[1].data.pubkeys, ['live']);
    });

    test('uses current-user scoped cache key', () async {
      await dao.write(
        key: 'my_followers_alice',
        payload: const FollowersSnapshot(
          pubkeys: ['alice_cached'],
          count: 1,
        ).toJson(),
      );
      when(() => mockNostrClient.publicKey).thenReturn('bob');

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersResult: const ['bob_live'],
        myFollowerCountResult: 1,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo.watchMyFollowersCached().take(1).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['bob_live']);
    });

    test(
      'regression – disk cache and in-memory followers cache both populated: '
      'emits exactly [cached, live] with network data, not the in-memory '
      'snapshot',
      () async {
        await dao.write(
          key: 'my_followers_current-user',
          payload: const FollowersSnapshot(
            pubkeys: ['disk'],
            count: 1,
          ).toJson(),
        );

        // _myFollowersStream emits two values, replicating the two-phase
        // emission pattern that watchMyFollowers() uses when
        // _hasMyFollowersCache is true: first the in-memory snapshot, then
        // the live network data.
        //
        // Regression: the old CacheSync.watchStream-based implementation
        // tagged the first (in-memory) emission as CacheResult.live, so
        // take(2) returned [cached(disk), live(in_memory)] and
        // events[1].data.pubkeys equalled ['in_memory'] instead of
        // ['network']. This test would have failed against the old code.
        //
        // With the fix (CacheSync.watchOne), watchMyFollowers() is not called
        // at all; getMyFollowers()/getMyFollowerCount() drive the single live
        // fetch and produce exactly [cached(disk), live(network)].
        final repo = _TestableFollowRepository(
          nostrClient: mockNostrClient,
          myFollowersResult: const ['network'],
          myFollowerCountResult: 1,
          myFollowersStream: Stream.fromIterable([
            const FollowersSnapshot(pubkeys: ['in_memory'], count: 1),
            const FollowersSnapshot(pubkeys: ['network'], count: 1),
          ]),
          myFollowingStream: const Stream.empty(),
          othersFollowersResult: const [],
          othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
        );

        final events = await repo.watchMyFollowersCached().take(2).toList();

        expect(events, hasLength(2));
        expect(events[0].isLive, isFalse);
        expect(events[0].data.pubkeys, ['disk']);
        expect(events[1].isLive, isTrue);
        // Must be ['network'] from getMyFollowers(), NOT ['in_memory'] from
        // the watchMyFollowers() in-memory cache phase.
        expect(events[1].data.pubkeys, ['network']);
        expect(repo.getMyFollowersCallCount, 1);
      },
    );
  });

  group('FollowRepository.watchMyFollowingCached', () {
    test('emits live result from a fresh getOthersFollowing fetch, '
        'NOT from the watchMyFollowing BehaviorSubject replay', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        // BehaviorSubject replay value — must be IGNORED by the new
        // watchOne-based implementation so CacheSync alone owns
        // stale/live semantics.
        myFollowingStream: Stream.value(
          const FollowingSnapshot(pubkeys: ['in_memory_replay'], count: 1),
        ),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['network'],
          count: 1,
        ),
      );

      final events = await repo.watchMyFollowingCached().take(1).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['network']);
      expect(repo.getOthersFollowingCallCount, 1);
    });

    test('emits cached (stale) then live (fresh) — proves CacheSync owns '
        'the single stale/live boundary', () async {
      await dao.write(
        key: 'my_following_bob',
        payload: const FollowingSnapshot(pubkeys: ['disk'], count: 1).toJson(),
      );
      when(() => mockNostrClient.publicKey).thenReturn('bob');

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        // In-memory replay should NEVER be mis-tagged as live by the
        // wrapper. This is the regression check for the reviewer's
        // "double cache layer" concern.
        myFollowingStream: Stream.value(
          const FollowingSnapshot(pubkeys: ['in_memory_replay'], count: 1),
        ),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['network'],
          count: 1,
        ),
      );

      final events = await repo.watchMyFollowingCached().take(2).toList();

      expect(events, hasLength(2));
      expect(events[0].isLive, isFalse);
      expect(events[0].data.pubkeys, ['disk']);
      expect(events[1].isLive, isTrue);
      // Must be ['network'] from getOthersFollowing(), NOT
      // ['in_memory_replay'] from the BehaviorSubject.
      expect(events[1].data.pubkeys, ['network']);
      expect(repo.getOthersFollowingCallCount, 1);
    });

    test('uses current-user scoped cache key', () async {
      await dao.write(
        key: 'my_following_alice',
        payload: const FollowingSnapshot(
          pubkeys: ['alice_cached'],
          count: 1,
        ).toJson(),
      );
      when(() => mockNostrClient.publicKey).thenReturn('bob');

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: Stream.value(
          const FollowingSnapshot(pubkeys: ['bob_in_memory'], count: 1),
        ),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['bob_live'],
          count: 1,
        ),
      );

      final events = await repo.watchMyFollowingCached().take(1).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      // Bob's own pubkey was used to query — not Alice's cached entry.
      expect(events[0].data.pubkeys, ['bob_live']);
    });
  });

  group('FollowRepository.watchOthersFollowersCached', () {
    test('uses max of follower list length and authoritative count', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['p1', 'p2', 'p3'],
        othersFollowerCountResult: 10,
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo
          .watchOthersFollowersCached('target')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].data.pubkeys, ['p1', 'p2', 'p3']);
      expect(events[0].data.count, 10);
    });

    test('expired cached entry refetches live data', () async {
      await dao.write(
        key: 'others_followers_target',
        payload: const FollowersSnapshot(pubkeys: ['stale'], count: 1).toJson(),
        ttl: const Duration(microseconds: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['fresh'],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo
          .watchOthersFollowersCached('target')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['fresh']);
    });

    test('uses cacheFirst policy for fresh cached profile lists', () async {
      await dao.write(
        key: 'others_followers_target',
        payload: const FollowersSnapshot(pubkeys: ['stale'], count: 1).toJson(),
        ttl: const Duration(hours: 1),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['fresh'],
        othersFollowerCountResult: 5,
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo
          .watchOthersFollowersCached('target')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isFalse);
      expect(events[0].data.pubkeys, ['stale']);
      expect(repo.getFollowersCallCount, 0);
    });

    test('forceRefresh skips cached emission', () async {
      await dao.write(
        key: 'others_followers_target',
        payload: const FollowersSnapshot(pubkeys: ['stale'], count: 1).toJson(),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['fresh'],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
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
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['bob_live'],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
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

    test('uses cacheFirst policy for fresh cached following lists', () async {
      await dao.write(
        key: 'others_following_target',
        payload: const FollowingSnapshot(pubkeys: ['stale'], count: 1).toJson(),
        ttl: const Duration(hours: 1),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['fresh'],
          count: 1,
        ),
      );

      final events = await repo
          .watchOthersFollowingCached('target')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isFalse);
      expect(events[0].data.pubkeys, ['stale']);
      expect(repo.getOthersFollowingCallCount, 0);
    });

    test('forceRefresh skips cached emission', () async {
      await dao.write(
        key: 'others_following_target',
        payload: const FollowingSnapshot(pubkeys: ['stale'], count: 1).toJson(),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
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
