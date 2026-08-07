// ABOUTME: Drives sound library reconciliation and exposes its status.
// ABOUTME: Maps expected sync failures to statuses, never to state strings.

import 'package:bloc/bloc.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:openvine/blocs/creator_sync/sound_sync_state.dart';
import 'package:openvine/observability/reportable_error.dart';

/// Runs sound library sync passes on demand.
class SoundSyncCubit extends Cubit<SoundSyncState> {
  /// Creates a [SoundSyncCubit].
  SoundSyncCubit({required SoundSyncRepository repository})
    : _repository = repository,
      super(const SoundSyncState());

  final SoundSyncRepository _repository;

  /// Runs one reconcile pass, ignoring re-entrant calls.
  ///
  /// Every emit is guarded by [isClosed]: the user can navigate away mid-pass
  /// and close this cubit while `reconcile()` is still in flight, and
  /// emitting after close throws. A catch-all beneath the two typed catches
  /// guarantees status always reaches a terminal value — an uncaught error
  /// here would otherwise leave `status` stuck at `syncing`, and the guard
  /// at the top of this method would then treat every later call as
  /// already-in-flight, wedging sync permanently for this cubit's lifetime.
  Future<void> syncNow() async {
    if (state.status == SoundSyncStatus.syncing) return;
    if (isClosed) return;
    emit(const SoundSyncState(status: SoundSyncStatus.syncing));

    try {
      final outcome = await _repository.reconcile();
      if (isClosed) return;
      emit(
        SoundSyncState(
          status: SoundSyncStatus.success,
          pulled: outcome.pulled,
          pushed: outcome.pushed,
        ),
      );
    } on VaultKeyUnavailableException catch (e, stackTrace) {
      // Expected during cold start and on relay outages — not Reportable.
      addError(e, stackTrace);
      if (isClosed) return;
      emit(const SoundSyncState(status: SoundSyncStatus.locked));
    } on SyncIndexException catch (e, stackTrace) {
      // Expected on flaky networks — not Reportable.
      addError(e, stackTrace);
      if (isClosed) return;
      emit(const SoundSyncState(status: SoundSyncStatus.failure));
    } catch (e, stackTrace) {
      // Unexpected: e.g. a malformed remote body raising FormatException out
      // of SavedSound.fromJson. This is a programming-invariant violation
      // (the matrix in error_handling.md says YES), so it is wrapped and
      // reported — unlike the two typed catches above, which are expected
      // domain failures and stay unwrapped.
      addError(Reportable(e, context: 'syncNow'), stackTrace);
      if (isClosed) return;
      emit(const SoundSyncState(status: SoundSyncStatus.failure));
    }
  }
}
