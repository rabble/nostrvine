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
    this.layers,
  });

  final bool canUndo;
  final bool canRedo;

  /// The current list of active layers, or `null` if unchanged.
  final List<Layer>? layers;

  @override
  List<Object?> get props => [canUndo, canRedo, layers];
}

/// Triggered when layer interaction (scaling/rotating) starts.
class VideoEditorLayerInteractionStarted extends VideoEditorMainEvent {
  const VideoEditorLayerInteractionStarted();
}

/// Triggered when layer interaction (scaling/rotating) ends.
class VideoEditorLayerInteractionEnded extends VideoEditorMainEvent {
  const VideoEditorLayerInteractionEnded();
}

/// Triggered when the layer position relative to the remove area changes.
class VideoEditorLayerOverRemoveAreaChanged extends VideoEditorMainEvent {
  const VideoEditorLayerOverRemoveAreaChanged({required this.isOver});

  final bool isOver;

  @override
  List<Object?> get props => [isOver];
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

/// Triggered when a layer is added to the editor.
class VideoEditorLayerAdded extends VideoEditorMainEvent {
  const VideoEditorLayerAdded(this.layer);

  final Layer layer;

  @override
  List<Object?> get props => [layer];
}

/// Triggered when a layer is removed from the editor.
class VideoEditorLayerRemoved extends VideoEditorMainEvent {
  const VideoEditorLayerRemoved(this.layer);

  final Layer layer;

  @override
  List<Object?> get props => [layer];
}

/// Types of sub-editors that can be opened.
enum SubEditorType { text, draw, filter, stickers, music }
