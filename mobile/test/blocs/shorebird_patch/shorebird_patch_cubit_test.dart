import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_cubit.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_state.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Records the track it was asked for, so tests can prove the cubit targets
/// `staging` rather than the package default of `stable` — the whole reason
/// this cubit exists.
class _FakeUpdater implements ShorebirdUpdater {
  _FakeUpdater({
    this.isAvailable = true,
    this.currentPatch,
    this.updateStatus = UpdateStatus.upToDate,
    this.readThrows = false,
    this.checkThrows = false,
    this.updateThrows = false,
  });

  @override
  final bool isAvailable;

  final Patch? currentPatch;
  final UpdateStatus updateStatus;
  final bool readThrows;
  final bool checkThrows;
  final bool updateThrows;

  UpdateTrack? checkedTrack;
  UpdateTrack? updatedTrack;

  @override
  Future<Patch?> readCurrentPatch() async {
    if (readThrows) throw Exception('read failed');
    return currentPatch;
  }

  @override
  Future<Patch?> readNextPatch() async => currentPatch;

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async {
    checkedTrack = track;
    if (checkThrows) throw Exception('check failed');
    return updateStatus;
  }

  @override
  Future<void> update({UpdateTrack? track}) async {
    updatedTrack = track;
    if (updateThrows) throw Exception('update failed');
  }
}

void main() {
  group(ShorebirdPatchCubit, () {
    group('load', () {
      blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
        'reports unavailable when the updater is absent from the build',
        build: () =>
            ShorebirdPatchCubit(updater: _FakeUpdater(isAvailable: false)),
        act: (cubit) => cubit.load(),
        expect: () => const [
          ShorebirdPatchState(status: ShorebirdPatchStatus.unavailable),
        ],
      );

      blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
        'surfaces the running patch number',
        build: () => ShorebirdPatchCubit(
          updater: _FakeUpdater(currentPatch: const Patch(number: 7)),
        ),
        act: (cubit) => cubit.load(),
        expect: () => const [
          ShorebirdPatchState(currentPatchNumber: 7),
        ],
      );

      blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
        'reports failure and an error when the read throws',
        build: () =>
            ShorebirdPatchCubit(updater: _FakeUpdater(readThrows: true)),
        act: (cubit) => cubit.load(),
        expect: () => const [
          ShorebirdPatchState(status: ShorebirdPatchStatus.failure),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('checkStagingTrack', () {
      test('asks for the staging track, not the stable default', () async {
        final updater = _FakeUpdater();
        await ShorebirdPatchCubit(updater: updater).checkStagingTrack();

        expect(updater.checkedTrack, equals(UpdateTrack.staging));
      });

      blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
        'reports a staged patch as available to apply',
        build: () => ShorebirdPatchCubit(
          updater: _FakeUpdater(updateStatus: UpdateStatus.outdated),
        ),
        act: (cubit) => cubit.checkStagingTrack(),
        expect: () => const [
          ShorebirdPatchState(status: ShorebirdPatchStatus.checking),
          ShorebirdPatchState(status: ShorebirdPatchStatus.updateAvailable),
        ],
      );

      blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
        'reports an empty staging track as up to date',
        build: () => ShorebirdPatchCubit(updater: _FakeUpdater()),
        act: (cubit) => cubit.checkStagingTrack(),
        expect: () => const [
          ShorebirdPatchState(status: ShorebirdPatchStatus.checking),
          ShorebirdPatchState(status: ShorebirdPatchStatus.upToDate),
        ],
      );

      blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
        'treats a downloaded-but-unapplied patch as needing a restart',
        build: () => ShorebirdPatchCubit(
          updater: _FakeUpdater(updateStatus: UpdateStatus.restartRequired),
        ),
        act: (cubit) => cubit.checkStagingTrack(),
        expect: () => const [
          ShorebirdPatchState(status: ShorebirdPatchStatus.checking),
          ShorebirdPatchState(status: ShorebirdPatchStatus.applied),
        ],
      );

      blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
        'reports failure and an error when the check throws',
        build: () =>
            ShorebirdPatchCubit(updater: _FakeUpdater(checkThrows: true)),
        act: (cubit) => cubit.checkStagingTrack(),
        expect: () => const [
          ShorebirdPatchState(status: ShorebirdPatchStatus.checking),
          ShorebirdPatchState(status: ShorebirdPatchStatus.failure),
        ],
        errors: () => [isA<Exception>()],
      );

      test('does not call the updater when unavailable', () async {
        final updater = _FakeUpdater(isAvailable: false);
        await ShorebirdPatchCubit(updater: updater).checkStagingTrack();

        expect(updater.checkedTrack, isNull);
      });
    });

    group('applyStagedPatch', () {
      test('applies from the staging track', () async {
        final updater = _FakeUpdater();
        await ShorebirdPatchCubit(updater: updater).applyStagedPatch();

        expect(updater.updatedTrack, equals(UpdateTrack.staging));
      });

      blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
        'reports applied so the tester knows to relaunch',
        build: () => ShorebirdPatchCubit(updater: _FakeUpdater()),
        act: (cubit) => cubit.applyStagedPatch(),
        expect: () => const [
          ShorebirdPatchState(status: ShorebirdPatchStatus.applying),
          ShorebirdPatchState(status: ShorebirdPatchStatus.applied),
        ],
      );

      blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
        'reports failure and an error when the update throws',
        build: () =>
            ShorebirdPatchCubit(updater: _FakeUpdater(updateThrows: true)),
        act: (cubit) => cubit.applyStagedPatch(),
        expect: () => const [
          ShorebirdPatchState(status: ShorebirdPatchStatus.applying),
          ShorebirdPatchState(status: ShorebirdPatchStatus.failure),
        ],
        errors: () => [isA<Exception>()],
      );
    });
  });
}
