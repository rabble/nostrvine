import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpAll(registerTestFallbackValues);

  group('PooledPlayer', () {
    late MockPlayer mockPlayer;
    late MockVideoController mockVideoController;
    late PooledPlayer pooledPlayer;

    setUp(() {
      mockPlayer = MockPlayer();
      mockVideoController = MockVideoController();

      // Stub required methods
      when(mockPlayer.stop).thenAnswer((_) async {});
      when(mockPlayer.play).thenAnswer((_) async {});
      when(mockPlayer.pause).thenAnswer((_) async {});
      when(mockPlayer.dispose).thenAnswer((_) async {});
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

      pooledPlayer = PooledPlayer(
        player: mockPlayer,
        videoController: mockVideoController,
      );
    });

    group('Constructor', () {
      test('creates with player and videoController', () {
        expect(pooledPlayer.player, mockPlayer);
        expect(pooledPlayer.videoController, mockVideoController);
      });

      test('sets lastUsed to approximately now', () {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        final after = DateTime.now().add(const Duration(seconds: 1));

        expect(pooledPlayer.lastUsed.isAfter(before), true);
        expect(pooledPlayer.lastUsed.isBefore(after), true);
      });

      test('isDisposed starts as false', () {
        expect(pooledPlayer.isDisposed, false);
      });
    });

    group('reset', () {
      test('calls player.stop()', () async {
        await pooledPlayer.reset();

        verify(mockPlayer.stop).called(1);
      });

      test('calls player.setVolume(100)', () async {
        await pooledPlayer.reset();

        verify(() => mockPlayer.setVolume(100)).called(1);
      });

      test('updates lastUsed', () async {
        final beforeReset = pooledPlayer.lastUsed;

        // Small delay to ensure time difference
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await pooledPlayer.reset();

        expect(
          pooledPlayer.lastUsed.isAfter(beforeReset) ||
              pooledPlayer.lastUsed.isAtSameMomentAs(beforeReset),
          true,
        );
      });

      test('no-op if isDisposed', () async {
        pooledPlayer.isDisposed = true;

        await pooledPlayer.reset();

        verifyNever(mockPlayer.stop);
        verifyNever(() => mockPlayer.setVolume(any()));
      });
    });

    group('safeDispose', () {
      test('sets isDisposed to true', () async {
        expect(pooledPlayer.isDisposed, false);

        await pooledPlayer.safeDispose();

        expect(pooledPlayer.isDisposed, true);
      });

      test('calls player.stop() before dispose', () async {
        await pooledPlayer.safeDispose();

        verifyInOrder([mockPlayer.stop, mockPlayer.dispose]);
      });

      test('calls player.dispose()', () async {
        await pooledPlayer.safeDispose();

        verify(mockPlayer.dispose).called(1);
      });

      test('handles already disposed gracefully', () async {
        pooledPlayer.isDisposed = true;

        // Should not throw
        await pooledPlayer.safeDispose();

        verifyNever(mockPlayer.stop);
        verifyNever(mockPlayer.dispose);
      });
    });

    group('lastUsed', () {
      test('can be updated', () {
        final newTime = DateTime(2025);
        pooledPlayer.lastUsed = newTime;

        expect(pooledPlayer.lastUsed, newTime);
      });
    });
  });

  group('PlayerPool', () {
    group('Constructor', () {
      test('has default maxPoolSize of 3', () {
        final pool = PlayerPool();
        expect(pool.maxPoolSize, 3);
      });

      test('has default maxTotalPlayers of 7', () {
        final pool = PlayerPool();
        expect(pool.maxTotalPlayers, 7);
      });

      test('accepts custom maxPoolSize', () {
        final pool = PlayerPool(maxPoolSize: 5);
        expect(pool.maxPoolSize, 5);
      });

      test('accepts custom maxTotalPlayers', () {
        final pool = PlayerPool(maxTotalPlayers: 10);
        expect(pool.maxTotalPlayers, 10);
      });

      test('accepts custom bufferSize', () {
        // BufferSize is internal, but we can verify construction doesn't fail
        final pool = PlayerPool(bufferSize: 64 * 1024 * 1024);
        expect(pool, isNotNull);
      });
    });

    group('State tracking', () {
      test('totalPlayers starts at 0', () {
        final pool = PlayerPool();
        expect(pool.totalPlayers, 0);
      });

      test('availableCount starts at 0', () {
        final pool = PlayerPool();
        expect(pool.availableCount, 0);
      });

      test('inUseCount starts at 0', () {
        final pool = PlayerPool();
        expect(pool.inUseCount, 0);
      });

      test('totalPlayers equals availableCount plus inUseCount', () {
        final pool = PlayerPool();
        expect(pool.totalPlayers, pool.availableCount + pool.inUseCount);
      });
    });

    group('updatePoolSize', () {
      test('updates maxPoolSize', () async {
        final pool = PlayerPool();
        expect(pool.maxPoolSize, 3);

        await pool.updatePoolSize(5);
        expect(pool.maxPoolSize, 5);
      });

      test('can decrease maxPoolSize', () async {
        final pool = PlayerPool(maxPoolSize: 5);
        await pool.updatePoolSize(2);
        expect(pool.maxPoolSize, 2);
      });

      test('can increase maxPoolSize', () async {
        final pool = PlayerPool(maxPoolSize: 2);
        await pool.updatePoolSize(5);
        expect(pool.maxPoolSize, 5);
      });
    });

    group('shrinkTo', () {
      test('does nothing when pool is empty', () async {
        final pool = PlayerPool();
        await pool.shrinkTo(0);
        expect(pool.availableCount, 0);
      });

      test('does nothing when already at or below target', () async {
        final pool = PlayerPool();
        // Pool starts empty (0 available)
        await pool.shrinkTo(5);
        expect(pool.availableCount, 0);
      });
    });

    group('dispose', () {
      test('clears all players', () async {
        final pool = PlayerPool();
        await pool.dispose();
        expect(pool.totalPlayers, 0);
        expect(pool.availableCount, 0);
        expect(pool.inUseCount, 0);
      });

      test('is idempotent (can be called multiple times)', () async {
        final pool = PlayerPool();
        await pool.dispose();
        // Should not throw
        await pool.dispose();
        expect(pool.totalPlayers, 0);
      });
    });

    group('acquire', () {
      test('throws StateError when disposed', () async {
        final pool = PlayerPool();
        await pool.dispose();

        expect(
          pool.acquire,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('disposed'),
            ),
          ),
        );
      });
    });

    group('release', () {
      test('does nothing when pool is disposed', () async {
        final pool = PlayerPool();
        await pool.dispose();

        final mockPlayer = MockPlayer();
        final mockVideoController = MockVideoController();
        when(mockPlayer.stop).thenAnswer((_) async {});
        when(mockPlayer.dispose).thenAnswer((_) async {});
        when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        // Should not throw
        await pool.release(pooledPlayer);
      });

      test('does nothing for player never acquired from pool', () async {
        final pool = PlayerPool();

        final mockPlayer = MockPlayer();
        final mockVideoController = MockVideoController();
        when(mockPlayer.stop).thenAnswer((_) async {});
        when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        // Should not throw - player wasn't from this pool
        await pool.release(pooledPlayer);

        // Player should not be added to pool
        expect(pool.availableCount, 0);
      });
    });

    group('prewarm', () {
      test('does nothing when disposed', () async {
        final pool = PlayerPool();
        await pool.dispose();

        await pool.prewarm(3);

        expect(pool.availableCount, 0);
      });

      test('does nothing when count is 0', () async {
        final pool = PlayerPool();
        await pool.prewarm(0);
        expect(pool.availableCount, 0);
      });
    });
  });
}
