import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_state.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:unified_logger/unified_logger.dart';

/// Drives the developer-options staging-patch section.
///
/// Exists because a staged patch is otherwise invisible on iOS: release
/// artifacts are signed for App Store distribution, so `shorebird preview`
/// cannot install them, and an installed build only ever polls
/// [UpdateTrack.stable]. Without a way to pull [UpdateTrack.staging] on the
/// exact store binary, the only way to see a patch is to promote it to
/// production. See #7979.
class ShorebirdPatchCubit extends Cubit<ShorebirdPatchState>
    with CloseGuardedEmit<ShorebirdPatchState> {
  ShorebirdPatchCubit({required ShorebirdUpdater updater})
    : _updater = updater,
      super(const ShorebirdPatchState());

  final ShorebirdUpdater _updater;

  static const _logName = 'ShorebirdPatchCubit';

  /// Reads updater availability and the running patch number.
  Future<void> load() async {
    if (!_updater.isAvailable) {
      emitIfOpen(
        state.copyWith(
          status: ShorebirdPatchStatus.unavailable,
          clearCurrentPatchNumber: true,
        ),
      );
      return;
    }

    try {
      final patch = await _updater.readCurrentPatch();
      emitIfOpen(
        state.copyWith(
          status: ShorebirdPatchStatus.initial,
          currentPatchNumber: patch?.number,
          clearCurrentPatchNumber: patch == null,
        ),
      );
    } catch (error, stackTrace) {
      Log.error(
        'Failed to read the current patch',
        name: _logName,
        category: LogCategory.system,
        error: error,
        stackTrace: stackTrace,
      );
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: ShorebirdPatchStatus.failure));
    }
  }

  /// Asks the staging track whether a patch is waiting.
  Future<void> checkStagingTrack() async {
    if (!_updater.isAvailable) {
      emitIfOpen(state.copyWith(status: ShorebirdPatchStatus.unavailable));
      return;
    }
    if (state.isBusy) return;

    emitIfOpen(state.copyWith(status: ShorebirdPatchStatus.checking));

    try {
      final status = await _updater.checkForUpdate(track: UpdateTrack.staging);
      emitIfOpen(state.copyWith(status: _statusFor(status)));
    } catch (error, stackTrace) {
      Log.error(
        'Staging-track check failed',
        name: _logName,
        category: LogCategory.system,
        error: error,
        stackTrace: stackTrace,
      );
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: ShorebirdPatchStatus.failure));
    }
  }

  /// Downloads and installs the staged patch. It applies on the next launch.
  Future<void> applyStagedPatch() async {
    if (!_updater.isAvailable) {
      emitIfOpen(state.copyWith(status: ShorebirdPatchStatus.unavailable));
      return;
    }
    if (state.isBusy) return;

    emitIfOpen(state.copyWith(status: ShorebirdPatchStatus.applying));

    try {
      await _updater.update(track: UpdateTrack.staging);
      emitIfOpen(state.copyWith(status: ShorebirdPatchStatus.applied));
    } catch (error, stackTrace) {
      Log.error(
        'Applying the staged patch failed',
        name: _logName,
        category: LogCategory.system,
        error: error,
        stackTrace: stackTrace,
      );
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: ShorebirdPatchStatus.failure));
    }
  }

  ShorebirdPatchStatus _statusFor(UpdateStatus status) {
    return switch (status) {
      UpdateStatus.outdated => ShorebirdPatchStatus.updateAvailable,
      // A downloaded-but-unapplied patch is still something the tester has to
      // relaunch for, so it reports as applied rather than up to date.
      UpdateStatus.restartRequired => ShorebirdPatchStatus.applied,
      UpdateStatus.upToDate => ShorebirdPatchStatus.upToDate,
      UpdateStatus.unavailable => ShorebirdPatchStatus.unavailable,
    };
  }
}
