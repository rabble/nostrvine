// ABOUTME: Service for parsing WebVTT subtitle content into cue objects.
// ABOUTME: Handles VTT parsing and generation for the subtitle pipeline.

/// A single subtitle cue with timing and text.
class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  /// Start time in milliseconds.
  final int start;

  /// End time in milliseconds.
  final int end;

  /// The subtitle text content.
  final String text;
}

/// Service for parsing and generating WebVTT subtitle content.
class SubtitleService {
  /// Parse a WebVTT string into a list of [SubtitleCue]s.
  ///
  /// Tolerant parser: skips malformed cues rather than throwing.
  static List<SubtitleCue> parseVtt(String vttContent) {
    if (vttContent.trim().isEmpty) return [];

    final cues = <SubtitleCue>[];
    final lines = vttContent.split('\n');

    var i = 0;

    // Skip WEBVTT header and any metadata lines
    while (i < lines.length && !lines[i].contains('-->')) {
      i++;
    }

    while (i < lines.length) {
      final line = lines[i].trim();

      // Look for timing line (contains "-->")
      if (line.contains('-->')) {
        final timing = _parseTimingLine(line);
        if (timing != null) {
          // Collect text lines until blank line or end
          final textLines = <String>[];
          i++;
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            textLines.add(lines[i].trim());
            i++;
          }
          if (textLines.isNotEmpty) {
            cues.add(
              SubtitleCue(
                start: timing.$1,
                end: timing.$2,
                text: textLines.join('\n'),
              ),
            );
          }
        } else {
          i++;
        }
      } else {
        i++;
      }
    }

    return cues;
  }

  /// Generate a WebVTT string from a list of [SubtitleCue]s.
  static String generateVtt(List<SubtitleCue> cues) {
    final buffer = StringBuffer('WEBVTT\n\n');

    for (var i = 0; i < cues.length; i++) {
      final cue = cues[i];
      buffer.writeln('${i + 1}');
      buffer.writeln(
        '${_formatTimestamp(cue.start)} --> ${_formatTimestamp(cue.end)}',
      );
      buffer.writeln(cue.text);
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Parse a VTT timing line like "00:00:01.500 --> 00:00:03.200"
  /// Returns (startMs, endMs) or null if malformed.
  static (int, int)? _parseTimingLine(String line) {
    final parts = line.split('-->');
    if (parts.length != 2) return null;

    final start = _parseTimestamp(parts[0].trim());
    final end = _parseTimestamp(parts[1].trim());

    if (start == null || end == null) return null;
    return (start, end);
  }

  /// Parse a VTT timestamp like "00:00:01.500" into milliseconds.
  /// Supports both "HH:MM:SS.mmm" and "MM:SS.mmm" formats.
  static int? _parseTimestamp(String timestamp) {
    // Strip any position/alignment settings after the timestamp
    final clean = timestamp.split(' ').first;

    final parts = clean.split(':');
    if (parts.length < 2 || parts.length > 3) return null;

    try {
      int hours;
      int minutes;
      final secondsParts = parts.length == 3
          ? parts[2].split('.')
          : parts[1].split('.');

      if (parts.length == 3) {
        hours = int.parse(parts[0]);
        minutes = int.parse(parts[1]);
      } else {
        hours = 0;
        minutes = int.parse(parts[0]);
      }

      final seconds = int.parse(secondsParts[0]);
      final millis = secondsParts.length > 1 ? int.parse(secondsParts[1]) : 0;

      return (hours * 3600 + minutes * 60 + seconds) * 1000 + millis;
    } catch (_) {
      return null;
    }
  }

  /// Format milliseconds as a VTT timestamp "HH:MM:SS.mmm".
  static String _formatTimestamp(int ms) {
    final hours = ms ~/ 3600000;
    final minutes = (ms % 3600000) ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }
}
