// ABOUTME: Caption track model for the video editor.
// ABOUTME: Cues are timed text; the track carries burn-in, preset, language.

import 'package:caption_generator/caption_generator.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/services/subtitle_service.dart';

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
/// [cues] is always the source of truth: captions are always published as a
/// WebVTT closed-caption track (Blossom VTT + kind 39307 + `text-track`
/// tags). [burnIn] is an additional choice — when `true` the cues are *also*
/// rasterized into the exported video, styled either by the built-in
/// [presetId] or, when set, the user-defined [customStyle].
class CaptionTrack extends Equatable {
  /// Creates a caption track.
  const CaptionTrack({
    required this.presetId,
    required this.languageTag,
    this.burnIn = false,
    this.customStyle,
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
    final rawBurnIn = json['burnIn'];
    return CaptionTrack(
      // Legacy drafts stored a `mode` string instead of a `burnIn` bool.
      burnIn: rawBurnIn is bool ? rawBurnIn : json['mode'] == 'burnIn',
      presetId: presetId,
      languageTag: languageTag,
      customStyle: CaptionCustomStyle.fromJson(json['customStyle']),
      cues: [
        for (final cue in rawCues)
          CaptionCue.fromJson(cue! as Map<Object?, Object?>),
      ],
    );
  }

  /// Whether the cues are additionally burned into the exported video.
  final bool burnIn;

  /// The built-in style/animation preset id (see `CaptionStylePreset`). Used
  /// for the burned-in look when [customStyle] is `null`.
  final String presetId;

  /// The user-defined style, taking precedence over [presetId] when set.
  final CaptionCustomStyle? customStyle;

  /// BCP-47 tag of the caption language (e.g. `en-US`).
  final String languageTag;

  /// The cues, ordered by start time.
  final List<CaptionCue> cues;

  /// Encodes this track for draft/history storage.
  Map<String, Object?> toJson() => <String, Object?>{
    'burnIn': burnIn,
    'presetId': presetId,
    'languageTag': languageTag,
    if (customStyle != null) 'customStyle': customStyle!.toJson(),
    'cues': [for (final cue in cues) cue.toJson()],
  };

  /// Copy with the given fields replaced. Pass [clearCustomStyle] to drop a
  /// custom style (selecting a built-in preset again).
  CaptionTrack copyWith({
    bool? burnIn,
    String? presetId,
    String? languageTag,
    CaptionCustomStyle? customStyle,
    bool clearCustomStyle = false,
    List<CaptionCue>? cues,
  }) => CaptionTrack(
    burnIn: burnIn ?? this.burnIn,
    presetId: presetId ?? this.presetId,
    languageTag: languageTag ?? this.languageTag,
    customStyle: clearCustomStyle ? null : (customStyle ?? this.customStyle),
    cues: cues ?? this.cues,
  );

  @override
  List<Object?> get props => [
    burnIn,
    presetId,
    customStyle,
    languageTag,
    cues,
  ];
}
