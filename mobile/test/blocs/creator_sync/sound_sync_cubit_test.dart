// ABOUTME: Tests SoundSyncCubit status transitions.
// ABOUTME: Pins that no error strings or exceptions land in state.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/creator_sync/sound_sync_cubit.dart';
import 'package:openvine/blocs/creator_sync/sound_sync_state.dart';
import 'package:openvine/observability/reportable_error.dart';

class _MockRepository extends Mock implements SoundSyncRepository {}

void main() {
  group(SoundSyncCubit, () {
    late _MockRepository repository;

    setUp(() => repository = _MockRepository());

    blocTest<SoundSyncCubit, SoundSyncState>(
      'emits syncing then success on a clean pass',
      build: () {
        when(repository.reconcile).thenAnswer(
          (_) async => const SoundSyncOutcome(pulled: 2, pushed: 1, deleted: 0),
        );
        return SoundSyncCubit(repository: repository);
      },
      act: (cubit) => cubit.syncNow(),
      expect: () => const [
        SoundSyncState(status: SoundSyncStatus.syncing),
        SoundSyncState(status: SoundSyncStatus.success, pulled: 2, pushed: 1),
      ],
    );

    blocTest<SoundSyncCubit, SoundSyncState>(
      'emits failure without reporting an expected relay error',
      build: () {
        when(
          repository.reconcile,
        ).thenThrow(SyncIndexException('relay down'));
        return SoundSyncCubit(repository: repository);
      },
      act: (cubit) => cubit.syncNow(),
      expect: () => const [
        SoundSyncState(status: SoundSyncStatus.syncing),
        SoundSyncState(status: SoundSyncStatus.failure),
      ],
      errors: () => [isA<SyncIndexException>()],
    );

    blocTest<SoundSyncCubit, SoundSyncState>(
      'emits locked when the vault key is unavailable',
      build: () {
        when(
          repository.reconcile,
        ).thenThrow(VaultKeyUnavailableException('relay unreachable'));
        return SoundSyncCubit(repository: repository);
      },
      act: (cubit) => cubit.syncNow(),
      expect: () => const [
        SoundSyncState(status: SoundSyncStatus.syncing),
        SoundSyncState(status: SoundSyncStatus.locked),
      ],
      errors: () => [isA<VaultKeyUnavailableException>()],
    );

    blocTest<SoundSyncCubit, SoundSyncState>(
      'ignores a second syncNow while one is in flight',
      build: () {
        when(repository.reconcile).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return const SoundSyncOutcome(pulled: 0, pushed: 0, deleted: 0);
        });
        return SoundSyncCubit(repository: repository);
      },
      act: (cubit) async {
        unawaited(cubit.syncNow());
        await cubit.syncNow();
      },
      verify: (_) => verify(repository.reconcile).called(1),
    );

    blocTest<SoundSyncCubit, SoundSyncState>(
      'emits failure and reports an unexpected error, e.g. a malformed '
      'remote body',
      build: () {
        when(
          repository.reconcile,
        ).thenThrow(const FormatException('Saved sound missing audio'));
        return SoundSyncCubit(repository: repository);
      },
      act: (cubit) => cubit.syncNow(),
      expect: () => const [
        SoundSyncState(status: SoundSyncStatus.syncing),
        SoundSyncState(status: SoundSyncStatus.failure),
      ],
      errors: () => [
        isA<Reportable<Object>>().having(
          (r) => r.unwrap(),
          'unwrap',
          isA<FormatException>(),
        ),
      ],
    );

    blocTest<SoundSyncCubit, SoundSyncState>(
      'does not wedge sync after an unexpected error — a later syncNow '
      'still calls reconcile',
      build: () {
        when(
          repository.reconcile,
        ).thenThrow(const FormatException('Saved sound missing audio'));
        return SoundSyncCubit(repository: repository);
      },
      act: (cubit) async {
        await cubit.syncNow();
        await cubit.syncNow();
      },
      expect: () => const [
        SoundSyncState(status: SoundSyncStatus.syncing),
        SoundSyncState(status: SoundSyncStatus.failure),
        SoundSyncState(status: SoundSyncStatus.syncing),
        SoundSyncState(status: SoundSyncStatus.failure),
      ],
      errors: () => [
        isA<Reportable<Object>>(),
        isA<Reportable<Object>>(),
      ],
      verify: (_) => verify(repository.reconcile).called(2),
    );

    test(
      'does not throw when the cubit closes while reconcile is in flight',
      () async {
        final completer = Completer<SoundSyncOutcome>();
        when(repository.reconcile).thenAnswer((_) => completer.future);
        final cubit = SoundSyncCubit(repository: repository);
        addTearDown(() {
          if (!cubit.isClosed) cubit.close();
        });

        final syncFuture = cubit.syncNow();
        await cubit.close();
        completer.complete(
          const SoundSyncOutcome(pulled: 0, pushed: 0, deleted: 0),
        );

        await expectLater(syncFuture, completes);
      },
    );
  });
}
