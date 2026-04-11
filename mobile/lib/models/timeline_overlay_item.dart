// ABOUTME: Data model for overlay items (layers, filters, sounds) on the
// ABOUTME: video editor timeline. Each item has a time position, duration,
// ABOUTME: row assignment, and trim state.

import 'package:equatable/equatable.dart';

/// The type of overlay on the timeline.
enum TimelineOverlayType {
  /// Visual overlay: text, drawing, sticker, etc.
  layer,

  /// Filter effect applied to the video.
  filter,

  /// Audio track added on top of the original video audio.
  sound,
}

/// An overlay item positioned on the video editor timeline.
///
/// Items live in typed strips (layer / filter / sound) and can be
/// repositioned in time (horizontal) and in z-order (vertical row).
///
/// For layers, lower [row] values render in front (higher z-index).
class TimelineOverlayItem extends Equatable {
  const TimelineOverlayItem({
    required this.id,
    required this.type,
    required this.startTime,
    required this.duration,
    this.row = 0,
    this.label = '',
    this.trimStart = Duration.zero,
    this.trimEnd = Duration.zero,
  });

  /// Unique identifier.
  final String id;

  /// Determines which strip this item belongs to.
  final TimelineOverlayType type;

  /// Where the item starts on the timeline.
  final Duration startTime;

  /// Original full duration of the item.
  final Duration duration;

  /// Row index within the strip. For layers, lower row = higher z-index
  /// (rendered in front).
  final int row;

  /// Human-readable label (e.g. "Blur", "Beat Drop", "Hello World").
  final String label;

  /// How much has been trimmed from the start.
  final Duration trimStart;

  /// How much has been trimmed from the end.
  final Duration trimEnd;

  /// Effective duration after trimming (clamped to zero).
  Duration get trimmedDuration {
    final result = duration - trimStart - trimEnd;
    return result.isNegative ? Duration.zero : result;
  }

  /// Start time in seconds for layout calculations.
  double get startTimeInSeconds => startTime.inMilliseconds / 1000.0;

  /// Effective duration in seconds after trimming.
  double get trimmedDurationInSeconds =>
      trimmedDuration.inMilliseconds / 1000.0;

  /// End time after trimming.
  Duration get endTime => startTime + trimmedDuration;

  TimelineOverlayItem copyWith({
    String? id,
    TimelineOverlayType? type,
    Duration? startTime,
    Duration? duration,
    int? row,
    String? label,
    Duration? trimStart,
    Duration? trimEnd,
  }) {
    return TimelineOverlayItem(
      id: id ?? this.id,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      row: row ?? this.row,
      label: label ?? this.label,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    startTime,
    duration,
    row,
    label,
    trimStart,
    trimEnd,
  ];
}
