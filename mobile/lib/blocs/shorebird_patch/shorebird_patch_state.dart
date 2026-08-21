import 'package:equatable/equatable.dart';

/// What the staging-patch validation flow is doing or reporting.
enum ShorebirdPatchValidationStatus {
  loading,
  notChecked,
  unavailable,
  checking,
  updateAvailable,
  upToDate,
  restartRequired,
  rollbackRequired,
  applying,
  applied,
  unchanged,
  selectingStableTrack,
  stableRestored,
  failure,
}

/// State for the developer-options staging-patch section.
class ShorebirdPatchState extends Equatable {
  const ShorebirdPatchState({
    this.status = ShorebirdPatchValidationStatus.loading,
    this.currentPatchNumber,
    this.usesStagingTrack = false,
  });

  final ShorebirdPatchValidationStatus status;
  final int? currentPatchNumber;
  final bool usesStagingTrack;

  bool get isBusy =>
      status == ShorebirdPatchValidationStatus.loading ||
      status == ShorebirdPatchValidationStatus.checking ||
      status == ShorebirdPatchValidationStatus.applying ||
      status == ShorebirdPatchValidationStatus.selectingStableTrack;

  bool get isAvailable => status != ShorebirdPatchValidationStatus.unavailable;

  bool get canApply => status == ShorebirdPatchValidationStatus.updateAvailable;

  ShorebirdPatchState copyWith({
    ShorebirdPatchValidationStatus? status,
    int? currentPatchNumber,
    bool clearCurrentPatchNumber = false,
    bool? usesStagingTrack,
  }) {
    return ShorebirdPatchState(
      status: status ?? this.status,
      currentPatchNumber: clearCurrentPatchNumber
          ? null
          : currentPatchNumber ?? this.currentPatchNumber,
      usesStagingTrack: usesStagingTrack ?? this.usesStagingTrack,
    );
  }

  @override
  List<Object?> get props => [status, currentPatchNumber, usesStagingTrack];
}
