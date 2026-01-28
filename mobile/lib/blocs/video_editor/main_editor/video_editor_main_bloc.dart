import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

part 'video_editor_main_event.dart';
part 'video_editor_main_state.dart';

/// BLoC for managing the video editor main screen state.
///
/// Handles:
/// - Undo/Redo availability and actions
/// - Layer interaction state (scaling/rotating)
/// - Sub-editor open state and navigation
/// - Close/Done actions
class VideoEditorMainBloc
    extends Bloc<VideoEditorMainEvent, VideoEditorMainState> {
  VideoEditorMainBloc({
    required GlobalKey<ProImageEditorState> editorKey,
    required this.onClose,
    required this.onAddStickers,
  }) : _editorKey = editorKey,
       super(const VideoEditorMainState()) {
    on<VideoEditorMainLayerChanged>(_onCapabilitiesChanged);
    on<VideoEditorMainUndoPerformed>(_onCapabilitiesChanged);
    on<VideoEditorMainRedoPerformed>(_onCapabilitiesChanged);
    on<VideoEditorMainCloseRequested>(_onCloseRequested);
    on<VideoEditorMainUndoRequested>(_onUndoRequested);
    on<VideoEditorMainRedoRequested>(_onRedoRequested);
    on<VideoEditorMainDoneRequested>(_onDoneRequested);
    on<VideoEditorLayerInteractionStarted>(_onLayerInteractionStarted);
    on<VideoEditorLayerInteractionEnded>(_onLayerInteractionEnded);
    on<VideoEditorMainOpenSubEditor>(_onOpenSubEditor);
  }

  final GlobalKey<ProImageEditorState> _editorKey;
  final VoidCallback onClose;
  final VoidCallback onAddStickers;

  ProImageEditorState? get _editor => _editorKey.currentState;

  /// Handles any event that may affect undo/redo/subEditor state.
  void _onCapabilitiesChanged(
    VideoEditorMainEvent event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(
      state.copyWith(
        canUndo: _editor?.canUndo ?? false,
        canRedo: _editor?.canRedo ?? false,
        isSubEditorOpen: _editor?.isSubEditorOpen ?? false,
      ),
    );
  }

  void _onCloseRequested(
    VideoEditorMainCloseRequested event,
    Emitter<VideoEditorMainState> emit,
  ) {
    if (state.isSubEditorOpen) {
      _editor?.closeSubEditor();
    } else {
      onClose();
    }
  }

  void _onUndoRequested(
    VideoEditorMainUndoRequested event,
    Emitter<VideoEditorMainState> emit,
  ) {
    _editor?.undoAction();
  }

  void _onRedoRequested(
    VideoEditorMainRedoRequested event,
    Emitter<VideoEditorMainState> emit,
  ) {
    _editor?.redoAction();
  }

  void _onDoneRequested(
    VideoEditorMainDoneRequested event,
    Emitter<VideoEditorMainState> emit,
  ) {
    _editor?.doneEditing();
  }

  void _onLayerInteractionStarted(
    VideoEditorLayerInteractionStarted event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isLayerInteractionActive: true));
  }

  void _onLayerInteractionEnded(
    VideoEditorLayerInteractionEnded event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(isLayerInteractionActive: false));
  }

  void _onOpenSubEditor(
    VideoEditorMainOpenSubEditor event,
    Emitter<VideoEditorMainState> emit,
  ) {
    switch (event.type) {
      case SubEditorType.text:
        _editor?.openTextEditor();
      case SubEditorType.paint:
        _editor?.openPaintEditor();
      case SubEditorType.filter:
        _editor?.openFilterEditor();
      case SubEditorType.stickers:
        onAddStickers();
      case SubEditorType.music:
        // TODO(@hm21): Implement music editor
        break;
    }
  }
}
