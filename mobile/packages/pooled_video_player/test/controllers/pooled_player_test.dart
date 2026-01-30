import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/mocks.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUpAll(setUpMocktail);

  group('PooledPlayer', () {
    late MockPlayer mockPlayer;
    late MockVideoController mockVideoController;

    setUp(() {
      mockPlayer = createMockPlayer();
      mockVideoController = createMockVideoController();
    });

    group('constructor', () {
      test('creates instance with player and videoController', () {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        expect(pooledPlayer.player, equals(mockPlayer));
        expect(pooledPlayer.videoController, equals(mockVideoController));
      });

      test('isDisposed is false initially', () {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        expect(pooledPlayer.isDisposed, isFalse);
      });
    });

    group('dispose', () {
      test('stops player before disposing', () async {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        await pooledPlayer.dispose();

        verify(() => mockPlayer.stop()).called(1);
      });

      test('disposes player', () async {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        await pooledPlayer.dispose();

        verify(() => mockPlayer.dispose()).called(1);
      });

      test('sets isDisposed to true', () async {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        await pooledPlayer.dispose();

        expect(pooledPlayer.isDisposed, isTrue);
      });

      test('can be called multiple times safely', () async {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        await pooledPlayer.dispose();
        await pooledPlayer.dispose();
        await pooledPlayer.dispose();

        // Should only be called once due to isDisposed check
        verify(() => mockPlayer.stop()).called(1);
        verify(() => mockPlayer.dispose()).called(1);
      });

      test('handles player.stop() exception gracefully', () async {
        when(() => mockPlayer.stop()).thenThrow(Exception('Stop failed'));

        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        // Should not throw
        await expectLater(pooledPlayer.dispose(), completes);
        expect(pooledPlayer.isDisposed, isTrue);
      });

      test('handles player.dispose() exception gracefully', () async {
        when(() => mockPlayer.dispose()).thenThrow(Exception('Dispose failed'));

        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        // Should not throw
        await expectLater(pooledPlayer.dispose(), completes);
        expect(pooledPlayer.isDisposed, isTrue);
      });
    });

    group('isDisposed', () {
      test('returns false before dispose', () {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        expect(pooledPlayer.isDisposed, isFalse);
      });

      test('returns true after dispose', () async {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        await pooledPlayer.dispose();

        expect(pooledPlayer.isDisposed, isTrue);
      });
    });
  });
}
