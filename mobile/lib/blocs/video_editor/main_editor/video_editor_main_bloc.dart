import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'video_editor_main_event.dart';
part 'video_editor_main_state.dart';

/// BLoC for managing the video editor main screen UI state.
///
/// Handles:
/// - Undo/Redo availability tracking
/// - Layer interaction state (scaling/rotating)
/// - Sub-editor open state tracking
///
/// Note: This BLoC only manages UI state. Editor actions (undo, redo, etc.)
/// should be called directly on the editor via its GlobalKey.
class VideoEditorMainBloc
    extends Bloc<VideoEditorMainEvent, VideoEditorMainState> {
  VideoEditorMainBloc() : super(const VideoEditorMainState()) {
    on<VideoEditorMainCapabilitiesChanged>(_onCapabilitiesChanged);
    on<VideoEditorLayerInteractionStarted>(_onLayerInteractionStarted);
    on<VideoEditorLayerInteractionEnded>(_onLayerInteractionEnded);
  }

  /// Updates undo/redo/subEditor state based on editor capabilities.
  void _onCapabilitiesChanged(
    VideoEditorMainCapabilitiesChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(
      state.copyWith(
        canUndo: event.canUndo,
        canRedo: event.canRedo,
        isSubEditorOpen: event.isSubEditorOpen,
      ),
    );
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
}
