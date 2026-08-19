// ABOUTME: Exposes app-scoped DM history-recovery status to screens that need
// ABOUTME: to qualify an empty view, so "no messages" is not asserted while
// ABOUTME: recovery is still in flight or stopped short of finishing.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/close_guard.dart';

/// Whether DM history recovery still owes the user messages.
class DmRestoreStatusState extends Equatable {
  const DmRestoreStatusState({
    this.isRestoring = false,
    this.hasAttempted = false,
    this.isComplete = true,
  });

  /// A recovery pass (reinstall backfill or failed-decrypt replay) is running.
  final bool isRestoring;

  /// History recovery has run, completed, or is running for this user.
  final bool hasAttempted;

  /// The one-time history drain has completed cleanly for this user.
  ///
  /// Defaults to `true` so a screen never claims history is missing before the
  /// repository has answered — the same fail-open stance as
  /// [DmRepository.isHistoryRecoveryComplete], which returns `true` when it has
  /// no sync state or pubkey to consult.
  final bool isComplete;

  /// Whether an empty view might simply not have its messages yet.
  bool get mayBeIncomplete => isRestoring || (hasAttempted && !isComplete);

  @override
  List<Object?> get props => [isRestoring, hasAttempted, isComplete];
}

/// Publishes [DmRepository]'s app-scoped recovery signals as bloc state.
///
/// Deliberately separate from `ConversationBloc` rather than a third stream in
/// its `combineLatest`. That bloc's emission sequence is contract — its tests
/// pin exact `[loading, loaded]` lists and mark-as-read call counts — and
/// recovery status is app-scoped, not per-conversation, so folding it in would
/// couple two different lifetimes for no gain.
class DmRestoreStatusCubit extends Cubit<DmRestoreStatusState>
    with CloseGuardedEmit<DmRestoreStatusState> {
  DmRestoreStatusCubit({required DmRepository dmRepository})
    : _dmRepository = dmRepository,
      super(
        DmRestoreStatusState(
          isRestoring: dmRepository.isRecoveringHistory,
          hasAttempted: dmRepository.hasAttemptedHistoryRecovery,
          isComplete: dmRepository.isHistoryRecoveryComplete,
        ),
      ) {
    // `historyRecoveryStream` does not replay, hence the constructor seed above.
    _subscription = _dmRepository.historyRecoveryStream.listen((isRestoring) {
      // Re-read the persisted flag on every tick: it is what actually gates the
      // request split, and it only flips on a clean drain exhaustion. A pass
      // that stops at the page cap, throws, or finds no connected relay ends
      // with isRestoring false while this stays false too.
      emitIfOpen(
        DmRestoreStatusState(
          isRestoring: isRestoring,
          hasAttempted: _dmRepository.hasAttemptedHistoryRecovery,
          isComplete: _dmRepository.isHistoryRecoveryComplete,
        ),
      );
    });
  }

  final DmRepository _dmRepository;
  late final StreamSubscription<bool> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
