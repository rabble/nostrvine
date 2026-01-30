import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

part 'video_editor_draw_event.dart';
part 'video_editor_draw_state.dart';

/// BLoC for managing the video editor draw/paint functionality.
///
/// Handles:
/// - Tool selection (pencil, marker, arrow, eraser)
/// - Color selection for drawing
/// - Undo/redo operations
/// - Synchronization with [PaintEditorState]
class VideoEditorDrawBloc
    extends Bloc<VideoEditorDrawEvent, VideoEditorDrawState> {
  /// Creates a [VideoEditorDrawBloc] with the given [editorKey].
  ///
  /// The [editorKey] is used to access the [ProImageEditorState] and its
  /// paint editor for drawing operations.
  VideoEditorDrawBloc({required GlobalKey<ProImageEditorState> editorKey})
    : this.editorKey = editorKey,
      super(const VideoEditorDrawState()) {
    on<VideoEditorDrawEditorInitialized>(_onEditorInitialized);
    on<VideoEditorDrawCapabilitiesChanged>(_onCapabilitiesChanged);
    on<VideoEditorDrawLayerChanged>(_onCapabilitiesChanged);
    on<VideoEditorDrawUndoPerformed>(_onCapabilitiesChanged);
    on<VideoEditorDrawRedoPerformed>(_onCapabilitiesChanged);
    on<VideoEditorDrawCloseRequested>(_onCloseRequested);
    on<VideoEditorDrawUndoRequested>(_onUndoRequested);
    on<VideoEditorDrawRedoRequested>(_onRedoRequested);
    on<VideoEditorDrawDoneRequested>(_onDoneRequested);
    on<VideoEditorDrawToolSelected>(_onToolSelected);
    on<VideoEditorDrawColorSelected>(_onColorSelected);
  }

  /// Key to access the [ProImageEditorState] for paint operations.
  final GlobalKey<ProImageEditorState> editorKey;

  ProImageEditorState? get _editor => editorKey.currentState;
  PaintEditorState? get _paintEditor => _editor?.paintEditor.currentState;

  /// Synchronizes the paint editor with the current BLoC state on initialization.
  void _onEditorInitialized(
    VideoEditorDrawEditorInitialized event,
    Emitter<VideoEditorDrawState> emit,
  ) {
    _paintEditor
      ?..setColor(state.selectedColor)
      ..setStrokeWidth(state.strokeWidth)
      ..setOpacity(state.opacity)
      ..setMode(state.mode);
  }

  /// Updates undo/redo availability after any drawing change.
  void _onCapabilitiesChanged(
    VideoEditorDrawEvent event,
    Emitter<VideoEditorDrawState> emit,
  ) {
    emit(
      state.copyWith(
        canUndo: _paintEditor?.canUndo ?? false,
        canRedo: _paintEditor?.canRedo ?? false,
      ),
    );
  }

  /// Closes the draw editor and returns to the main editor.
  void _onCloseRequested(
    VideoEditorDrawCloseRequested event,
    Emitter<VideoEditorDrawState> emit,
  ) {
    _editor?.closeSubEditor();
  }

  /// Undoes the last drawing action.
  void _onUndoRequested(
    VideoEditorDrawUndoRequested event,
    Emitter<VideoEditorDrawState> emit,
  ) {
    _paintEditor?.undoAction();
  }

  /// Redoes a previously undone drawing action.
  void _onRedoRequested(
    VideoEditorDrawRedoRequested event,
    Emitter<VideoEditorDrawState> emit,
  ) {
    _paintEditor?.redoAction();
  }

  /// Confirms and applies all drawing changes.
  void _onDoneRequested(
    VideoEditorDrawDoneRequested event,
    Emitter<VideoEditorDrawState> emit,
  ) {
    _paintEditor?.done();
  }

  /// Updates the drawing color in both state and paint editor.
  void _onColorSelected(
    VideoEditorDrawColorSelected event,
    Emitter<VideoEditorDrawState> emit,
  ) {
    _paintEditor?.setColor(event.color);
    emit(state.copyWith(selectedColor: event.color));
  }

  /// Applies the selected tool configuration to state and paint editor.
  void _onToolSelected(
    VideoEditorDrawToolSelected event,
    Emitter<VideoEditorDrawState> emit,
  ) {
    if (_paintEditor == null) return;
    final tool = event.tool;

    final config = _getToolConfig(tool);

    _paintEditor!
      ..setMode(config.mode)
      ..setOpacity(config.opacity)
      ..setStrokeWidth(config.strokeWidth);

    emit(
      state.copyWith(
        selectedTool: tool,
        mode: config.mode,
        opacity: config.opacity,
        strokeWidth: config.strokeWidth,
      ),
    );
  }

  /// Returns the paint configuration for a given [DrawToolType].
  ({PaintMode mode, double opacity, double strokeWidth}) _getToolConfig(
    DrawToolType tool,
  ) {
    return switch (tool) {
      .pencil => (mode: .freeStyle, opacity: 1.0, strokeWidth: 6.0),
      .marker => (mode: .freeStyle, opacity: 0.7, strokeWidth: 12.0),
      .arrow => (mode: .freeStyleArrowEnd, opacity: 1.0, strokeWidth: 8.0),
      .eraser => (mode: .eraser, opacity: 1.0, strokeWidth: 12.0),
    };
  }
}
