// ABOUTME: Drives sound library reconciliation and exposes its status.
// ABOUTME: Maps expected sync failures to statuses, never to state strings.

import 'package:bloc/bloc.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:openvine/blocs/creator_sync/sound_sync_state.dart';

/// Runs sound library sync passes on demand.
class SoundSyncCubit extends Cubit<SoundSyncState> {
  /// Creates a [SoundSyncCubit].
  SoundSyncCubit({required SoundSyncRepository repository})
    : _repository = repository,
      super(const SoundSyncState());

  final SoundSyncRepository _repository;

  /// Runs one reconcile pass, ignoring re-entrant calls.
  Future<void> syncNow() async {
    if (state.status == SoundSyncStatus.syncing) return;
    emit(const SoundSyncState(status: SoundSyncStatus.syncing));

    try {
      final outcome = await _repository.reconcile();
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
      emit(const SoundSyncState(status: SoundSyncStatus.locked));
    } on SyncIndexException catch (e, stackTrace) {
      // Expected on flaky networks — not Reportable.
      addError(e, stackTrace);
      emit(const SoundSyncState(status: SoundSyncStatus.failure));
    }
  }
}
