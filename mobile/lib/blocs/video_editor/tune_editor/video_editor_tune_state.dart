part of 'video_editor_tune_bloc.dart';

/// State for the video editor tune adjustments.
class VideoEditorTuneState extends Equatable {
  const VideoEditorTuneState({
    required this.adjustments,
    this.selectedIndex = 0,
    this.values = const {},
    this.initialValues = const {},
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

  /// The currently selected adjustment.
  TuneAdjustmentItem get selectedAdjustment => adjustments[selectedIndex];

  /// The value of the currently selected adjustment.
  double get selectedValue => valueOf(selectedAdjustment.id);

  /// Returns the current value for the adjustment with the given [id], or `0`
  /// when it has not been adjusted.
  double valueOf(String id) => values[id] ?? 0;

  /// Whether any adjustment differs from its neutral value.
  bool get hasAdjustments => values.values.any((value) => value != 0);

  VideoEditorTuneState copyWith({
    List<TuneAdjustmentItem>? adjustments,
    int? selectedIndex,
    Map<String, double>? values,
    Map<String, double>? initialValues,
  }) {
    return VideoEditorTuneState(
      adjustments: adjustments ?? this.adjustments,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      values: values ?? this.values,
      initialValues: initialValues ?? this.initialValues,
    );
  }

  @override
  List<Object?> get props => [
    adjustments,
    selectedIndex,
    values,
    initialValues,
  ];
}
