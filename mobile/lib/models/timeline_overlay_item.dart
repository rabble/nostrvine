// ABOUTME: Data model for overlay items (layers, filters, sounds) on the
// ABOUTME: video editor timeline. Each item has a time position, duration,
// ABOUTME: row assignment, and trim state.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

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
    required this.endTime,
    this.row = 0,
    this.label = '',
    this.layer,
    this.maxDuration,
    this.waveformLeftChannel,
    this.waveformRightChannel,
  });

  /// Unique identifier.
  final String id;

  /// Determines which strip this item belongs to.
  final TimelineOverlayType type;

  /// Where the item starts on the timeline.
  final Duration startTime;

  /// Where the item ends on the timeline.
  final Duration endTime;

  /// Row index within the strip. For layers, lower row = higher z-index
  /// (rendered in front).
  final int row;

  /// Human-readable label (e.g. "Blur", "Beat Drop", "Hello World").
  final String label;

  /// The original layer data.
  final Layer? layer;

  /// Maximum allowed duration for this item.
  ///
  /// When set (e.g. for sound items), trimming cannot extend
  /// the item beyond this duration — the item moves instead.
  final Duration? maxDuration;

  /// Left audio waveform amplitude samples for sound items.
  final Float32List? waveformLeftChannel;

  /// Right audio waveform amplitude samples for sound items.
  final Float32List? waveformRightChannel;

  /// Start time in seconds for layout calculations.
  double get startTimeInSeconds => startTime.inMilliseconds / 1000.0;
  double get durationInSeconds => duration.inMilliseconds / 1000;

  Duration get duration => endTime - startTime;

  TimelineOverlayItem copyWith({
    String? id,
    TimelineOverlayType? type,
    Duration? startTime,
    Duration? endTime,
    int? row,
    String? label,
    Layer? layer,
    Duration? maxDuration,
    Float32List? waveformLeftChannel,
    Float32List? waveformRightChannel,
  }) {
    return TimelineOverlayItem(
      id: id ?? this.id,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      row: row ?? this.row,
      label: label ?? this.label,
      layer: layer ?? this.layer,
      maxDuration: maxDuration ?? this.maxDuration,
      waveformLeftChannel: waveformLeftChannel ?? this.waveformLeftChannel,
      waveformRightChannel: waveformRightChannel ?? this.waveformRightChannel,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    startTime,
    endTime,
    row,
    label,
    layer,
    maxDuration,
    waveformLeftChannel,
    waveformRightChannel,
  ];
}
