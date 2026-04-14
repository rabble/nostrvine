part of 'timeline_overlay_bloc.dart';

/// State for the timeline overlay editor.
class TimelineOverlayState extends Equatable {
  const TimelineOverlayState({
    this.items = const [],
    this.selectedItemId,
    this.draggingItemId,
    this.trimmingItemId,
    this.collapsedTypes = const {},
  });

  /// All overlay items across all strip types.
  final List<TimelineOverlayItem> items;

  /// The currently selected item (shows trim handles), or `null`.
  final String? selectedItemId;

  /// The item being dragged, or `null`.
  final String? draggingItemId;

  /// The item being trimmed, or `null`.
  final String? trimmingItemId;

  /// Strip types that are in collapsed view.
  final Set<TimelineOverlayType> collapsedTypes;

  TimelineOverlayState copyWith({
    List<TimelineOverlayItem>? items,
    String? selectedItemId,
    bool clearSelectedItemId = false,
    String? draggingItemId,
    bool clearDraggingItemId = false,
    String? trimmingItemId,
    bool clearTrimmingItemId = false,
    Set<TimelineOverlayType>? collapsedTypes,
  }) {
    return TimelineOverlayState(
      items: items ?? this.items,
      selectedItemId: clearSelectedItemId
          ? null
          : (selectedItemId ?? this.selectedItemId),
      draggingItemId: clearDraggingItemId
          ? null
          : (draggingItemId ?? this.draggingItemId),
      trimmingItemId: clearTrimmingItemId
          ? null
          : (trimmingItemId ?? this.trimmingItemId),
      collapsedTypes: collapsedTypes ?? this.collapsedTypes,
    );
  }

  @override
  List<Object?> get props => [
    items,
    selectedItemId,
    draggingItemId,
    trimmingItemId,
    collapsedTypes,
  ];
}
