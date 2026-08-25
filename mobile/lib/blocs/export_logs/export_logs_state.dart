// ABOUTME: State for the developer-options log export flow
// ABOUTME: Status enum only — the UI maps each outcome to its own l10n string

import 'package:equatable/equatable.dart';

/// Outcome of a log export, as the UI needs to distinguish it.
///
/// Four of these are not failures. Collapsing them into one is what made a
/// working share report "Failed to export logs" (#8113) and an empty capture
/// buffer look like a broken feature rather than a prompt to reproduce first
/// (#8114).
enum ExportLogsStatus {
  idle,
  exporting,

  /// Handed to another app, which confirmed it.
  shared,

  /// Written to a path the user picked, carried in [ExportLogsState.filePath].
  saved,

  /// User backed out of the share sheet or the Save As dialog.
  cancelled,

  /// The capture buffer was empty. It is memory-only, so a crash or a
  /// force-quit empties it.
  noLogs,

  /// The sheet opened but reported no outcome. The share may well have
  /// completed — share_plus cannot tell.
  unconfirmed,

  failed,
}

class ExportLogsState extends Equatable {
  const ExportLogsState({this.status = ExportLogsStatus.idle, this.filePath});

  final ExportLogsStatus status;

  /// Where the file landed, when the platform told us. Only ever set
  /// alongside [ExportLogsStatus.saved].
  final String? filePath;

  @override
  List<Object?> get props => [status, filePath];
}
