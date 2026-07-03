part of 'video_editor_tune_bloc.dart';

/// Base class for all video editor tune-adjustment events.
sealed class VideoEditorTuneEvent extends Equatable {
  const VideoEditorTuneEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the tune editor is initialized.
///
/// Seeds the session values from the adjustments already applied to the clip
/// and snapshots them so a cancel can restore the pre-open state.
class VideoEditorTuneEditorInitialized extends VideoEditorTuneEvent {
  const VideoEditorTuneEditorInitialized(this.activeAdjustments);

  /// The tune adjustments currently applied to the clip.
  final List<TuneAdjustmentMatrix> activeAdjustments;

  @override
  List<Object?> get props => [activeAdjustments];
}

/// Triggered when the user selects a different adjustment to tune.
class VideoEditorTuneAdjustmentSelected extends VideoEditorTuneEvent {
  const VideoEditorTuneAdjustmentSelected(this.index);

  /// The index of the selected adjustment in
  /// [VideoEditorTuneState.adjustments].
  final int index;

  @override
  List<Object?> get props => [index];
}

/// Triggered when the value of the selected adjustment changes.
class VideoEditorTuneValueChanged extends VideoEditorTuneEvent {
  const VideoEditorTuneValueChanged(this.value);

  /// The new value for the currently selected adjustment.
  final double value;

  @override
  List<Object?> get props => [value];
}

/// Triggered when the user cancels tune editing.
///
/// Restores the values captured when the editor was opened. The UI is
/// responsible for closing the sub-editor via [VideoEditorScope].
class VideoEditorTuneCancelled extends VideoEditorTuneEvent {
  const VideoEditorTuneCancelled();
}

/// Triggered when the user confirms the tune adjustments (presses done).
class VideoEditorTuneConfirmed extends VideoEditorTuneEvent {
  const VideoEditorTuneConfirmed();
}
