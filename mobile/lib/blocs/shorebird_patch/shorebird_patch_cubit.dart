import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_state.dart';
import 'package:openvine/repositories/shorebird_patch_repository.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:unified_logger/unified_logger.dart';

/// Drives the developer-options staging-patch validation flow.
class ShorebirdPatchCubit extends Cubit<ShorebirdPatchState>
    with CloseGuardedEmit<ShorebirdPatchState> {
  ShorebirdPatchCubit({required ShorebirdPatchRepository repository})
    : _repository = repository,
      super(const ShorebirdPatchState());

  final ShorebirdPatchRepository _repository;
  static const _logName = 'ShorebirdPatchCubit';

  Future<void> load() async {
    final usesStagingTrack =
        _repository.subscribedTrack == ShorebirdSubscribedTrack.staging;
    if (!_repository.isAvailable) {
      emitIfOpen(
        state.copyWith(
          status: ShorebirdPatchValidationStatus.unavailable,
          clearCurrentPatchNumber: true,
          usesStagingTrack: usesStagingTrack,
        ),
      );
      return;
    }

    try {
      final snapshot = await _repository.readSnapshot();
      emitIfOpen(
        state.copyWith(
          status: ShorebirdPatchValidationStatus.notChecked,
          currentPatchNumber: snapshot.current?.number,
          clearCurrentPatchNumber: snapshot.current == null,
          usesStagingTrack: usesStagingTrack,
        ),
      );
    } catch (error, stackTrace) {
      _reportFailure(
        'Failed to read Shorebird patch state',
        error,
        stackTrace,
        usesStagingTrack: usesStagingTrack,
      );
    }
  }

  Future<void> checkStagingTrack() async {
    if (!_repository.isAvailable) {
      emitIfOpen(
        state.copyWith(status: ShorebirdPatchValidationStatus.unavailable),
      );
      return;
    }
    if (state.isBusy) return;

    emitIfOpen(state.copyWith(status: ShorebirdPatchValidationStatus.checking));
    try {
      final check = await _repository.checkStagingTrack();
      emitIfOpen(
        state.copyWith(
          status: _statusFor(check),
          currentPatchNumber: check.snapshot.current?.number,
          clearCurrentPatchNumber: check.snapshot.current == null,
          usesStagingTrack:
              _repository.subscribedTrack == ShorebirdSubscribedTrack.staging,
        ),
      );
    } catch (error, stackTrace) {
      _reportFailure('Staging-track check failed', error, stackTrace);
    }
  }

  Future<void> applyStagedPatch() async {
    if (!_repository.isAvailable) {
      emitIfOpen(
        state.copyWith(status: ShorebirdPatchValidationStatus.unavailable),
      );
      return;
    }
    if (!state.canApply) return;

    emitIfOpen(state.copyWith(status: ShorebirdPatchValidationStatus.applying));
    try {
      final result = await _repository.applyStagingPatch();
      final snapshot = await _repository.readSnapshot();
      emitIfOpen(
        state.copyWith(
          status: switch (result) {
            ShorebirdPatchApplyResult.installed =>
              ShorebirdPatchValidationStatus.applied,
            ShorebirdPatchApplyResult.unchanged =>
              ShorebirdPatchValidationStatus.unchanged,
          },
          currentPatchNumber: snapshot.current?.number,
          clearCurrentPatchNumber: snapshot.current == null,
          usesStagingTrack:
              _repository.subscribedTrack == ShorebirdSubscribedTrack.staging,
        ),
      );
    } catch (error, stackTrace) {
      _reportFailure('Applying the staged patch failed', error, stackTrace);
    }
  }

  Future<void> useStableTrack() async {
    if (state.isBusy) return;
    emitIfOpen(
      state.copyWith(
        status: ShorebirdPatchValidationStatus.selectingStableTrack,
      ),
    );
    try {
      await _repository.useStableTrack();
      emitIfOpen(
        state.copyWith(
          status: ShorebirdPatchValidationStatus.stableRestored,
          usesStagingTrack: false,
        ),
      );
    } catch (error, stackTrace) {
      _reportFailure('Restoring the stable track failed', error, stackTrace);
    }
  }

  ShorebirdPatchValidationStatus _statusFor(ShorebirdPatchCheck check) {
    return switch (check.status) {
      UpdateStatus.outdated => ShorebirdPatchValidationStatus.updateAvailable,
      UpdateStatus.restartRequired when check.isRollback =>
        ShorebirdPatchValidationStatus.rollbackRequired,
      UpdateStatus.restartRequired =>
        ShorebirdPatchValidationStatus.restartRequired,
      UpdateStatus.upToDate => ShorebirdPatchValidationStatus.upToDate,
      UpdateStatus.unavailable => ShorebirdPatchValidationStatus.unavailable,
    };
  }

  void _reportFailure(
    String message,
    Object error,
    StackTrace stackTrace, {
    bool? usesStagingTrack,
  }) {
    Log.error(
      message,
      name: _logName,
      category: LogCategory.system,
      error: error,
      stackTrace: stackTrace,
    );
    addError(error, stackTrace);
    emitIfOpen(
      state.copyWith(
        status: ShorebirdPatchValidationStatus.failure,
        usesStagingTrack: usesStagingTrack,
      ),
    );
  }
}
