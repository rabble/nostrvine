part of 'video_editor_tune_bloc.dart';

/// State for the video editor tune adjustments.
class VideoEditorTuneState extends Equatable {
  const VideoEditorTuneState({
    required this.adjustments,
    this.selectedIndex = 0,
    this.values = const {},
    this.initialValues = const {},
    this.editingSetId,
  });

  /// The available tune adjustment options, in display order.
  final List<TuneAdjustmentItem> adjustments;

  /// Index of the currently selected adjustment in [adjustments].
  final int selectedIndex;

  /// Current value per adjustment id. A missing id means the adjustment is at
  /// its neutral value (`0`).
  final Map<String, double> values;

  /// Snapshot of [values] captured when the editor was opened. Used to restore
  /// on cancel.
  final Map<String, double> initialValues;

  /// The id of the timeline set this session is editing, or `null` when the
  /// session creates a new set. On done, an edit session replaces the set's
  /// adjustments in place (keeping its time window); a new session appends a
  /// fresh set.
  final String? editingSetId;

  /// The currently selected adjustment.
  TuneAdjustmentItem get selectedAdjustment => adjustments[selectedIndex];

  /// The value of the currently selected adjustment.
  double get selectedValue => valueOf(selectedAdjustment.id);

  /// Returns the current value for the adjustment with the given [id], or `0`
  /// when it has not been adjusted.
  double valueOf(String id) => values[id] ?? 0;

  VideoEditorTuneState copyWith({
    List<TuneAdjustmentItem>? adjustments,
    int? selectedIndex,
    Map<String, double>? values,
    Map<String, double>? initialValues,
    String? editingSetId,
    bool clearEditingSetId = false,
  }) {
    return VideoEditorTuneState(
      adjustments: adjustments ?? this.adjustments,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      values: values ?? this.values,
      initialValues: initialValues ?? this.initialValues,
      editingSetId: clearEditingSetId
          ? null
          : (editingSetId ?? this.editingSetId),
    );
  }

  @override
  List<Object?> get props => [
    adjustments,
    selectedIndex,
    values,
    initialValues,
    editingSetId,
  ];
}
