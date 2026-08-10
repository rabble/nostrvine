// ABOUTME: State for the sound library sync cubit.
// ABOUTME: Status enum only; error text is resolved in the UI via l10n.

import 'package:equatable/equatable.dart';

/// Lifecycle of a sound library sync pass.
enum SoundSyncStatus {
  /// No pass has run yet.
  idle,

  /// A pass is in flight.
  syncing,

  /// The last pass completed.
  success,

  /// The vault key could not be obtained; sync is unavailable.
  locked,

  /// The last pass failed for a transient reason.
  failure,
}

/// Observable state of sound library sync.
class SoundSyncState extends Equatable {
  /// Creates a [SoundSyncState].
  const SoundSyncState({
    this.status = SoundSyncStatus.idle,
    this.pulled = 0,
    this.pushed = 0,
  });

  /// Current lifecycle status.
  final SoundSyncStatus status;

  /// Sounds pulled from other devices in the last successful pass.
  final int pulled;

  /// Sounds published in the last successful pass.
  final int pushed;

  @override
  List<Object?> get props => [status, pulled, pushed];
}
