// ABOUTME: Strips leaked AI prompt instructions from transcript/caption text.
// ABOUTME: Defense-in-depth for upstream transcription pipelines that
// ABOUTME: occasionally concatenate prompt scaffolding into cue text.

/// Sanitizes transcript text against leaked LLM prompt instructions.
///
/// The upstream transcription pipeline can concatenate prompt scaffolding
/// (instructions about producing JSON output, schema directives, etc.) into
/// the actual transcribed cue text — see issue #3737, where a vine
/// transcript ended with
///
///   "... a single JSON array. Do not include any extra text outside of the
///   JSON string. When producing JSON you must follow the schema provided
///   in the context."
///
/// This is a server-side defect, but until upstream fixes propagate, the
/// client must not surface those phrases as captions.
class TranscriptSanitizer {
  /// Phrases that signal AI prompt instructions leaking into a caption.
  ///
  /// Each entry is matched case-insensitively as a substring. Phrases were
  /// chosen to be highly specific to LLM-output directives — they are
  /// extremely unlikely to appear in conversational speech that captions
  /// typically transcribe.
  static const List<String> _promptMarkers = [
    'a single json array',
    'a single json object',
    'do not include any extra text',
    'outside of the json',
    'follow the schema provided',
    'schema provided in the context',
    'when producing json',
    'when producing the json',
    'you must follow the schema',
    'as a json array',
    'as a json object',
    'respond with a json',
    'respond only with json',
    'output only json',
    'output a json',
    'return a json',
    'return only json',
  ];

  /// Returns [text] with any trailing leaked prompt directive removed, or
  /// `null` if the entire string is prompt content with nothing real to keep.
  ///
  /// Truncation point is the last sentence terminator (`.`, `!`, `?`) before
  /// the earliest matched marker. If no terminator precedes the marker, the
  /// whole string is dropped.
  static String? sanitize(String text) {
    if (text.isEmpty) return text;

    final lower = text.toLowerCase();
    var earliestMarkerIndex = -1;

    for (final marker in _promptMarkers) {
      final idx = lower.indexOf(marker);
      if (idx >= 0 &&
          (earliestMarkerIndex == -1 || idx < earliestMarkerIndex)) {
        earliestMarkerIndex = idx;
      }
    }

    if (earliestMarkerIndex == -1) {
      return text;
    }

    final beforeMarker = text.substring(0, earliestMarkerIndex);
    final lastSentenceEnd = _lastSentenceTerminator(beforeMarker);

    if (lastSentenceEnd == -1) {
      return null;
    }

    final truncated = text.substring(0, lastSentenceEnd + 1).trim();
    return truncated.isEmpty ? null : truncated;
  }

  static int _lastSentenceTerminator(String text) {
    for (var i = text.length - 1; i >= 0; i--) {
      final c = text[i];
      if (c == '.' || c == '!' || c == '?') return i;
    }
    return -1;
  }
}
