part of 'timeline_overlay_bloc.dart';

/// Base class for all timeline overlay events.
sealed class TimelineOverlayEvent extends Equatable {
  const TimelineOverlayEvent();

  @override
  List<Object?> get props => [];
}

/// Updates all item to the timeline.
class TimelineOverlayItemsUpdate extends TimelineOverlayEvent {
  const TimelineOverlayItemsUpdate({
    required this.layers,
    required this.filters,
    required this.audioTracks,
    required this.totalVideoDuration,
  });

  final List<Layer> layers;
  final List<FilterState> filters;
  final List<AudioEvent> audioTracks;

  final Duration totalVideoDuration;

  @override
  List<Object?> get props => [layers, filters, audioTracks, totalVideoDuration];
}

/// Move an overlay item to a new start time and/or row.
///
/// When [insertAbove] is `true` and the target row has an overlap,
/// the moved item keeps the target row and existing items shift down.
/// When `false` (default), the moved item shifts to the row below.
class TimelineOverlayItemMoved extends TimelineOverlayEvent {
  const TimelineOverlayItemMoved({
    required this.itemId,
    this.startTime,
    this.row,
    this.insertAbove = false,
  });

  final String itemId;
  final Duration? startTime;
  final int? row;
  final bool insertAbove;

  @override
  List<Object?> get props => [itemId, startTime, row, insertAbove];
}

/// Update the trim of an overlay item.
///
/// When [startTime] or [duration] are provided, the item is being
/// extended beyond its original boundary (overlays have no fixed
/// content length).
class TimelineOverlayItemTrimmed extends TimelineOverlayEvent {
  const TimelineOverlayItemTrimmed({
    required this.itemId,
    required this.isStart,
    this.startTime,
    this.endTime,
  });

  final String itemId;
  final bool isStart;
  final Duration? startTime;
  final Duration? endTime;

  @override
  List<Object?> get props => [itemId, isStart, startTime, endTime];
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

/// Signal that a trim gesture started for an item.
class TimelineOverlayTrimStarted extends TimelineOverlayEvent {
  const TimelineOverlayTrimStarted(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// Signal that the current trim gesture ended.
class TimelineOverlayTrimEnded extends TimelineOverlayEvent {
  const TimelineOverlayTrimEnded();
}

/// Toggle collapse / expand for a strip type.
class TimelineOverlayCollapseToggled extends TimelineOverlayEvent {
  const TimelineOverlayCollapseToggled(this.type);

  final TimelineOverlayType type;

  @override
  List<Object?> get props => [type];
}

/// Clamp all overlay items so they fit within [totalDuration].
///
/// Dispatched when clip trimming or removal shortens the total
/// video duration.
class TimelineOverlayTotalDurationChanged extends TimelineOverlayEvent {
  const TimelineOverlayTotalDurationChanged(this.totalDuration);

  final Duration totalDuration;

  @override
  List<Object?> get props => [totalDuration];
}

/// Attach extracted waveform samples to a sound item.
class TimelineOverlayWaveformLoaded extends TimelineOverlayEvent {
  const TimelineOverlayWaveformLoaded({
    required this.itemId,
    required this.leftChannel,
    this.rightChannel,
  });

  final String itemId;
  final Float32List leftChannel;
  final Float32List? rightChannel;

  @override
  List<Object?> get props => [itemId, leftChannel, rightChannel];
}
