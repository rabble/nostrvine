// ABOUTME: Tests for VideoIndexState model
// ABOUTME: Validates getters, equality, and constructor defaults

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

class _MockVideoController extends Mock implements VideoController {}

class _MockPlayer extends Mock implements Player {}

void main() {
  group(VideoIndexState, () {
    group('constructor', () {
      test('has correct defaults', () {
        const state = VideoIndexState();

        expect(state.loadState, equals(LoadState.none));
        expect(state.videoController, isNull);
        expect(state.player, isNull);
      });

      test('accepts all parameters', () {
        final controller = _MockVideoController();
        final player = _MockPlayer();

        final state = VideoIndexState(
          loadState: LoadState.ready,
          videoController: controller,
          player: player,
        );

        expect(state.loadState, equals(LoadState.ready));
        expect(state.videoController, equals(controller));
        expect(state.player, equals(player));
      });
    });

    group('isReady', () {
      test('returns true when LoadState is ready', () {
        const state = VideoIndexState(loadState: LoadState.ready);

        expect(state.isReady, isTrue);
      });

      test('returns false when LoadState is not ready', () {
        const states = [
          VideoIndexState(),
          VideoIndexState(loadState: LoadState.loading),
          VideoIndexState(loadState: LoadState.error),
          VideoIndexState(loadState: LoadState.disabled),
        ];

        for (final state in states) {
          expect(state.isReady, isFalse);
        }
      });
    });

    group('hasError', () {
      test('returns true when LoadState is error', () {
        const state = VideoIndexState(loadState: LoadState.error);

        expect(state.hasError, isTrue);
      });

      test('returns false when LoadState is not error', () {
        const states = [
          VideoIndexState(),
          VideoIndexState(loadState: LoadState.loading),
          VideoIndexState(loadState: LoadState.ready),
          VideoIndexState(loadState: LoadState.disabled),
        ];

        for (final state in states) {
          expect(state.hasError, isFalse);
        }
      });
    });

    group('isLoading', () {
      test('returns true when LoadState is loading', () {
        const state = VideoIndexState(loadState: LoadState.loading);

        expect(state.isLoading, isTrue);
      });

      test('returns false when LoadState is not loading', () {
        const states = [
          VideoIndexState(),
          VideoIndexState(loadState: LoadState.ready),
          VideoIndexState(loadState: LoadState.error),
          VideoIndexState(loadState: LoadState.disabled),
        ];

        for (final state in states) {
          expect(state.isLoading, isFalse);
        }
      });
    });

    group('isDisabled', () {
      test('returns true when LoadState is disabled', () {
        const state = VideoIndexState(loadState: LoadState.disabled);

        expect(state.isDisabled, isTrue);
      });

      test('returns false when LoadState is not disabled', () {
        const states = [
          VideoIndexState(),
          VideoIndexState(loadState: LoadState.loading),
          VideoIndexState(loadState: LoadState.ready),
          VideoIndexState(loadState: LoadState.error),
        ];

        for (final state in states) {
          expect(state.isDisabled, isFalse);
        }
      });
    });

    group('equality', () {
      test('two states with same values are equal', () {
        const state1 = VideoIndexState(loadState: LoadState.loading);
        const state2 = VideoIndexState(loadState: LoadState.loading);

        expect(state1, equals(state2));
      });

      test('two states with different loadState are not equal', () {
        const state1 = VideoIndexState(loadState: LoadState.loading);
        const state2 = VideoIndexState(loadState: LoadState.ready);

        expect(state1, isNot(equals(state2)));
      });

      test('props includes all fields', () {
        final controller = _MockVideoController();
        final player = _MockPlayer();

        final state = VideoIndexState(
          loadState: LoadState.ready,
          videoController: controller,
          player: player,
        );

        expect(state.props, equals([LoadState.ready, controller, player]));
      });
    });
  });
}
