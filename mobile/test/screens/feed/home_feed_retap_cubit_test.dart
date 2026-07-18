// ABOUTME: Unit tests for HomeFeedRetapCubit request/completeRefresh
// ABOUTME: transitions and retap idempotency while a refresh is in flight.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';

void main() {
  group(HomeFeedRetapCubit, () {
    group('request', () {
      blocTest<HomeFeedRetapCubit, HomeFeedRetapState>(
        'emits refreshing when idle',
        build: HomeFeedRetapCubit.new,
        act: (cubit) => cubit.request(),
        expect: () => const [
          HomeFeedRetapState(status: HomeFeedRetapStatus.refreshing),
        ],
      );

      blocTest<HomeFeedRetapCubit, HomeFeedRetapState>(
        'is a no-op while a refresh is already in flight',
        build: HomeFeedRetapCubit.new,
        seed: () =>
            const HomeFeedRetapState(status: HomeFeedRetapStatus.refreshing),
        act: (cubit) => cubit.request(),
        expect: () => const <HomeFeedRetapState>[],
      );
    });

    group('completeRefresh', () {
      blocTest<HomeFeedRetapCubit, HomeFeedRetapState>(
        'returns to idle once the refresh settles',
        build: HomeFeedRetapCubit.new,
        seed: () =>
            const HomeFeedRetapState(status: HomeFeedRetapStatus.refreshing),
        act: (cubit) => cubit.completeRefresh(),
        expect: () => const [HomeFeedRetapState()],
      );
    });

    group(HomeFeedRetapState, () {
      test('isRefreshing reflects status', () {
        expect(const HomeFeedRetapState().isRefreshing, isFalse);
        expect(
          const HomeFeedRetapState(
            status: HomeFeedRetapStatus.refreshing,
          ).isRefreshing,
          isTrue,
        );
      });
    });
  });
}
