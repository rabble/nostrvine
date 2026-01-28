part of 'video_editor_main_bloc.dart';

/// Base class for all video editor main events.
sealed class VideoEditorMainEvent extends Equatable {
  const VideoEditorMainEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when a layer is added, removed, or modified.
class VideoEditorMainLayerChanged extends VideoEditorMainEvent {
  const VideoEditorMainLayerChanged();
}

/// Triggered when the close/back button is tapped.
class VideoEditorMainCloseRequested extends VideoEditorMainEvent {
  const VideoEditorMainCloseRequested();
}

/// Triggered when undo action is requested (from UI button).
class VideoEditorMainUndoRequested extends VideoEditorMainEvent {
  const VideoEditorMainUndoRequested();
}

/// Triggered when redo action is requested (from UI button).
class VideoEditorMainRedoRequested extends VideoEditorMainEvent {
  const VideoEditorMainRedoRequested();
}

/// Triggered when undo was performed (from editor callback).
class VideoEditorMainUndoPerformed extends VideoEditorMainEvent {
  const VideoEditorMainUndoPerformed();
}

/// Triggered when redo was performed (from editor callback).
class VideoEditorMainRedoPerformed extends VideoEditorMainEvent {
  const VideoEditorMainRedoPerformed();
}

/// Triggered when done/complete action is requested.
class VideoEditorMainDoneRequested extends VideoEditorMainEvent {
  const VideoEditorMainDoneRequested();
}

/// Triggered when layer interaction (scaling/rotating) starts.
class VideoEditorLayerInteractionStarted extends VideoEditorMainEvent {
  const VideoEditorLayerInteractionStarted();
}

/// Triggered when layer interaction (scaling/rotating) ends.
class VideoEditorLayerInteractionEnded extends VideoEditorMainEvent {
  const VideoEditorLayerInteractionEnded();
}

/// Triggered when a sub-editor (text, paint, filter) should be opened.
class VideoEditorMainOpenSubEditor extends VideoEditorMainEvent {
  const VideoEditorMainOpenSubEditor(this.type);

  final SubEditorType type;

  @override
  List<Object?> get props => [type];
}

/// Types of sub-editors that can be opened.
enum SubEditorType { text, paint, filter, stickers, music }
