import 'package:equatable/equatable.dart';

/// What the staging-patch section is currently doing or reporting.
enum ShorebirdPatchStatus {
  /// Nothing requested yet.
  initial,

  /// The updater is absent from this build — debug, simulator, or any binary
  /// not produced by `shorebird release`.
  unavailable,

  /// A staging-track check is in flight.
  checking,

  /// A staged patch is available to download and apply.
  updateAvailable,

  /// The staging track holds nothing newer than what is already installed.
  upToDate,

  /// A staged patch is downloading and installing.
  applying,

  /// A staged patch was installed. It takes effect on the next launch.
  applied,

  /// The check or apply failed. The reason goes to `addError`, never here.
  failure,
}

/// State for the developer-options staging-patch section.
class ShorebirdPatchState extends Equatable {
  const ShorebirdPatchState({
    this.status = ShorebirdPatchStatus.initial,
    this.currentPatchNumber,
  });

  final ShorebirdPatchStatus status;

  /// Patch number currently running, or `null` when the release build is
  /// running unpatched. Reported so a tester can name exactly what they
  /// validated.
  final int? currentPatchNumber;

  /// Whether a check or apply is in flight, so the UI can disable both
  /// actions rather than letting them overlap.
  bool get isBusy =>
      status == ShorebirdPatchStatus.checking ||
      status == ShorebirdPatchStatus.applying;

  /// Whether this build can talk to the updater at all.
  bool get isAvailable => status != ShorebirdPatchStatus.unavailable;

  ShorebirdPatchState copyWith({
    ShorebirdPatchStatus? status,
    int? currentPatchNumber,
    bool clearCurrentPatchNumber = false,
  }) {
    return ShorebirdPatchState(
      status: status ?? this.status,
      currentPatchNumber: clearCurrentPatchNumber
          ? null
          : currentPatchNumber ?? this.currentPatchNumber,
    );
  }

  @override
  List<Object?> get props => [status, currentPatchNumber];
}
