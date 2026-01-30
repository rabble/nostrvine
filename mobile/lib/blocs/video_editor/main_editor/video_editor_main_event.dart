part of 'video_editor_main_bloc.dart';

/// Base class for all video editor main events.
sealed class VideoEditorMainEvent extends Equatable {
  const VideoEditorMainEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when editor capabilities change (undo/redo availability, sub-editor state).
///
/// This event carries the current state from the editor widget, allowing the
/// BLoC to update its state without directly accessing the widget.
class VideoEditorMainCapabilitiesChanged extends VideoEditorMainEvent {
  const VideoEditorMainCapabilitiesChanged({
    required this.canUndo,
    required this.canRedo,
    required this.isSubEditorOpen,
  });

  final bool canUndo;
  final bool canRedo;
  final bool isSubEditorOpen;

  @override
  List<Object?> get props => [canUndo, canRedo, isSubEditorOpen];
}

/// Triggered when layer interaction (scaling/rotating) starts.
class VideoEditorLayerInteractionStarted extends VideoEditorMainEvent {
  const VideoEditorLayerInteractionStarted();
}

/// Triggered when layer interaction (scaling/rotating) ends.
class VideoEditorLayerInteractionEnded extends VideoEditorMainEvent {
  const VideoEditorLayerInteractionEnded();
}
