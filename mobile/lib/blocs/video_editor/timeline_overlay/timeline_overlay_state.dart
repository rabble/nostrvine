part of 'timeline_overlay_bloc.dart';

/// State for the timeline overlay editor.
class TimelineOverlayState extends Equatable {
  const TimelineOverlayState({
    this.items = const [],
    this.selectedItemId,
    this.draggingItemId,
    this.collapsedTypes = const {},
  });

  /// All overlay items across all strip types.
  final List<TimelineOverlayItem> items;

  /// The currently selected item (shows trim handles), or `null`.
  final String? selectedItemId;

  /// The item being dragged, or `null`.
  final String? draggingItemId;

  /// Strip types that are in collapsed view.
  final Set<TimelineOverlayType> collapsedTypes;

  /// Whether any item of [type] exists.
  bool hasItemsOfType(TimelineOverlayType type) =>
      items.any((i) => i.type == type);

  /// Items filtered by type, sorted by row then start time.
  List<TimelineOverlayItem> itemsOfType(TimelineOverlayType type) {
    final filtered = items.where((i) => i.type == type).toList()
      ..sort((a, b) {
        final rowCmp = a.row.compareTo(b.row);
        if (rowCmp != 0) return rowCmp;
        return a.startTime.compareTo(b.startTime);
      });
    return filtered;
  }

  /// Number of rows used by items of [type].
  int rowCountForType(TimelineOverlayType type) {
    final typeItems = itemsOfType(type);
    if (typeItems.isEmpty) return 0;
    return typeItems.map((i) => i.row).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Whether [type] is collapsed.
  bool isTypeCollapsed(TimelineOverlayType type) =>
      collapsedTypes.contains(type);

  TimelineOverlayState copyWith({
    List<TimelineOverlayItem>? items,
    String? selectedItemId,
    bool clearSelectedItemId = false,
    String? draggingItemId,
    bool clearDraggingItemId = false,
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
      collapsedTypes: collapsedTypes ?? this.collapsedTypes,
    );
  }

  @override
  List<Object?> get props => [
    items,
    selectedItemId,
    draggingItemId,
    collapsedTypes,
  ];
}
