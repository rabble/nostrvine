// ABOUTME: Tests for VideoIndexState model
// ABOUTME: Validates convenience getters and equality

import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group(VideoIndexState, () {
    group('isReady', () {
      test('returns true when loadState is ready', () {
        const state = VideoIndexState(loadState: LoadState.ready);

        expect(state.isReady, isTrue);
      });

      test('returns false when loadState is not ready', () {
        const state = VideoIndexState(loadState: LoadState.loading);

        expect(state.isReady, isFalse);
      });
    });

    group('hasError', () {
      test('returns true when loadState is error', () {
        const state = VideoIndexState(loadState: LoadState.error);

        expect(state.hasError, isTrue);
      });

      test('returns false when loadState is not error', () {
        const state = VideoIndexState(loadState: LoadState.ready);

        expect(state.hasError, isFalse);
      });
    });

    group('isLoading', () {
      test('returns true when loadState is loading', () {
        const state = VideoIndexState(loadState: LoadState.loading);

        expect(state.isLoading, isTrue);
      });

      test('returns false when loadState is not loading', () {
        const state = VideoIndexState();

        expect(state.isLoading, isFalse);
      });
    });

    group('equality', () {
      test('states with same properties are equal', () {
        const state1 = VideoIndexState(loadState: LoadState.ready);
        const state2 = VideoIndexState(loadState: LoadState.ready);

        expect(state1, equals(state2));
      });

      test('states with different loadState are not equal', () {
        const state1 = VideoIndexState(loadState: LoadState.ready);
        const state2 = VideoIndexState(loadState: LoadState.error);

        expect(state1, isNot(equals(state2)));
      });

      test('states with different errorType are not equal', () {
        const state1 = VideoIndexState(
          loadState: LoadState.error,
          errorType: VideoErrorType.forbidden,
        );
        const state2 = VideoIndexState(
          loadState: LoadState.error,
          errorType: VideoErrorType.notFound,
        );

        expect(state1, isNot(equals(state2)));
      });
    });

    group('defaults', () {
      test('default loadState is none', () {
        const state = VideoIndexState();

        expect(state.loadState, equals(LoadState.none));
      });

      test('default controller is null', () {
        const state = VideoIndexState();

        expect(state.controller, isNull);
      });

      test('default errorType is null', () {
        const state = VideoIndexState();

        expect(state.errorType, isNull);
      });
    });
  });
}
