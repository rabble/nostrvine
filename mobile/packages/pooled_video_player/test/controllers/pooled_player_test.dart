// ABOUTME: Tests for PooledPlayer controller
// ABOUTME: Validates player wrapper lifecycle and dispose behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

class _MockDivineVideoPlayerController extends Mock
    implements DivineVideoPlayerController {}

void main() {
  group('PooledPlayer', () {
    late _MockDivineVideoPlayerController mockController;

    setUp(() {
      mockController = _MockDivineVideoPlayerController();
      when(mockController.stop).thenAnswer((_) async {});
      when(mockController.dispose).thenAnswer((_) async {});
    });

    group('constructor', () {
      test('creates instance with controller', () {
        final pooledPlayer = PooledPlayer(controller: mockController);

        expect(pooledPlayer.controller, equals(mockController));
      });

      test('isDisposed is false initially', () {
        final pooledPlayer = PooledPlayer(controller: mockController);

        expect(pooledPlayer.isDisposed, isFalse);
      });
    });

    group('dispose', () {
      test('stops controller before disposing', () async {
        final pooledPlayer = PooledPlayer(controller: mockController);

        await pooledPlayer.dispose();

        verify(() => mockController.stop()).called(1);
      });

      test('disposes controller', () async {
        final pooledPlayer = PooledPlayer(controller: mockController);

        await pooledPlayer.dispose();

        verify(() => mockController.dispose()).called(1);
      });

      test('sets isDisposed to true', () async {
        final pooledPlayer = PooledPlayer(controller: mockController);

        await pooledPlayer.dispose();

        expect(pooledPlayer.isDisposed, isTrue);
      });

      test('can be called multiple times safely', () async {
        final pooledPlayer = PooledPlayer(controller: mockController);

        await pooledPlayer.dispose();
        await pooledPlayer.dispose();
        await pooledPlayer.dispose();

        verify(() => mockController.stop()).called(1);
        verify(() => mockController.dispose()).called(1);
      });

      test('handles controller.stop() exception gracefully', () async {
        when(() => mockController.stop()).thenThrow(Exception('Stop failed'));

        final pooledPlayer = PooledPlayer(controller: mockController);

        await expectLater(pooledPlayer.dispose(), completes);
        expect(pooledPlayer.isDisposed, isTrue);
      });

      test('handles controller.dispose() exception gracefully', () async {
        when(
          () => mockController.dispose(),
        ).thenThrow(Exception('Dispose failed'));

        final pooledPlayer = PooledPlayer(controller: mockController);

        await expectLater(pooledPlayer.dispose(), completes);
        expect(pooledPlayer.isDisposed, isTrue);
      });
    });

    group('isDisposed', () {
      test('returns false before dispose', () {
        final pooledPlayer = PooledPlayer(controller: mockController);

        expect(pooledPlayer.isDisposed, isFalse);
      });

      test('returns true after dispose', () async {
        final pooledPlayer = PooledPlayer(controller: mockController);

        await pooledPlayer.dispose();

        expect(pooledPlayer.isDisposed, isTrue);
      });
    });

    group('onEvictedCallback', () {
      test('invokes callback on dispose', () async {
        final pooledPlayer = PooledPlayer(controller: mockController);

        var callCount = 0;
        pooledPlayer.addOnEvictedCallback(() => callCount++);

        await pooledPlayer.dispose();

        expect(callCount, equals(1));
      });

      test('invokes multiple callbacks on dispose', () async {
        final pooledPlayer = PooledPlayer(controller: mockController);

        final calls = <String>[];
        pooledPlayer
          ..addOnEvictedCallback(() => calls.add('a'))
          ..addOnEvictedCallback(() => calls.add('b'));

        await pooledPlayer.dispose();

        expect(calls, equals(['a', 'b']));
      });

      test('invokes callbacks before stopping native controller', () async {
        final pooledPlayer = PooledPlayer(controller: mockController);

        var wasDisposedInCallback = false;
        pooledPlayer.addOnEvictedCallback(() {
          wasDisposedInCallback = pooledPlayer.isDisposed;
          verifyNever(() => mockController.stop());
        });

        await pooledPlayer.dispose();

        expect(wasDisposedInCallback, isTrue);
      });

      test('does not invoke callbacks on second dispose', () async {
        final pooledPlayer = PooledPlayer(controller: mockController);

        var callCount = 0;
        pooledPlayer.addOnEvictedCallback(() => callCount++);

        await pooledPlayer.dispose();
        await pooledPlayer.dispose();

        expect(callCount, equals(1));
      });

      test('removed callback is not invoked', () async {
        final pooledPlayer = PooledPlayer(controller: mockController);

        var callCount = 0;
        void callback() => callCount++;
        pooledPlayer
          ..addOnEvictedCallback(callback)
          ..removeOnEvictedCallback(callback);

        await pooledPlayer.dispose();

        expect(callCount, equals(0));
      });

      test('clears callbacks after dispose', () async {
        final pooledPlayer = PooledPlayer(controller: mockController);

        var callCount = 0;
        pooledPlayer.addOnEvictedCallback(() => callCount++);

        await pooledPlayer.dispose();

        expect(callCount, equals(1));
      });
    });

    group('recycle', () {
      test('invokes callbacks synchronously', () {
        final pooledPlayer = PooledPlayer(controller: mockController);

        var callCount = 0;
        pooledPlayer
          ..addOnEvictedCallback(() => callCount++)
          ..recycle();

        expect(callCount, equals(1));
      });

      test('invokes multiple callbacks in registration order', () {
        final pooledPlayer = PooledPlayer(controller: mockController);

        final calls = <String>[];
        pooledPlayer
          ..addOnEvictedCallback(() => calls.add('a'))
          ..addOnEvictedCallback(() => calls.add('b'))
          ..recycle();

        expect(calls, equals(['a', 'b']));
      });

      test('does not set isDisposed', () {
        final pooledPlayer = PooledPlayer(controller: mockController)
          ..recycle();

        expect(pooledPlayer.isDisposed, isFalse);
      });

      test('does not call controller.stop() or controller.dispose()', () {
        PooledPlayer(controller: mockController).recycle();

        verifyNever(() => mockController.stop());
        verifyNever(() => mockController.dispose());
      });

      test('clears callbacks after recycle', () {
        final pooledPlayer = PooledPlayer(controller: mockController);

        var callCount = 0;
        pooledPlayer
          ..addOnEvictedCallback(() => callCount++)
          ..recycle()
          ..recycle();

        expect(callCount, equals(1));
      });

      test('is a no-op if already disposed', () async {
        final pooledPlayer = PooledPlayer(controller: mockController);

        var callCount = 0;
        pooledPlayer.addOnEvictedCallback(() => callCount++);

        await pooledPlayer.dispose();
        pooledPlayer.recycle();

        expect(callCount, equals(1));
        expect(pooledPlayer.isDisposed, isTrue);
      });

      test('sets wasRecycled to true', () {
        final pooledPlayer = PooledPlayer(controller: mockController);

        expect(pooledPlayer.wasRecycled, isFalse);
        pooledPlayer.recycle();
        expect(pooledPlayer.wasRecycled, isTrue);
      });

      test('clearRecycled resets wasRecycled to false', () {
        final pooledPlayer = PooledPlayer(controller: mockController);

        (pooledPlayer..recycle()).clearRecycled();
        expect(pooledPlayer.wasRecycled, isFalse);
      });
    });
  });
}
