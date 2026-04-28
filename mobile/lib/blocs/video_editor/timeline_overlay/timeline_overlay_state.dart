part of 'timeline_overlay_bloc.dart';

/// State for the timeline overlay editor.
class TimelineOverlayState extends Equatable {
  const TimelineOverlayState({
    this.items = const [],
    this.audioTracks = const [],
    this.selectedItemId,
    this.draggingItemId,
    this.dragPosition,
    this.trimmingItemId,
    this.trimPosition,
    this.collapsedTypes = const {},
  });

  /// All overlay items across all strip types.
  final List<TimelineOverlayItem> items;

  /// Source audio events for the current sound items.
  ///
  /// Stored so the presentation layer can build native [AudioTrack]s
  /// with the correct URL / asset path without reaching into Riverpod.
  final List<AudioEvent> audioTracks;

  /// The currently selected item (shows trim handles), or `null`.
  final String? selectedItemId;

  /// The item being dragged, or `null`.
  final String? draggingItemId;

  /// The live startTime of the item currently being dragged.
  ///
  /// Set to the dragged item's `startTime` while a move gesture is
  /// active; `null` when no drag is in progress.
  final Duration? dragPosition;

  /// The item being trimmed, or `null`.
  final String? trimmingItemId;

  /// The live position of the trim handle currently being dragged.
  ///
  /// Set to the dragged [startTime] or [endTime] while a trim gesture is
  /// active; `null` when no trim is in progress.
  final Duration? trimPosition;

  /// Strip types that are in collapsed view.
  final Set<TimelineOverlayType> collapsedTypes;

  TimelineOverlayState copyWith({
    List<TimelineOverlayItem>? items,
    List<AudioEvent>? audioTracks,
    String? selectedItemId,
    bool clearSelectedItemId = false,
    String? draggingItemId,
    bool clearDraggingItemId = false,
    Duration? dragPosition,
    bool clearDragPosition = false,
    String? trimmingItemId,
    bool clearTrimmingItemId = false,
    Duration? trimPosition,
    bool clearTrimPosition = false,
    Set<TimelineOverlayType>? collapsedTypes,
  }) {
    return TimelineOverlayState(
      items: items ?? this.items,
      audioTracks: audioTracks ?? this.audioTracks,
      selectedItemId: clearSelectedItemId
          ? null
          : (selectedItemId ?? this.selectedItemId),
      draggingItemId: clearDraggingItemId
          ? null
          : (draggingItemId ?? this.draggingItemId),
      dragPosition: clearDragPosition
          ? null
          : (dragPosition ?? this.dragPosition),
      trimmingItemId: clearTrimmingItemId
          ? null
          : (trimmingItemId ?? this.trimmingItemId),
      trimPosition: clearTrimPosition
          ? null
          : (trimPosition ?? this.trimPosition),
      collapsedTypes: collapsedTypes ?? this.collapsedTypes,
    );
  }

  @override
  List<Object?> get props => [
    items,
    audioTracks,
    selectedItemId,
    draggingItemId,
    dragPosition,
    trimmingItemId,
    trimPosition,
    collapsedTypes,
  ];
}
