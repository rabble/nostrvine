// ABOUTME: Tests for PlayerPool controller
// ABOUTME: Validates singleton pattern, pool operations, and LRU eviction

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_helpers.dart';

class _MockPooledPlayer extends Mock implements PooledPlayer {}

class _FakeMedia extends Fake implements Media {}

void _setUpFallbacks() {
  registerFallbackValue(_FakeMedia());
  registerFallbackValue(Duration.zero);
  registerFallbackValue(PlaylistMode.single);
}

_MockPooledPlayer _createMockPooledPlayer() {
  final mockPooledPlayer = _MockPooledPlayer();
  final mockPlayer = createMockPlayer();
  final mockController = createMockVideoController();

  var recycled = false;

  when(() => mockPooledPlayer.player).thenReturn(mockPlayer);
  when(() => mockPooledPlayer.videoController).thenReturn(mockController);
  when(() => mockPooledPlayer.isDisposed).thenReturn(false);
  when(() => mockPooledPlayer.wasRecycled).thenAnswer((_) => recycled);
  when(mockPooledPlayer.clearRecycled).thenAnswer(
    (_) => recycled = false,
  );
  when(mockPooledPlayer.recycle).thenAnswer((_) => recycled = true);
  when(mockPooledPlayer.dispose).thenAnswer((_) async {});

  return mockPooledPlayer;
}

