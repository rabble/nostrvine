// ABOUTME: Groups word-level transcription segments into caption cues.
// ABOUTME: Splits on silence gaps, character limits, and cue duration limits.

import 'package:caption_generator/src/models/caption_segment.dart';

/// Merges word-level [segments] into display-ready caption cues.
///
/// Words are joined with single spaces into one cue until adding the next
/// word would cross a limit, at which point a new cue starts:
///
/// * [maxCharactersPerCaption] — cue text length ceiling. A single word
///   longer than the ceiling still becomes its own cue.
/// * [maxCaptionDuration] — how long one cue may span on the timeline.
/// * [maxSilenceGap] — a pause between words longer than this starts a new
///   cue, so captions do not linger across silence.
///
/// Input order does not matter; segments are sorted by start time first.
///
/// Throws an [ArgumentError] when a limit is not positive.
List<CaptionSegment> groupCaptionSegments(
  List<CaptionSegment> segments, {
  int maxCharactersPerCaption = 42,
  Duration maxCaptionDuration = const Duration(seconds: 5),
  Duration maxSilenceGap = const Duration(milliseconds: 800),
}) {
  if (maxCharactersPerCaption < 1) {
    throw ArgumentError.value(
      maxCharactersPerCaption,
      'maxCharactersPerCaption',
      'must be positive',
    );
  }
  if (maxCaptionDuration <= Duration.zero) {
    throw ArgumentError.value(
      maxCaptionDuration,
      'maxCaptionDuration',
      'must be positive',
    );
  }
  if (maxSilenceGap <= Duration.zero) {
    throw ArgumentError.value(
      maxSilenceGap,
      'maxSilenceGap',
      'must be positive',
    );
  }
  if (segments.isEmpty) return const [];

  final sorted = [...segments]..sort((a, b) => a.start.compareTo(b.start));
  final cues = <CaptionSegment>[];
  final text = StringBuffer(sorted.first.text);
  var cueStart = sorted.first.start;
  var cueEnd = sorted.first.end;

  for (final segment in sorted.skip(1)) {
    final gap = segment.start - cueEnd;
    final mergedLength = text.length + 1 + segment.text.length;
    final mergedDuration = segment.end - cueStart;
    final startsNewCue =
        gap > maxSilenceGap ||
        mergedLength > maxCharactersPerCaption ||
        mergedDuration > maxCaptionDuration;
    if (startsNewCue) {
      cues.add(
        CaptionSegment(text: text.toString(), start: cueStart, end: cueEnd),
      );
      text
        ..clear()
        ..write(segment.text);
      cueStart = segment.start;
      cueEnd = segment.end;
    } else {
      text
        ..write(' ')
        ..write(segment.text);
      cueEnd = segment.end > cueEnd ? segment.end : cueEnd;
    }
  }
  cues.add(CaptionSegment(text: text.toString(), start: cueStart, end: cueEnd));
  return cues;
}
