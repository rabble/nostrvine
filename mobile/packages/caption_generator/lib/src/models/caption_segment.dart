// ABOUTME: Immutable transcribed speech segment with start/end timestamps.
// ABOUTME: Wire model decoded from the native transcription result maps.

import 'package:equatable/equatable.dart';

/// A piece of transcribed speech positioned on the audio timeline.
///
/// The native recognizers return one segment per recognized word; use
/// `groupCaptionSegments` to merge words into display-ready caption cues.
class CaptionSegment extends Equatable {
  /// Creates a segment covering [start] to [end] with the given [text].
  const CaptionSegment({
    required this.text,
    required this.start,
    required this.end,
  });

  /// Decodes a segment from a platform channel map.
  ///
  /// Throws a [FormatException] when required keys are missing or have an
  /// unexpected type.
  factory CaptionSegment.fromMap(Map<Object?, Object?> map) {
    final text = map['text'];
    final startMs = map['startMs'];
    final endMs = map['endMs'];
    if (text is! String || startMs is! int || endMs is! int) {
      throw FormatException('Malformed caption segment map: $map');
    }
    return CaptionSegment(
      text: text,
      start: Duration(milliseconds: startMs),
      end: Duration(milliseconds: endMs),
    );
  }

  /// The transcribed text of this segment.
  final String text;

  /// Where this segment starts on the audio timeline.
  final Duration start;

  /// Where this segment ends on the audio timeline.
  final Duration end;

  /// How long this segment lasts.
  Duration get duration => end - start;

  /// Encodes this segment as a platform channel compatible map.
  Map<String, Object?> toMap() => <String, Object?>{
    'text': text,
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
  };

  @override
  List<Object?> get props => [text, start, end];

  @override
  String toString() =>
      'CaptionSegment("$text", '
      '${start.inMilliseconds}ms-${end.inMilliseconds}ms)';
}
