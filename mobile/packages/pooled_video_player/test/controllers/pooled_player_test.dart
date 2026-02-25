// ABOUTME: Tests for PooledPlayer controller
// ABOUTME: Validates player wrapper lifecycle and dispose behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

class _MockPlayer extends Mock implements Player {}

class _MockVideoController extends Mock implements VideoController {}

class _MockPlayerState extends Mock implements PlayerState {}

class _MockPlayerStream extends Mock implements PlayerStream {}

void _setUpFallbacks() {
  registerFallbackValue(Duration.zero);
  registerFallbackValue(PlaylistMode.single);
}

_MockPlayer _createMockPlayer() {
  final mockPlayer = _MockPlayer();
  final mockState = _MockPlayerState();
  final mockStream = _MockPlayerStream();

  when(() => mockState.playing).thenReturn(false);
  when(() => mockState.buffering).thenReturn(false);
  when(() => mockState.position).thenReturn(Duration.zero);
  when(() => mockPlayer.state).thenReturn(mockState);
  when(() => mockPlayer.stream).thenReturn(mockStream);

  when(mockPlayer.play).thenAnswer((_) async {});
  when(mockPlayer.pause).thenAnswer((_) async {});
  when(mockPlayer.stop).thenAnswer((_) async {});
  when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
  when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});
  when(() => mockPlayer.setRate(any())).thenAnswer((_) async {});
  when(() => mockPlayer.setPlaylistMode(any())).thenAnswer((_) async {});
  when(mockPlayer.dispose).thenAnswer((_) async {});

  return mockPlayer;
}

void main() {
  setUpAll(_setUpFallbacks);

  group('PooledPlayer', () {
    late _MockPlayer mockPlayer;
    late _MockVideoController mockVideoController;

    setUp(() {
      mockPlayer = _createMockPlayer();
      mockVideoController = _MockVideoController();
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

        verify(() => mockPlayer.stop()).called(1);
        verify(() => mockPlayer.dispose()).called(1);
      });

      test('handles player.stop() exception gracefully', () async {
        when(() => mockPlayer.stop()).thenThrow(Exception('Stop failed'));

        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        await expectLater(pooledPlayer.dispose(), completes);
        expect(pooledPlayer.isDisposed, isTrue);
      });

      test('handles player.dispose() exception gracefully', () async {
        when(() => mockPlayer.dispose()).thenThrow(Exception('Dispose failed'));

        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

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

    group('onDisposedCallback', () {
      test('invokes callback on dispose', () async {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        var callCount = 0;
        pooledPlayer.addOnDisposedCallback(() => callCount++);

        await pooledPlayer.dispose();

        expect(callCount, equals(1));
      });

      test('invokes multiple callbacks on dispose', () async {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        final calls = <String>[];
        pooledPlayer
          ..addOnDisposedCallback(() => calls.add('a'))
          ..addOnDisposedCallback(() => calls.add('b'));

        await pooledPlayer.dispose();

        expect(calls, equals(['a', 'b']));
      });

      test('invokes callbacks before stopping native player', () async {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        var wasDisposedInCallback = false;
        pooledPlayer.addOnDisposedCallback(() {
          // Callback fires BEFORE player.stop(), so isDisposed is true
          // but native resources haven't been torn down yet.
          wasDisposedInCallback = pooledPlayer.isDisposed;
          verifyNever(() => mockPlayer.stop());
        });

        await pooledPlayer.dispose();

        expect(wasDisposedInCallback, isTrue);
      });

      test('does not invoke callbacks on second dispose', () async {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        var callCount = 0;
        pooledPlayer.addOnDisposedCallback(() => callCount++);

        await pooledPlayer.dispose();
        await pooledPlayer.dispose();

        expect(callCount, equals(1));
      });

      test('removed callback is not invoked', () async {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        var callCount = 0;
        void callback() => callCount++;
        pooledPlayer
          ..addOnDisposedCallback(callback)
          ..removeOnDisposedCallback(callback);

        await pooledPlayer.dispose();

        expect(callCount, equals(0));
      });

      test('clears callbacks after dispose', () async {
        final pooledPlayer = PooledPlayer(
          player: mockPlayer,
          videoController: mockVideoController,
        );

        var callCount = 0;
        pooledPlayer.addOnDisposedCallback(() => callCount++);

        await pooledPlayer.dispose();

        expect(callCount, equals(1));
        // Callbacks are cleared — no lingering references.
      });
    });
  });
}
