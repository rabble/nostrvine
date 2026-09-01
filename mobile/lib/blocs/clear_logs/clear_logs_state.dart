// ABOUTME: State for the Support Center clear-logs action
// ABOUTME: Transient clearing state lets a repeat clear re-notify the UI

import 'package:equatable/equatable.dart';

/// Outcome of clearing the in-memory log capture buffer.
enum ClearLogsStatus {
  idle,

  /// The clear is in flight. Emitted before [cleared] so a repeat clear still
  /// produces a state change the UI can react to.
  clearing,

  /// The buffer was emptied.
  cleared,
}

class ClearLogsState extends Equatable {
  const ClearLogsState({this.status = ClearLogsStatus.idle});

  final ClearLogsStatus status;

  @override
  List<Object?> get props => [status];
}
