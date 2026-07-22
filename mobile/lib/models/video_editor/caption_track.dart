// ABOUTME: Caption track model for the video editor (burn-in or CC overlay).
// ABOUTME: Cues are timed text; the track carries mode, preset, and language.

import 'package:caption_generator/caption_generator.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/services/subtitle_service.dart';

/// How the caption track is rendered into the published video.
enum CaptionRenderMode {
  /// Cues are rasterized into the exported video as animated text layers.
  burnIn,

  /// Cues ride alongside the video as a WebVTT closed-caption track
  /// (Blossom VTT + kind 39307 + `text-track` tags) and render at playback.
  overlay;

  /// Parses the serialized [name], defaulting to [overlay] for unknown input
  /// so a future mode never crashes an old draft.
  static CaptionRenderMode fromName(String? name) => switch (name) {
    'burnIn' => burnIn,
    _ => overlay,
  };
}

/// A single caption cue: one piece of timed text on the video timeline.
class CaptionCue extends Equatable {
  /// Creates a cue with a stable [id] covering [start] to [end].
  const CaptionCue({
    required this.id,
    required this.text,
    required this.start,
    required this.end,
  });

  /// Decodes a cue from its [toJson] map.
  ///
  /// Throws a [FormatException] when required keys are missing or mistyped.
  factory CaptionCue.fromJson(Map<Object?, Object?> json) {
    final id = json['id'];
    final text = json['text'];
    final startMs = json['startMs'];
    final endMs = json['endMs'];
    if (id is! String || text is! String || startMs is! int || endMs is! int) {
      throw FormatException('Malformed caption cue: $json');
    }
    return CaptionCue(
      id: id,
      text: text,
      start: Duration(milliseconds: startMs),
      end: Duration(milliseconds: endMs),
    );
  }

  /// Creates a cue from a recognizer [segment] with the given [id].
  factory CaptionCue.fromSegment(CaptionSegment segment, {required String id}) {
    return CaptionCue(
      id: id,
      text: segment.text,
      start: segment.start,
      end: segment.end,
    );
  }

  /// Stable identifier, used to address the cue from timeline items.
  final String id;

  /// The caption text shown while the cue is active.
  final String text;

  /// Where the cue starts on the video timeline.
  final Duration start;

  /// Where the cue ends on the video timeline.
  final Duration end;

  /// How long the cue is visible.
  Duration get duration => end - start;

  /// This cue as a [SubtitleCue] for the VTT pipeline.
  SubtitleCue toSubtitleCue() => SubtitleCue(
    start: start.inMilliseconds,
    end: end.inMilliseconds,
    text: text,
  );

  /// Encodes this cue for draft/history storage.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'text': text,
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
  };

  /// Copy with the given fields replaced.
  CaptionCue copyWith({
    String? text,
    Duration? start,
    Duration? end,
  }) => CaptionCue(
    id: id,
    text: text ?? this.text,
    start: start ?? this.start,
    end: end ?? this.end,
  );

  @override
  List<Object?> get props => [id, text, start, end];
}

/// The video's caption track as stored in editor history meta.
///
/// In [CaptionRenderMode.overlay] the [cues] list is the source of truth. In
/// [CaptionRenderMode.burnIn] the cues live as marked editor layers instead
/// and [cues] stays empty — the track then only remembers [mode], [presetId],
/// and [languageTag] so re-opening the captions flow restores the session.
class CaptionTrack extends Equatable {
  /// Creates a caption track.
  const CaptionTrack({
    required this.mode,
    required this.presetId,
    required this.languageTag,
    this.cues = const [],
  });

  /// Decodes a track from its [toJson] map.
  ///
  /// Throws a [FormatException] when the map is malformed.
  factory CaptionTrack.fromJson(Map<Object?, Object?> json) {
    final presetId = json['presetId'];
    final languageTag = json['languageTag'];
    final rawCues = json['cues'];
    if (presetId is! String || languageTag is! String || rawCues is! List) {
      throw FormatException('Malformed caption track: $json');
    }
    return CaptionTrack(
      mode: CaptionRenderMode.fromName(json['mode'] as String?),
      presetId: presetId,
      languageTag: languageTag,
      cues: [
        for (final cue in rawCues)
          CaptionCue.fromJson(cue! as Map<Object?, Object?>),
      ],
    );
  }

  /// Whether cues are burned into the video or attached as a CC track.
  final CaptionRenderMode mode;

  /// The track-wide style/animation preset id (see `CaptionStylePreset`).
  final String presetId;

  /// BCP-47 tag of the caption language (e.g. `en-US`).
  final String languageTag;

  /// The cues, ordered by start time. Empty in burn-in mode.
  final List<CaptionCue> cues;

  /// Encodes this track for draft/history storage.
  Map<String, Object?> toJson() => <String, Object?>{
    'mode': mode.name,
    'presetId': presetId,
    'languageTag': languageTag,
    'cues': [for (final cue in cues) cue.toJson()],
  };

  /// Copy with the given fields replaced.
  CaptionTrack copyWith({
    CaptionRenderMode? mode,
    String? presetId,
    String? languageTag,
    List<CaptionCue>? cues,
  }) => CaptionTrack(
    mode: mode ?? this.mode,
    presetId: presetId ?? this.presetId,
    languageTag: languageTag ?? this.languageTag,
    cues: cues ?? this.cues,
  );

  @override
  List<Object?> get props => [mode, presetId, languageTag, cues];
}
