part of 'timeline_overlay_bloc.dart';

/// Base class for all timeline overlay events.
sealed class TimelineOverlayEvent extends Equatable {
  const TimelineOverlayEvent();

  @override
  List<Object?> get props => [];
}

/// Add a new overlay item to the timeline.
class TimelineOverlayItemAdded extends TimelineOverlayEvent {
  const TimelineOverlayItemAdded(this.item);

  final TimelineOverlayItem item;

  @override
  List<Object?> get props => [item];
}

/// Remove an overlay item by id.
class TimelineOverlayItemRemoved extends TimelineOverlayEvent {
  const TimelineOverlayItemRemoved(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// Move an overlay item to a new start time and/or row.
class TimelineOverlayItemMoved extends TimelineOverlayEvent {
  const TimelineOverlayItemMoved({
    required this.itemId,
    this.startTime,
    this.row,
  });

  final String itemId;
  final Duration? startTime;
  final int? row;

  @override
  List<Object?> get props => [itemId, startTime, row];
}

/// Update the trim of an overlay item.
class TimelineOverlayItemTrimmed extends TimelineOverlayEvent {
  const TimelineOverlayItemTrimmed({
    required this.itemId,
    required this.trimStart,
    required this.trimEnd,
    required this.isStart,
  });

  final String itemId;
  final Duration trimStart;
  final Duration trimEnd;
  final bool isStart;

  @override
  List<Object?> get props => [itemId, trimStart, trimEnd, isStart];
}

/// Select an overlay item (shows trim handles).
class TimelineOverlayItemSelected extends TimelineOverlayEvent {
  const TimelineOverlayItemSelected(this.itemId);

  final String? itemId;

  @override
  List<Object?> get props => [itemId];
}

/// Signal that a drag gesture started for an item.
class TimelineOverlayDragStarted extends TimelineOverlayEvent {
  const TimelineOverlayDragStarted(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// Signal that the current drag gesture ended.
class TimelineOverlayDragEnded extends TimelineOverlayEvent {
  const TimelineOverlayDragEnded();
}

/// Toggle collapse / expand for a strip type.
class TimelineOverlayCollapseToggled extends TimelineOverlayEvent {
  const TimelineOverlayCollapseToggled(this.type);

  final TimelineOverlayType type;

  @override
  List<Object?> get props => [type];
}
