// ABOUTME: Tests SoundSyncCubit status transitions.
// ABOUTME: Pins that no error strings or exceptions land in state.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/creator_sync/sound_sync_cubit.dart';
import 'package:openvine/blocs/creator_sync/sound_sync_state.dart';

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
  });
}
