part of 'clip_recovery_cubit.dart';

/// Lifecycle of the clip-recovery section.
enum ClipRecoveryStatus {
  /// Nothing scanned yet.
  idle,

  /// A scan is running.
  scanning,

  /// Scan complete; see [ClipRecoveryState.report].
  scanned,

  /// An owner group is being restamped.
  claiming,

  /// A claim finished; [ClipRecoveryState.lastRecoveredCount] holds how many
  /// clip rows moved.
  claimed,

  /// Unreferenced files are being rebuilt into library rows.
  importing,

  /// An import finished; [ClipRecoveryState.lastRecoveredCount] holds how many
  /// clips were rebuilt.
  imported,

  /// The last recovery operation failed.
  failure,
}

/// State for the developer clip-recovery section.
class ClipRecoveryState extends Equatable {
  /// Creates a state.
  const ClipRecoveryState({
    this.status = ClipRecoveryStatus.idle,
    this.report = ClipRecoveryReport.empty,
    this.lastRecoveredCount = 0,
    this.hasReport = false,
  });

  /// Lifecycle of the section.
  final ClipRecoveryStatus status;

  /// What the last scan found.
  final ClipRecoveryReport report;

  /// How many clips the last claim or import recovered.
  final int lastRecoveredCount;

  /// Whether a scan has produced [report], so the UI can render it.
  ///
  /// Tracked separately from [status] rather than derived from it, because a
  /// later action can fail without invalidating the report the scan produced —
  /// and that report is the whole output of the tool, the thing the operator
  /// copies into the support thread. Deriving this from the status would take
  /// the findings off screen at exactly the moment they matter most.
  final bool hasReport;

  /// Whether an operation is in flight, so the UI can disable its actions.
  bool get isBusy =>
      status == ClipRecoveryStatus.scanning ||
      status == ClipRecoveryStatus.claiming ||
      status == ClipRecoveryStatus.importing;

  /// Returns a copy with the given fields replaced.
  ClipRecoveryState copyWith({
    ClipRecoveryStatus? status,
    ClipRecoveryReport? report,
    int? lastRecoveredCount,
    bool? hasReport,
  }) {
    return ClipRecoveryState(
      status: status ?? this.status,
      report: report ?? this.report,
      lastRecoveredCount: lastRecoveredCount ?? this.lastRecoveredCount,
      hasReport: hasReport ?? this.hasReport,
    );
  }

  @override
  List<Object?> get props => [
    status,
    report,
    lastRecoveredCount,
    hasReport,
  ];
}
