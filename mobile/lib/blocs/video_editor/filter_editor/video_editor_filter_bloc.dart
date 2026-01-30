import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

part 'video_editor_filter_event.dart';
part 'video_editor_filter_state.dart';

/// BLoC for managing filter selection and adjustment in the video editor.
class VideoEditorFilterBloc
    extends Bloc<VideoEditorFilterEvent, VideoEditorFilterState> {
  VideoEditorFilterBloc({required this.editorKey})
    : super(VideoEditorFilterState(filters: presetFiltersList)) {
    on<VideoEditorFilterEditorInitialized>(_onEditorInitialized);
    on<VideoEditorFilterSelected>(_onFilterSelected);
    on<VideoEditorFilterOpacityChanged>(_onOpacityChanged);
    on<VideoEditorFilterCancelRequested>(_onCancelRequested);
    on<VideoEditorFilterDoneRequested>(_onDoneRequested);
  }

  /// Key to access the [ProImageEditorState] for applying filters.
  final GlobalKey<ProImageEditorState> editorKey;
  ProImageEditorState? get _editor => editorKey.currentState;
  FilterEditorState? get _filterEditor => _editor?.filterEditor.currentState;

  /// Currently active filters from the editor state.
  FilterMatrix get activeFilters => _editor?.stateManager.activeFilters ?? [];

  /// Currently active tune adjustments from the editor state.
  List<TuneAdjustmentMatrix> get activeTuneAdjustments =>
      _editor?.stateManager.activeTuneAdjustments ?? [];

  /// Current blur factor from the editor state.
  double get activeBlur => _editor?.stateManager.activeBlur ?? 0;

  void _onEditorInitialized(
    VideoEditorFilterEditorInitialized event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    // Store current values as initial values for potential cancel
    emit(
      VideoEditorFilterState(
        filters: state.filters,
        selectedFilter: state.selectedFilter,
        opacity: state.opacity,
        initialSelectedFilter: state.selectedFilter,
        initialOpacity: state.opacity,
      ),
    );

    // Sync editor with current state
    _filterEditor?.setFilter(state.selectedFilter ?? PresetFilters.none);
    _filterEditor?.setFilterOpacity(state.opacity);
  }

  void _onFilterSelected(
    VideoEditorFilterSelected event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    if (_filterEditor == null) return;

    _filterEditor!.setFilter(event.filter);

    emit(state.copyWith(selectedFilter: event.filter));
  }

  void _onOpacityChanged(
    VideoEditorFilterOpacityChanged event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    if (_filterEditor == null || state.selectedFilter == null) return;

    _filterEditor!.setFilterOpacity(event.opacity);

    emit(state.copyWith(opacity: event.opacity));
  }

  void _onCancelRequested(
    VideoEditorFilterCancelRequested event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    _editor?.closeSubEditor();

    // Restore to initial values from when the editor was opened
    emit(
      VideoEditorFilterState(
        filters: state.filters,
        selectedFilter: state.initialSelectedFilter,
        opacity: state.initialOpacity,
        initialSelectedFilter: state.initialSelectedFilter,
        initialOpacity: state.initialOpacity,
      ),
    );
  }

  void _onDoneRequested(
    VideoEditorFilterDoneRequested event,
    Emitter<VideoEditorFilterState> emit,
  ) {
    _filterEditor?.done();
  }
}
