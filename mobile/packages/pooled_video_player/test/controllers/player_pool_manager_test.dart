import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerTestFallbackValues);

  tearDown(() async {
    // Always reset the singleton after each test
    await cleanupPoolManager();
  });

  group('PlayerPoolManager', () {
    group('Singleton Pattern', () {
      group('initialize', () {
        test('creates singleton instance', () async {
          await initializeTestPoolManager();

          expect(PlayerPoolManager.isInitialized, true);
          expect(PlayerPoolManager.instance, isNotNull);
        });

        test('returns the instance', () async {
          final manager = await initializeTestPoolManager();

          expect(manager, same(PlayerPoolManager.instance));
        });

        test('auto-detects memory tier', () async {
          final manager = await initializeTestPoolManager(
            tier: MemoryTier.high,
          );

          // High tier should have specific config
          expect(
            manager.config.poolSize,
            MemoryTierConfig.highMemoryPoolSize,
          );
        });

        test('uses provided custom config values', () async {
          final manager = await initializeTestPoolManager(
            customConfig: const VideoPoolConfig(
              poolSize: 5,
              preloadAhead: 4,
              preloadBehind: 3,
              maxActivePlayers: 10,
            ),
          );

          expect(manager.config.poolSize, 5);
          expect(manager.config.preloadAhead, 4);
          expect(manager.config.preloadBehind, 3);
          expect(manager.config.maxActivePlayers, 10);
        });

        test('disposes existing instance before creating new', () async {
          await initializeTestPoolManager(tier: MemoryTier.low);
          final firstInstance = PlayerPoolManager.instance;

          await initializeTestPoolManager(tier: MemoryTier.high);
          final secondInstance = PlayerPoolManager.instance;

          expect(firstInstance, isNot(same(secondInstance)));
        });
      });

      group('instance', () {
        test('throws StateError before initialization', () {
          expect(
            () => PlayerPoolManager.instance,
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('not initialized'),
              ),
            ),
          );
        });

        test('returns singleton after initialization', () async {
          await initializeTestPoolManager();

          final instance1 = PlayerPoolManager.instance;
          final instance2 = PlayerPoolManager.instance;

          expect(instance1, same(instance2));
        });
      });

      group('isInitialized', () {
        test('returns false before initialization', () {
          expect(PlayerPoolManager.isInitialized, false);
        });

        test('returns true after initialization', () async {
          await initializeTestPoolManager();

          expect(PlayerPoolManager.isInitialized, true);
        });

        test('returns false after reset', () async {
          await initializeTestPoolManager();
          await PlayerPoolManager.reset();

          expect(PlayerPoolManager.isInitialized, false);
        });
      });

      group('reset', () {
        test('sets instance to null', () async {
          await initializeTestPoolManager();
          expect(PlayerPoolManager.isInitialized, true);

          await PlayerPoolManager.reset();

          expect(PlayerPoolManager.isInitialized, false);
        });

        test('allows reinitialization', () async {
          await initializeTestPoolManager(tier: MemoryTier.low);
          await PlayerPoolManager.reset();
          await initializeTestPoolManager(tier: MemoryTier.high);

          expect(PlayerPoolManager.isInitialized, true);
        });

        test('is safe to call when not initialized', () async {
          // Should not throw
          await PlayerPoolManager.reset();

          expect(PlayerPoolManager.isInitialized, false);
        });
      });
    });

    group('Tier Configuration', () {
      test('low tier uses correct pool size', () async {
        final manager = await initializeTestPoolManager(tier: MemoryTier.low);

        expect(manager.config.poolSize, MemoryTierConfig.lowMemoryPoolSize);
      });

      test('medium tier uses correct pool size', () async {
        final manager = await initializeTestPoolManager(
          tier: MemoryTier.medium,
        );

        expect(manager.config.poolSize, MemoryTierConfig.mediumMemoryPoolSize);
      });

      test('high tier uses correct pool size', () async {
        final manager = await initializeTestPoolManager(tier: MemoryTier.high);

        expect(manager.config.poolSize, MemoryTierConfig.highMemoryPoolSize);
      });

      test('low tier uses correct preloadAhead', () async {
        final manager = await initializeTestPoolManager(tier: MemoryTier.low);

        expect(
          manager.config.preloadAhead,
          MemoryTierConfig.lowMemoryPreloadAhead,
        );
      });

      test('high tier uses correct preloadAhead', () async {
        final manager = await initializeTestPoolManager(tier: MemoryTier.high);

        expect(
          manager.config.preloadAhead,
          MemoryTierConfig.highMemoryPreloadAhead,
        );
      });

      test('low tier uses correct maxActivePlayers', () async {
        final manager = await initializeTestPoolManager(tier: MemoryTier.low);

        expect(
          manager.config.maxActivePlayers,
          MemoryTierConfig.lowMemoryMaxActivePlayers,
        );
      });

      test('high tier uses correct maxActivePlayers', () async {
        final manager = await initializeTestPoolManager(tier: MemoryTier.high);

        expect(
          manager.config.maxActivePlayers,
          MemoryTierConfig.highMemoryMaxActivePlayers,
        );
      });
    });

    group('Feed Registration', () {
      test('registerFeed adds feed to set', () async {
        final manager = await initializeTestPoolManager();
        final videos = createTestVideos(3);

        final feed = VideoFeedController(feedId: 'test-feed', videos: videos);
        addTearDown(feed.dispose);

        // Feed auto-registers in constructor
        expect(manager.registeredFeeds, contains(feed));
      });

      test('unregisterFeed removes feed from set', () async {
        final manager = await initializeTestPoolManager();
        final videos = createTestVideos(3);

        final feed = VideoFeedController(feedId: 'test-feed', videos: videos);

        expect(manager.registeredFeeds, contains(feed));

        manager.unregisterFeed(feed);

        expect(manager.registeredFeeds, isNot(contains(feed)));

        feed.dispose();
      });

      test('registeredFeeds returns unmodifiable set', () async {
        final manager = await initializeTestPoolManager();

        final feeds = manager.registeredFeeds;

        expect(
          () => (feeds as Set).add(MockVideoFeedController()),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('Player Acquisition', () {
      test('totalActivePlayers starts at 0', () async {
        final manager = await initializeTestPoolManager();

        expect(manager.totalActivePlayers, 0);
      });

      test('canAcquireMore returns true when under maxActivePlayers', () async {
        final manager = await initializeTestPoolManager();

        expect(manager.canAcquireMore, true);
      });

      group('acquirePlayer', () {
        test('returns new lease for new video', () async {
          final manager = await initializeTestPoolManager();

          final lease = await manager.acquirePlayer(
            videoId: 'video-1',
            ownerId: 'owner-1',
          );

          expect(lease, isNotNull);
          expect(lease.videoId, 'video-1');
          expect(lease.ownerId, 'owner-1');
        });

        test('returns existing lease if already acquired', () async {
          final manager = await initializeTestPoolManager();

          final lease1 = await manager.acquirePlayer(
            videoId: 'video-1',
            ownerId: 'owner-1',
          );

          final lease2 = await manager.acquirePlayer(
            videoId: 'video-1',
            ownerId: 'owner-1',
          );

          expect(lease1, same(lease2));
        });

        test('assigns correct priority', () async {
          final manager = await initializeTestPoolManager();

          final lease = await manager.acquirePlayer(
            videoId: 'video-1',
            ownerId: 'owner-1',
            priority: PlayerPriority.current,
          );

          expect(lease.priority, PlayerPriority.current);
        });

        test('increments totalActivePlayers', () async {
          final manager = await initializeTestPoolManager();

          expect(manager.totalActivePlayers, 0);

          await manager.acquirePlayer(
            videoId: 'video-1',
            ownerId: 'owner-1',
          );

          expect(manager.totalActivePlayers, 1);
        });
      });
    });

    group('Lease Management', () {
      group('transferLease', () {
        test('updates lease ownership', () async {
          final manager = await initializeTestPoolManager();

          final lease = await manager.acquirePlayer(
            videoId: 'video-1',
            ownerId: 'feed-1',
          );

          expect(lease.ownerId, 'feed-1');

          manager.transferLease(lease: lease, newOwnerId: 'detail-page');

          expect(lease.ownerId, 'detail-page');
        });

        test('updates lease location in activeLeases', () async {
          final manager = await initializeTestPoolManager();

          final lease = await manager.acquirePlayer(
            videoId: 'video-1',
            ownerId: 'feed-1',
          );

          manager.transferLease(lease: lease, newOwnerId: 'detail-page');

          // Old key should not find the lease
          expect(manager.getLease('feed-1', 'video-1'), isNull);
          // New key should find the lease
          expect(manager.getLease('detail-page', 'video-1'), same(lease));
        });
      });

      group('releaseLease', () {
        test('removes lease from active leases', () async {
          final manager = await initializeTestPoolManager();

          final lease = await manager.acquirePlayer(
            videoId: 'video-1',
            ownerId: 'owner-1',
          );

          expect(manager.totalActivePlayers, 1);

          await manager.releaseLease(lease);

          expect(manager.totalActivePlayers, 0);
        });

        test('getLease returns null after release', () async {
          final manager = await initializeTestPoolManager();

          final lease = await manager.acquirePlayer(
            videoId: 'video-1',
            ownerId: 'owner-1',
          );

          await manager.releaseLease(lease);

          expect(manager.getLease('owner-1', 'video-1'), isNull);
        });
      });

      group('getLease', () {
        test('returns lease for existing ownerId:videoId', () async {
          final manager = await initializeTestPoolManager();

          final lease = await manager.acquirePlayer(
            videoId: 'video-1',
            ownerId: 'owner-1',
          );

          expect(manager.getLease('owner-1', 'video-1'), same(lease));
        });

        test('returns null for non-existent key', () async {
          final manager = await initializeTestPoolManager();

          expect(manager.getLease('unknown', 'unknown'), isNull);
        });
      });

      group('getLeasesForOwner', () {
        test('returns all leases for owner', () async {
          final manager = await initializeTestPoolManager();

          await manager.acquirePlayer(videoId: 'video-1', ownerId: 'feed-1');
          await manager.acquirePlayer(videoId: 'video-2', ownerId: 'feed-1');
          await manager.acquirePlayer(videoId: 'video-3', ownerId: 'feed-2');

          final feed1Leases = manager.getLeasesForOwner('feed-1');

          expect(feed1Leases.length, 2);
          expect(
            feed1Leases.map((l) => l.videoId),
            containsAll(['video-1', 'video-2']),
          );
        });

        test('returns empty list for unknown owner', () async {
          final manager = await initializeTestPoolManager();

          final leases = manager.getLeasesForOwner('unknown');

          expect(leases, isEmpty);
        });
      });
    });

    group('Eviction', () {
      group('requestEviction', () {
        test('returns true when canAcquireMore', () async {
          final manager = await initializeTestPoolManager();

          final result = await manager.requestEviction(
            requesterPriority: PlayerPriority.current,
            requesterId: 'requester',
          );

          expect(result, true);
        });
      });
    });

    group('Pool Access', () {
      test('poolSize returns correct value', () async {
        final manager = await initializeTestPoolManager(
          customConfig: const VideoPoolConfig(poolSize: 4),
        );

        expect(manager.poolSize, 4);
      });

      test('status returns correct PoolStatus snapshot', () async {
        final manager = await initializeTestPoolManager();

        final status = manager.status;

        expect(status, isA<PoolStatus>());
        expect(status.activeLeaseCount, 0);
        expect(status.registeredFeedCount, 0);
      });

      test('status reflects active leases', () async {
        final manager = await initializeTestPoolManager();

        await manager.acquirePlayer(videoId: 'video-1', ownerId: 'owner-1');

        final status = manager.status;

        expect(status.activeLeaseCount, 1);
      });
    });

    group('ChangeNotifier', () {
      test('notifies listeners on acquirePlayer', () async {
        final manager = await initializeTestPoolManager();

        var notified = false;
        manager.addListener(() => notified = true);

        await manager.acquirePlayer(videoId: 'video-1', ownerId: 'owner-1');

        expect(notified, true);
      });

      test('notifies listeners on releaseLease', () async {
        final manager = await initializeTestPoolManager();

        final lease = await manager.acquirePlayer(
          videoId: 'video-1',
          ownerId: 'owner-1',
        );

        var notified = false;
        manager.addListener(() => notified = true);

        await manager.releaseLease(lease);

        expect(notified, true);
      });

      test('notifies listeners on transferLease', () async {
        final manager = await initializeTestPoolManager();

        final lease = await manager.acquirePlayer(
          videoId: 'video-1',
          ownerId: 'feed-1',
        );

        var notified = false;
        manager.addListener(() => notified = true);

        manager.transferLease(lease: lease, newOwnerId: 'detail-page');

        expect(notified, true);
      });
    });
  });
}
