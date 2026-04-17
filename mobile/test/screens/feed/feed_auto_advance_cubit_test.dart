// ABOUTME: Tests the FeedAutoAdvanceCubit toggle, suppression, and pending
// ABOUTME: pagination transitions.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';

void main() {
  group(FeedAutoAdvanceCubit, () {
    test('initial state is disabled, unsuppressed, no pending advance', () {
      final cubit = FeedAutoAdvanceCubit();
      addTearDown(cubit.close);

      expect(cubit.state.enabled, isFalse);
      expect(cubit.state.suppressed, isFalse);
      expect(cubit.state.pendingPaginationAdvance, isFalse);
      expect(cubit.state.isEffectivelyActive, isFalse);
    });

    group('setEnabled', () {
      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'enabling emits enabled state',
        build: FeedAutoAdvanceCubit.new,
        act: (cubit) => cubit.setEnabled(enabled: true),
        expect: () => const [FeedAutoAdvanceState(enabled: true)],
      );

      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'is a no-op when already enabled',
        build: FeedAutoAdvanceCubit.new,
        seed: () => const FeedAutoAdvanceState(enabled: true),
        act: (cubit) => cubit.setEnabled(enabled: true),
        expect: () => const <FeedAutoAdvanceState>[],
      );

      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'disabling clears suppression and pending advance',
        build: FeedAutoAdvanceCubit.new,
        seed: () => const FeedAutoAdvanceState(
          enabled: true,
          suppressed: true,
          pendingPaginationAdvance: true,
        ),
        act: (cubit) => cubit.setEnabled(enabled: false),
        expect: () => const [FeedAutoAdvanceState()],
      );
    });

    group('toggle', () {
      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'flips enabled from off to on',
        build: FeedAutoAdvanceCubit.new,
        act: (cubit) => cubit.toggle(),
        expect: () => const [FeedAutoAdvanceState(enabled: true)],
      );

      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'flips enabled from on to off',
        build: FeedAutoAdvanceCubit.new,
        seed: () => const FeedAutoAdvanceState(enabled: true),
        act: (cubit) => cubit.toggle(),
        expect: () => const [FeedAutoAdvanceState()],
      );

      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'resumes (clears suppression) when enabled and suppressed',
        build: FeedAutoAdvanceCubit.new,
        seed: () => const FeedAutoAdvanceState(
          enabled: true,
          suppressed: true,
        ),
        act: (cubit) => cubit.toggle(),
        expect: () => const [FeedAutoAdvanceState(enabled: true)],
      );
    });

    group('suppressForInteraction', () {
      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'sets suppressed and clears pending advance when enabled',
        build: FeedAutoAdvanceCubit.new,
        seed: () => const FeedAutoAdvanceState(
          enabled: true,
          pendingPaginationAdvance: true,
        ),
        act: (cubit) => cubit.suppressForInteraction(),
        expect: () => const [
          FeedAutoAdvanceState(enabled: true, suppressed: true),
        ],
      );

      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'is a no-op when already suppressed',
        build: FeedAutoAdvanceCubit.new,
        seed: () => const FeedAutoAdvanceState(
          enabled: true,
          suppressed: true,
        ),
        act: (cubit) => cubit.suppressForInteraction(),
        expect: () => const <FeedAutoAdvanceState>[],
      );

      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'is a no-op when Auto is disabled',
        build: FeedAutoAdvanceCubit.new,
        act: (cubit) => cubit.suppressForInteraction(),
        expect: () => const <FeedAutoAdvanceState>[],
      );
    });

    group('resumeAfterSwipe', () {
      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'clears suppression and pending advance',
        build: FeedAutoAdvanceCubit.new,
        seed: () => const FeedAutoAdvanceState(
          enabled: true,
          suppressed: true,
          pendingPaginationAdvance: true,
        ),
        act: (cubit) => cubit.resumeAfterSwipe(),
        expect: () => const [FeedAutoAdvanceState(enabled: true)],
      );

      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'is a no-op when not suppressed',
        build: FeedAutoAdvanceCubit.new,
        seed: () => const FeedAutoAdvanceState(enabled: true),
        act: (cubit) => cubit.resumeAfterSwipe(),
        expect: () => const <FeedAutoAdvanceState>[],
      );

      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'is a no-op when Auto is disabled',
        build: FeedAutoAdvanceCubit.new,
        act: (cubit) => cubit.resumeAfterSwipe(),
        expect: () => const <FeedAutoAdvanceState>[],
      );
    });

    group('pending pagination advance', () {
      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'markPendingPaginationAdvance flips the flag',
        build: FeedAutoAdvanceCubit.new,
        seed: () => const FeedAutoAdvanceState(enabled: true),
        act: (cubit) => cubit.markPendingPaginationAdvance(),
        expect: () => const [
          FeedAutoAdvanceState(
            enabled: true,
            pendingPaginationAdvance: true,
          ),
        ],
      );

      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'markPendingPaginationAdvance is a no-op when already pending',
        build: FeedAutoAdvanceCubit.new,
        seed: () => const FeedAutoAdvanceState(
          enabled: true,
          pendingPaginationAdvance: true,
        ),
        act: (cubit) => cubit.markPendingPaginationAdvance(),
        expect: () => const <FeedAutoAdvanceState>[],
      );

      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'clearPendingPaginationAdvance flips the flag back',
        build: FeedAutoAdvanceCubit.new,
        seed: () => const FeedAutoAdvanceState(
          enabled: true,
          pendingPaginationAdvance: true,
        ),
        act: (cubit) => cubit.clearPendingPaginationAdvance(),
        expect: () => const [FeedAutoAdvanceState(enabled: true)],
      );

      blocTest<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
        'clearPendingPaginationAdvance is a no-op when nothing queued',
        build: FeedAutoAdvanceCubit.new,
        act: (cubit) => cubit.clearPendingPaginationAdvance(),
        expect: () => const <FeedAutoAdvanceState>[],
      );
    });

    test('isEffectivelyActive is false while suppressed', () {
      final cubit = FeedAutoAdvanceCubit();
      addTearDown(cubit.close);

      cubit
        ..toggle()
        ..suppressForInteraction();

      expect(cubit.state.enabled, isTrue);
      expect(cubit.state.suppressed, isTrue);
      expect(cubit.state.isEffectivelyActive, isFalse);
    });
  });
}
