import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

part 'video_editor_filter_event.dart';
part 'video_editor_filter_state.dart';

/// BLoC for managing filter selection state in the video editor.
///
/// This BLoC only manages state. Editor interactions (applying filters,
/// closing sub-editors) should be done through [VideoEditorScope] in the UI.
class VideoEditorFilterBloc
    extends Bloc<VideoEditorFilterEvent, VideoEditorFilterState> {
  VideoEditorFilterBloc()
    : super(VideoEditorFilterState(filters: presetFiltersList)) {
    on<VideoEditorFilterEditorInitialized>(_onEditorInitialized);
    on<VideoEditorFilterSelected>(_onFilterSelected);
    on<VideoEditorFilterOpacityChanged>(_onOpacityChanged);
    on<VideoEditorFilterCancelled>(_onCancelled);
  }

  void _onEditorInitialized(
    VideoEditorFilterEditorInitialized event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    // Store current values as initial values for potential cancel
    emit(
      state.copyWith(
        initialSelectedFilter: state.selectedFilter,
        initialOpacity: state.opacity,
      ),
    );
  }

  void _onFilterSelected(
    VideoEditorFilterSelected event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    emit(state.copyWith(selectedFilter: event.filter));
  }

  void _onOpacityChanged(
    VideoEditorFilterOpacityChanged event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    emit(state.copyWith(opacity: event.opacity));
  }

  void _onCancelled(
    VideoEditorFilterCancelled event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    // Restore to initial values from when the editor was opened
    emit(
      state.copyWith(
        selectedFilter: state.initialSelectedFilter,
        opacity: state.initialOpacity,
      ),
    );
  }
}
