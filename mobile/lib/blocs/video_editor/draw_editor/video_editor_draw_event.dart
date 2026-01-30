part of 'video_editor_draw_bloc.dart';

/// Base class for all video editor draw events.
sealed class VideoEditorDrawEvent extends Equatable {
  const VideoEditorDrawEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the filter editor is initialized.
class VideoEditorDrawEditorInitialized extends VideoEditorDrawEvent {
  const VideoEditorDrawEditorInitialized();
}

/// Triggered when a layer is added, removed, or modified.
class VideoEditorDrawLayerChanged extends VideoEditorDrawEvent {
  const VideoEditorDrawLayerChanged();
}

/// Triggered when draw capabilities may have changed (e.g., after drawing).
class VideoEditorDrawCapabilitiesChanged extends VideoEditorDrawEvent {
  const VideoEditorDrawCapabilitiesChanged();
}

/// Triggered when the close/back button is tapped.
class VideoEditorDrawCloseRequested extends VideoEditorDrawEvent {
  const VideoEditorDrawCloseRequested();
}

/// Triggered when undo action is requested.
class VideoEditorDrawUndoRequested extends VideoEditorDrawEvent {
  const VideoEditorDrawUndoRequested();
}

/// Triggered when redo action is requested.
class VideoEditorDrawRedoRequested extends VideoEditorDrawEvent {
  const VideoEditorDrawRedoRequested();
}

/// Triggered when done/complete action is requested.
class VideoEditorDrawDoneRequested extends VideoEditorDrawEvent {
  const VideoEditorDrawDoneRequested();
}

/// Triggered when undo was performed (from editor callback).
class VideoEditorDrawUndoPerformed extends VideoEditorDrawEvent {
  const VideoEditorDrawUndoPerformed();
}

/// Triggered when redo was performed (from editor callback).
class VideoEditorDrawRedoPerformed extends VideoEditorDrawEvent {
  const VideoEditorDrawRedoPerformed();
}

/// Triggered when a drawing tool is selected.
class VideoEditorDrawToolSelected extends VideoEditorDrawEvent {
  const VideoEditorDrawToolSelected(this.tool);

  final DrawToolType tool;

  @override
  List<Object?> get props => [tool];
}

/// Triggered when a drawing color is selected.
class VideoEditorDrawColorSelected extends VideoEditorDrawEvent {
  const VideoEditorDrawColorSelected(this.color);

  final Color color;

  @override
  List<Object?> get props => [color];
}
