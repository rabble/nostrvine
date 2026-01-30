part of 'video_editor_filter_bloc.dart';

/// State for the video editor filter selection.
class VideoEditorFilterState extends Equatable {
  const VideoEditorFilterState({
    required this.filters,
    this.selectedFilter,
    this.opacity = 1.0,
    this.initialSelectedFilter,
    this.initialOpacity = 1.0,
  });

  /// List of available filters.
  final List<FilterModel> filters;

  /// The currently selected filter, or `null` if no filter is applied.
  final FilterModel? selectedFilter;

  /// The opacity of the filter (0.0 - 1.0).
  final double opacity;

  /// The filter that was selected when the editor was initialized.
  /// Used to restore on cancel.
  final FilterModel? initialSelectedFilter;

  /// The opacity that was set when the editor was initialized.
  /// Used to restore on cancel.
  final double initialOpacity;

  /// Whether a filter is currently selected (not "None").
  bool get hasFilter =>
      selectedFilter != null && selectedFilter != PresetFilters.none;

  /// Whether the given filter is the currently selected one.
  bool isSelected(FilterModel filter) =>
      selectedFilter?.name == filter.name ||
      (selectedFilter == null && filter == PresetFilters.none);

  /// Creates a copy of this state with optionally updated values.
  VideoEditorFilterState copyWith({
    List<FilterModel>? filters,
    FilterModel? selectedFilter,
    double? opacity,
    FilterModel? initialSelectedFilter,
    double? initialOpacity,
  }) {
    return VideoEditorFilterState(
      filters: filters ?? this.filters,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      opacity: opacity ?? this.opacity,
      initialSelectedFilter:
          initialSelectedFilter ?? this.initialSelectedFilter,
      initialOpacity: initialOpacity ?? this.initialOpacity,
    );
  }

  @override
  List<Object?> get props => [
    filters,
    selectedFilter,
    opacity,
    initialSelectedFilter,
    initialOpacity,
  ];
}
