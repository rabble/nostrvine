// ABOUTME: Unit tests for FeedImmersiveCubit.
// ABOUTME: Pins the idempotent enter/exit contract the several hold-release
// ABOUTME: paths in the feed rely on.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';

void main() {
  group(FeedImmersiveCubit, () {
    test('starts with the chrome visible', () {
      final cubit = FeedImmersiveCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isImmersive, isFalse);
    });

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'enter hides the chrome',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit.enter(),
      expect: () => const [FeedImmersiveState(isImmersive: true)],
    );

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'exit restores the chrome',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit
        ..enter()
        ..exit(),
      expect: () => const [
        FeedImmersiveState(isImmersive: true),
        FeedImmersiveState(),
      ],
    );

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'repeated enter does not re-emit',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit
        ..enter()
        ..enter(),
      expect: () => const [FeedImmersiveState(isImmersive: true)],
    );

    blocTest<FeedImmersiveCubit, FeedImmersiveState>(
      'exit without a preceding enter emits nothing',
      build: FeedImmersiveCubit.new,
      act: (cubit) => cubit.exit(),
      expect: () => const <FeedImmersiveState>[],
    );
  });
}
