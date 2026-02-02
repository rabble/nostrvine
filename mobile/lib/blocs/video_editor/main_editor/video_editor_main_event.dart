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
  });

  final bool canUndo;
  final bool canRedo;

  @override
  List<Object?> get props => [canUndo, canRedo];
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

/// Triggered when a sub-editor is closed.
class VideoEditorMainSubEditorClosed extends VideoEditorMainEvent {
  const VideoEditorMainSubEditorClosed();
}

/// Types of sub-editors that can be opened.
enum SubEditorType { text, draw, filter, stickers, music }