void main() {
  setUpAll(_setUpFallbacks);

  group('PlayerPool', () {
    tearDown(() async {
      await PlayerPool.reset();
    });

    group('singleton pattern', () {
      group('init', () {
        test('creates singleton instance', () async {
          await PlayerPool.init();

          expect(PlayerPool.isInitialized, isTrue);
          expect(PlayerPool.instance, isNotNull);
        });

        test('uses default config when not provided', () async {
          await PlayerPool.init();

          expect(PlayerPool.instance.maxPlayers, equals(5));
        });

        test('uses provided config', () async {
          await PlayerPool.init(config: const VideoPoolConfig(maxPlayers: 10));

          expect(PlayerPool.instance.maxPlayers, equals(10));
        });

        test('disposes existing instance when re-initializing', () async {
          await PlayerPool.init(config: const VideoPoolConfig(maxPlayers: 3));
          final oldInstance = PlayerPool.instance;

          await PlayerPool.init();

          expect(PlayerPool.instance, isNot(same(oldInstance)));
          expect(PlayerPool.instance.maxPlayers, equals(5));
        });
      });

      group('instance', () {
        test('returns singleton after init', () async {
          await PlayerPool.init();

          final instance1 = PlayerPool.instance;
          final instance2 = PlayerPool.instance;

          expect(identical(instance1, instance2), isTrue);
        });

        test('throws StateError when not initialized', () {
          expect(
            () => PlayerPool.instance,
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('PlayerPool not initialized'),
              ),
            ),
          );
        });

        test('returns same instance on multiple calls', () async {
          await PlayerPool.init();

          final instances = <PlayerPool>[];
          for (var i = 0; i < 10; i++) {
            instances.add(PlayerPool.instance);
          }

          expect(instances.every((i) => identical(i, instances.first)), isTrue);
        });
      });

      group('isInitialized', () {
        test('returns false before init', () {
          expect(PlayerPool.isInitialized, isFalse);
        });

        test('returns true after init', () async {
          await PlayerPool.init();

          expect(PlayerPool.isInitialized, isTrue);
        });

        test('returns false after reset', () async {
          await PlayerPool.init();
          await PlayerPool.reset();

          expect(PlayerPool.isInitialized, isFalse);
        });
      });

      group('reset', () {
        test('disposes singleton', () async {
          await PlayerPool.init();
          expect(PlayerPool.isInitialized, isTrue);

          await PlayerPool.reset();

          expect(PlayerPool.isInitialized, isFalse);
        });

        test('allows re-initialization after reset', () async {
          await PlayerPool.init(config: const VideoPoolConfig(maxPlayers: 3));
          await PlayerPool.reset();
          await PlayerPool.init(config: const VideoPoolConfig(maxPlayers: 7));

          expect(PlayerPool.instance.maxPlayers, equals(7));
        });

        test('can be called when not initialized', () async {
          await expectLater(PlayerPool.reset(), completes);
        });
      });

      group('instanceForTesting', () {
        test('getter returns current instance', () async {
          await PlayerPool.init();

          expect(PlayerPool.instanceForTesting, equals(PlayerPool.instance));
        });

        test('getter returns null when not initialized', () {
          expect(PlayerPool.instanceForTesting, isNull);
        });

        test('setter replaces instance', () async {
          await PlayerPool.init();
          final customPool = PlayerPool(maxPlayers: 3);

          PlayerPool.instanceForTesting = customPool;

          expect(PlayerPool.instance, equals(customPool));
        });

        test('setter accepts null', () async {
          await PlayerPool.init();

          PlayerPool.instanceForTesting = null;

          expect(PlayerPool.isInitialized, isFalse);
        });
      });
    });

    group('manual instantiation', () {
      test('creates isolated instance', () {
        final pool1 = PlayerPool(maxPlayers: 3);
        final pool2 = PlayerPool();

        expect(identical(pool1, pool2), isFalse);
        expect(pool1.maxPlayers, equals(3));
        expect(pool2.maxPlayers, equals(5));
      });

      test('uses default maxPlayers when not provided', () {
        final pool = PlayerPool();

        expect(pool.maxPlayers, equals(5));
      });

      test('uses provided maxPlayers', () {
        final pool = PlayerPool(maxPlayers: 10);

        expect(pool.maxPlayers, equals(10));
      });

      test('does not affect singleton', () async {
        await PlayerPool.init();
        final manualPool = PlayerPool(maxPlayers: 10);

        expect(PlayerPool.instance.maxPlayers, equals(5));
        expect(manualPool.maxPlayers, equals(10));
        expect(identical(PlayerPool.instance, manualPool), isFalse);
      });
    });

    group('pool operations', () {
      late TestablePlayerPool pool;
      late List<_MockPooledPlayer> createdPlayers;

      setUp(() {
        createdPlayers = [];
        pool = TestablePlayerPool(
          maxPlayers: 3,
          mockPlayerFactory: (url) {
            final player = _createMockPooledPlayer();
            createdPlayers.add(player);
            return player;
          },
        );
      });

      tearDown(() async {
        await pool.dispose();
      });

      group('getPlayer', () {
        test('creates new player for new URL', () async {
          final player = await pool.getPlayer('https://example.com/v1.mp4');

          expect(player, isNotNull);
          expect(createdPlayers.length, equals(1));
        });

        test('returns existing player for same URL', () async {
          final player1 = await pool.getPlayer('https://example.com/v1.mp4');
          final player2 = await pool.getPlayer('https://example.com/v1.mp4');

          expect(identical(player1, player2), isTrue);
          expect(createdPlayers.length, equals(1));
        });

        test('creates players up to maxPlayers', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');
          await pool.getPlayer('https://example.com/v3.mp4');

          expect(pool.playerCount, equals(3));
          expect(createdPlayers.length, equals(3));
        });

        test('mutes cached player to prevent audio leaks', () async {
          await pool.getPlayer('https://example.com/v1.mp4');

          // Request the same URL again — pool returns cached player.
          await pool.getPlayer('https://example.com/v1.mp4');

          // The cached player should have been muted before returning.
          verify(() => createdPlayers[0].player.setVolume(0)).called(1);
        });

        test('evicts LRU player when at capacity', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');
          await pool.getPlayer('https://example.com/v3.mp4');

          await pool.getPlayer('https://example.com/v4.mp4');

          expect(pool.playerCount, equals(3));
          expect(pool.hasPlayer('https://example.com/v1.mp4'), isFalse);
          expect(pool.hasPlayer('https://example.com/v4.mp4'), isTrue);
        });

        test('recycles evicted player instead of disposing', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');
          await pool.getPlayer('https://example.com/v3.mp4');

          final evictedPlayer = createdPlayers[0];

          await pool.getPlayer('https://example.com/v4.mp4');

          // Player is recycled (callbacks fired) but NOT disposed — native
          // resources are kept alive for reuse under the new URL.
          verify(evictedPlayer.recycle).called(1);
          verifyNever(evictedPlayer.dispose);
        });

        test('returns same native player instance under new URL', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');
          await pool.getPlayer('https://example.com/v3.mp4');

          // v1 is LRU; requesting v4 should recycle v1's player under v4.
          final player4 = await pool.getPlayer('https://example.com/v4.mp4');

          expect(identical(player4, createdPlayers[0]), isTrue);
          expect(createdPlayers.length, equals(3)); // no new player created
        });

        test(
          'stops recycled player before reuse to clear media surface',
          () async {
            await pool.getPlayer('https://example.com/v1.mp4');
            await pool.getPlayer('https://example.com/v2.mp4');
            await pool.getPlayer('https://example.com/v3.mp4');

            final evictedPlayer = createdPlayers[0];

            await pool.getPlayer('https://example.com/v4.mp4');

            // stop() must be called so the previous video's last frame is
            // cleared from the surface before the recycled player is exposed
            // to the UI — preventing a wrong-frame flash.
            // ignore: unnecessary_lambdas, chained mock calls need lambda for mocktail
            verify(() => evictedPlayer.player.stop()).called(1);
          },
        );
      });

      group('hasPlayer', () {
        test('returns false for unknown URL', () {
          expect(pool.hasPlayer('https://example.com/unknown.mp4'), isFalse);
        });

        test('returns true for known URL', () async {
          await pool.getPlayer('https://example.com/v1.mp4');

          expect(pool.hasPlayer('https://example.com/v1.mp4'), isTrue);
        });

        test('returns false after player is evicted', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');
          await pool.getPlayer('https://example.com/v3.mp4');
          await pool.getPlayer('https://example.com/v4.mp4');

          expect(pool.hasPlayer('https://example.com/v1.mp4'), isFalse);
        });

        test('returns false after player is released', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.release('https://example.com/v1.mp4');

          expect(pool.hasPlayer('https://example.com/v1.mp4'), isFalse);
        });
      });

      group('getExistingPlayer', () {
        test('returns null for unknown URL', () {
          expect(
            pool.getExistingPlayer('https://example.com/unknown.mp4'),
            isNull,
          );
        });

        test('returns player for known URL', () async {
          final created = await pool.getPlayer('https://example.com/v1.mp4');

          final existing = pool.getExistingPlayer('https://example.com/v1.mp4');

          expect(identical(created, existing), isTrue);
        });

        test('marks player as recently used', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');
          await pool.getPlayer('https://example.com/v3.mp4');

          // Touch v1 to make it recently used
          pool.getExistingPlayer('https://example.com/v1.mp4');

          // Should evict v2 (oldest after touch), not v1
          await pool.getPlayer('https://example.com/v4.mp4');

          expect(pool.hasPlayer('https://example.com/v1.mp4'), isTrue);
          expect(pool.hasPlayer('https://example.com/v2.mp4'), isFalse);
        });
      });

      group('release', () {
        test('removes player from pool', () async {
          await pool.getPlayer('https://example.com/v1.mp4');

          await pool.release('https://example.com/v1.mp4');

          expect(pool.hasPlayer('https://example.com/v1.mp4'), isFalse);
          expect(pool.playerCount, equals(0));
        });

        test('disposes released player', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          final player = createdPlayers[0];

          await pool.release('https://example.com/v1.mp4');

          verify(player.dispose).called(1);
        });

        test('does nothing for unknown URL', () async {
          await expectLater(
            pool.release('https://example.com/unknown.mp4'),
            completes,
          );
        });
      });

      group('playerCount', () {
        test('returns 0 initially', () {
          expect(pool.playerCount, equals(0));
        });

        test('increments when player added', () async {
          await pool.getPlayer('https://example.com/v1.mp4');

          expect(pool.playerCount, equals(1));
        });

        test('stays at max when player evicted', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');
          await pool.getPlayer('https://example.com/v3.mp4');

          expect(pool.playerCount, equals(3));

          await pool.getPlayer('https://example.com/v4.mp4');

          expect(pool.playerCount, equals(3));
        });

        test('decrements when player released', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');

          expect(pool.playerCount, equals(2));

          await pool.release('https://example.com/v1.mp4');

          expect(pool.playerCount, equals(1));
        });

        test('returns 0 after dispose', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');

          await pool.dispose();

          expect(pool.playerCount, equals(0));
        });
      });

      group('LRU eviction', () {
        test('evicts oldest player first', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');
          await pool.getPlayer('https://example.com/v3.mp4');

          await pool.getPlayer('https://example.com/v4.mp4');

          expect(pool.hasPlayer('https://example.com/v1.mp4'), isFalse);
          expect(pool.hasPlayer('https://example.com/v2.mp4'), isTrue);
          expect(pool.hasPlayer('https://example.com/v3.mp4'), isTrue);
          expect(pool.hasPlayer('https://example.com/v4.mp4'), isTrue);
        });

        test('touch moves player to end of LRU', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');
          await pool.getPlayer('https://example.com/v3.mp4');

          // Touch v1 to move it to end
          await pool.getPlayer('https://example.com/v1.mp4');

          // v2 should be evicted now, not v1
          await pool.getPlayer('https://example.com/v4.mp4');

          expect(pool.hasPlayer('https://example.com/v1.mp4'), isTrue);
          expect(pool.hasPlayer('https://example.com/v2.mp4'), isFalse);
        });

        test('correct eviction order with multiple players', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');
          await pool.getPlayer('https://example.com/v3.mp4');

          // Touch in order: v2, v3, v1
          await pool.getPlayer('https://example.com/v2.mp4');
          await pool.getPlayer('https://example.com/v3.mp4');
          await pool.getPlayer('https://example.com/v1.mp4');

          // Now order should be: v2, v3, v1 (v2 is oldest)
          await pool.getPlayer('https://example.com/v4.mp4');

          expect(pool.hasPlayer('https://example.com/v2.mp4'), isFalse);
          expect(pool.hasPlayer('https://example.com/v3.mp4'), isTrue);
          expect(pool.hasPlayer('https://example.com/v1.mp4'), isTrue);
          expect(pool.hasPlayer('https://example.com/v4.mp4'), isTrue);
        });
      });

      group('stopAll', () {
        test('stops all non-disposed players', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');

          pool.stopAll();

          for (final player in createdPlayers) {
            // ignore: unnecessary_lambdas, chained mock calls need lambda for mocktail
            verify(() => player.player.stop()).called(1);
          }
        });

        test('skips disposed players', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');

          when(() => createdPlayers[0].isDisposed).thenReturn(true);

          pool.stopAll();

          verifyNever(() => createdPlayers[0].player.stop());
          verify(() => createdPlayers[1].player.stop()).called(1);
        });

        test('handles empty pool', () {
          expect(() => pool.stopAll(), returnsNormally);
        });

        test('handles exception during stop gracefully', () async {
          await pool.getPlayer('https://example.com/v1.mp4');

          final firstPlayer = createdPlayers[0].player;

          when(firstPlayer.stop).thenThrow(Exception('stop failed'));

          expect(() => pool.stopAll(), returnsNormally);
        });
      });

      group('releaseAll', () {
        test(
          'starts disposing all players before awaiting any one disposal',
          () async {
            await pool.getPlayer('https://example.com/v1.mp4');
            await pool.getPlayer('https://example.com/v2.mp4');

            final firstDispose = Completer<void>();
            final secondDisposeStarted = Completer<void>();
            Future<void>? releaseFuture;

            when(createdPlayers[0].dispose).thenAnswer(
              (_) => firstDispose.future,
            );
            when(createdPlayers[1].dispose).thenAnswer((_) async {
              secondDisposeStarted.complete();
            });

            addTearDown(() async {
              if (!firstDispose.isCompleted) {
                firstDispose.complete();
              }
              await releaseFuture;
            });

            releaseFuture = pool.releaseAll();
            await Future<void>.delayed(Duration.zero);

            expect(secondDisposeStarted.isCompleted, isTrue);

            firstDispose.complete();
            await releaseFuture;
          },
        );
      });

      group('dispose', () {
        test('disposes all players', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');

          await pool.dispose();

          for (final player in createdPlayers) {
            verify(player.dispose).called(1);
          }
        });

        test('clears player count', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');

          await pool.dispose();

          expect(pool.playerCount, equals(0));
        });

        test('can be called multiple times', () async {
          await pool.getPlayer('https://example.com/v1.mp4');

          await pool.dispose();
          await pool.dispose();
          await pool.dispose();

          verify(() => createdPlayers[0].dispose()).called(1);
        });

        test('skips already disposed players', () async {
          await pool.getPlayer('https://example.com/v1.mp4');
          await pool.getPlayer('https://example.com/v2.mp4');

          when(() => createdPlayers[0].isDisposed).thenReturn(true);

          await pool.dispose();

          verifyNever(() => createdPlayers[0].dispose());
          verify(() => createdPlayers[1].dispose()).called(1);
        });
      });

      group('release with disposed player', () {
        test('skips disposing already disposed player', () async {
          await pool.getPlayer('https://example.com/v1.mp4');

          when(() => createdPlayers[0].isDisposed).thenReturn(true);

          await pool.release('https://example.com/v1.mp4');

          verifyNever(() => createdPlayers[0].dispose());
          expect(pool.hasPlayer('https://example.com/v1.mp4'), isFalse);
        });
      });

      group('eviction with disposed player', () {
        test(
          'skips recycling already disposed player and creates a new one',
          () async {
            await pool.getPlayer('https://example.com/v1.mp4');
            await pool.getPlayer('https://example.com/v2.mp4');
            await pool.getPlayer('https://example.com/v3.mp4');

            // Mark the LRU player as already disposed.
            when(() => createdPlayers[0].isDisposed).thenReturn(true);

            await pool.getPlayer('https://example.com/v4.mp4');

            // Disposed player must not be recycled or double-disposed.
            verifyNever(() => createdPlayers[0].recycle());
            verifyNever(() => createdPlayers[0].dispose());
            expect(pool.hasPlayer('https://example.com/v1.mp4'), isFalse);
            // A fresh player was created as fallback (createdPlayers[3]).
            expect(createdPlayers.length, equals(4));
            expect(pool.hasPlayer('https://example.com/v4.mp4'), isTrue);
          },
        );

        group('testing hooks and edge cases', () {
          test(
            'drainPendingOperations waits for in-flight getPlayer lock',
            () async {
              final delayedPool = TestablePlayerPool(
                maxPlayers: 1,
                serialized: true,
                mockPlayerFactory: (url) {
                  final player = _createMockPooledPlayer();
                  createdPlayers.add(player);
                  return player;
                },
              );
              addTearDown(delayedPool.dispose);

              await delayedPool.getPlayer('https://example.com/v1.mp4');

              final firstPlayer = createdPlayers[0].player;

              final stopCompleter = Completer<void>();
              when(firstPlayer.stop).thenAnswer(
                (_) => stopCompleter.future,
              );

              final inFlight = delayedPool.getPlayer(
                'https://example.com/v2.mp4',
              );
              await Future<void>.delayed(Duration.zero);

              var drained = false;
              final drainFuture = delayedPool.drainPendingOperations().then(
                (_) => drained = true,
              );

              await Future<void>.delayed(Duration.zero);
              expect(drained, isFalse);

              stopCompleter.complete();
              await inFlight;
              await drainFuture;
              expect(drained, isTrue);
            },
          );

          test('getPlayerInternal exposes internal lookup path', () async {
            final player = await pool.getPlayerInternal(
              'https://example.com/internal.mp4',
            );

            expect(player, isNotNull);
            expect(pool.hasPlayer('https://example.com/internal.mp4'), isTrue);
          });

          test('getPlayerInternal throws when pool is disposed', () async {
            await pool.dispose();

            await expectLater(
              pool.getPlayerInternal('https://example.com/disposed.mp4'),
              throwsA(isA<StateError>()),
            );
          });

          test(
            'recycle continues when stopping evicted player throws',
            () async {
              await pool.getPlayer('https://example.com/v1.mp4');
              await pool.getPlayer('https://example.com/v2.mp4');
              await pool.getPlayer('https://example.com/v3.mp4');

              final firstPlayer = createdPlayers[0].player;

              when(firstPlayer.stop).thenThrow(
                Exception('stop failed'),
              );

              final recycled = await pool.getPlayer(
                'https://example.com/v4.mp4',
              );

              expect(recycled, isNotNull);
              expect(pool.hasPlayer('https://example.com/v4.mp4'), isTrue);
              verify(createdPlayers[0].recycle).called(1);
            },
          );
        });

        test(
          'skips multiple disposed LRU entries in a row and creates a new '
          'player',
          () async {
            // Use a larger pool so we can have multiple disposed LRU entries
            // without the pool dropping below capacity after each removal.
            // pool (maxPlayers=3) starts full; v1 and v2 are disposed.
            // Removing disposed v1 drops the count to 2 (< maxPlayers=3),
            // making room for v4 without needing to evict further.
            // This test verifies that neither disposed entry is recycled or
            // double-disposed, and that a fresh player is allocated as
            // fallback.
            await pool.getPlayer('https://example.com/v1.mp4');
            await pool.getPlayer('https://example.com/v2.mp4');
            await pool.getPlayer('https://example.com/v3.mp4');

            // Mark v1 (LRU) and v2 as already disposed.
            when(() => createdPlayers[0].isDisposed).thenReturn(true);
            when(() => createdPlayers[1].isDisposed).thenReturn(true);

            // Request v4 — _recycleLru skips disposed v1 (pool now has room),
            // so no further eviction occurs and a fresh player is created.
            await pool.getPlayer('https://example.com/v4.mp4');

            // Neither disposed entry must be recycled or double-disposed.
            verifyNever(() => createdPlayers[0].recycle());
            verifyNever(() => createdPlayers[0].dispose());
            verifyNever(() => createdPlayers[1].recycle());
            verifyNever(() => createdPlayers[1].dispose());

            // v3 (live LRU) was not touched because the pool had room after
            // the disposed v1 was removed.
            verifyNever(() => createdPlayers[2].recycle());

            // A fresh player was created as fallback.
            expect(createdPlayers.length, equals(4));
            expect(pool.hasPlayer('https://example.com/v1.mp4'), isFalse);
            expect(pool.hasPlayer('https://example.com/v4.mp4'), isTrue);
          },
        );
      });
    });

    group('serialized getPlayer', () {
      test('concurrent getPlayer calls do not over-evict', () async {
        final createdCount = <int>[0];
        final serializedPool = _SerializedTestPool(
          maxPlayers: 3,
          onCreatePlayer: () {
            createdCount[0]++;
            return _createMockPooledPlayer();
          },
        );
        addTearDown(serializedPool.dispose);

        // Fire 5 concurrent getPlayer calls (exceeds maxPlayers=3).
        // With serialization, the pool should evict exactly 2 LRU
        // players (to make room for URLs 4 and 5), ending at exactly
        // maxPlayers=3.
        final futures = [
          serializedPool.getPlayer('https://example.com/v1.mp4'),
          serializedPool.getPlayer('https://example.com/v2.mp4'),
          serializedPool.getPlayer('https://example.com/v3.mp4'),
          serializedPool.getPlayer('https://example.com/v4.mp4'),
          serializedPool.getPlayer('https://example.com/v5.mp4'),
        ];

        await Future.wait(futures);

        expect(serializedPool.playerCount, equals(3));
      });

      test('serialization does not deadlock on same-URL calls', () async {
        final serializedPool = _SerializedTestPool(
          maxPlayers: 3,
          onCreatePlayer: _createMockPooledPlayer,
        );
        addTearDown(serializedPool.dispose);

        // Two concurrent calls for the same URL should not deadlock.
        final futures = [
          serializedPool.getPlayer('https://example.com/v1.mp4'),
          serializedPool.getPlayer('https://example.com/v1.mp4'),
        ];

        // This should complete without hanging.
        final results = await Future.wait(futures);

        // Both should return the same player instance.
        expect(identical(results[0], results[1]), isTrue);
        expect(serializedPool.playerCount, equals(1));
      });

      test(
        'getPlayer does not return until stop() completes on recycled player '
        '— ordering guarantee prevents wrong-frame flash',
        () async {
          // Use a Completer to simulate a slow stop() on the LRU player.
          // getPlayer() must not resolve until stop() completes, proving
          // the surface is cleared before the caller can expose the
          // recycled VideoController to the UI via _notifyIndex.
          final stopCompleter = Completer<void>();
          var stopCompleted = false;

          // Track how many players have been created so we can stub only
          // the first one (the future LRU) with a slow stop().
          var playerIndex = 0;
          final orderedPool = _SerializedTestPool(
            maxPlayers: 2,
            onCreatePlayer: () {
              final mock = _createMockPooledPlayer();
              if (playerIndex == 0) {
                // Capture the inner Player mock directly (before any
                // when() call that could confuse mocktail's recording).
                final innerPlayer = mock.player;
                // Override stop() on the first (LRU) player to block on
                // stopCompleter — simulating a slow native surface clear.
                when(innerPlayer.stop).thenAnswer((_) async {
                  await stopCompleter.future;
                  stopCompleted = true;
                });
              }
              playerIndex++;
              return mock;
            },
          );
          addTearDown(orderedPool.dispose);

          // Fill pool to capacity (maxPlayers=2).
          await orderedPool.getPlayer('https://example.com/v1.mp4');
          await orderedPool.getPlayer('https://example.com/v2.mp4');

          // Requesting v3 will recycle v1 (LRU). _recycleLru() awaits
          // stop() on v1's player before returning.
          var getPlayerReturned = false;
          final getFuture = orderedPool
              .getPlayer('https://example.com/v3.mp4')
              .then((p) => getPlayerReturned = true);

          // stop() is still blocked — getPlayer() must not have returned.
          await Future<void>.delayed(Duration.zero);
          expect(stopCompleted, isFalse);
          expect(getPlayerReturned, isFalse);

          // Unblock stop() — getPlayer() must now complete.
          stopCompleter.complete();
          await getFuture;

          expect(stopCompleted, isTrue);
          expect(getPlayerReturned, isTrue);
        },
      );
    });
  });
}

/// A [PlayerPool] subclass that uses mock players but inherits
/// the real [getPlayer] serialization logic.
class _SerializedTestPool extends PlayerPool {
  _SerializedTestPool({required this.onCreatePlayer, super.maxPlayers});

  final _MockPooledPlayer Function() onCreatePlayer;

  @override
  Future<PooledPlayer> createPlayer() async {
    return onCreatePlayer();
  }
}
