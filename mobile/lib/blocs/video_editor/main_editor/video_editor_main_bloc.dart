import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  VideoEditorMainBloc() : super(const VideoEditorMainState()) {
    on<VideoEditorMainCapabilitiesChanged>(_onCapabilitiesChanged);
    on<VideoEditorLayerInteractionStarted>(_onLayerInteractionStarted);
    on<VideoEditorLayerInteractionEnded>(_onLayerInteractionEnded);
    on<VideoEditorLayerOverRemoveAreaChanged>(_onLayerOverRemoveAreaChanged);
    on<VideoEditorMainOpenSubEditor>(_onOpenSubEditor);
    on<VideoEditorMainSubEditorClosed>(_onSubEditorClosed);
  }

  /// Updates undo/redo/subEditor state based on editor capabilities.
  void _onCapabilitiesChanged(
    VideoEditorMainCapabilitiesChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(canUndo: event.canUndo, canRedo: event.canRedo));
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
    emit(
      state.copyWith(
        isLayerInteractionActive: false,
        isLayerOverRemoveArea: false,
      ),
    );
  }

  void _onLayerOverRemoveAreaChanged(
    VideoEditorLayerOverRemoveAreaChanged event,
    Emitter<VideoEditorMainState> emit,
  ) {
    if (state.isLayerOverRemoveArea != event.isOver) {
      emit(state.copyWith(isLayerOverRemoveArea: event.isOver));
    }
  }

  void _onOpenSubEditor(
    VideoEditorMainOpenSubEditor event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(openSubEditor: event.type));
  }

  void _onSubEditorClosed(
    VideoEditorMainSubEditorClosed event,
    Emitter<VideoEditorMainState> emit,
  ) {
    emit(state.copyWith(clearOpenSubEditor: true));
  }
}
