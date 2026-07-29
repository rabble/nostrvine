// ABOUTME: Result types of one on-device caption generation run.
// ABOUTME: Consumed by the captions editor state and its failure UI copy.

import 'package:openvine/models/video_editor/caption_track.dart';

/// Why caption generation could not produce cues.
enum CaptionGenerationFailure {
  /// No on-device recognizer for this device or language (Android < 14,
  /// de-Googled devices, missing language packs, unsupported locales).
  recognizerUnavailable,

  /// The user denied speech recognition (Apple platforms).
  notAuthorized,

  /// The extracted audio could not be read by the recognizer.
  unsupportedAudio,

  /// Any other extraction or transcription error.
  failed,
}

/// The result of one caption generation run.
sealed class CaptionGenerationOutcome {
  const CaptionGenerationOutcome();
}

/// Speech was recognized; [cues] are display-ready and timeline-mapped.
final class CaptionsGenerated extends CaptionGenerationOutcome {
  /// Creates the outcome with the generated [cues].
  const CaptionsGenerated(this.cues);

  /// The generated cues, ordered by start time.
  final List<CaptionCue> cues;
}

/// The clips contain no transcribable speech (no audio, muted, or silence).
final class CaptionsEmpty extends CaptionGenerationOutcome {
  /// Creates the outcome.
  const CaptionsEmpty();
}

/// Generation failed; [reason] tells the UI which message to show.
final class CaptionsFailed extends CaptionGenerationOutcome {
  /// Creates the outcome with the failure [reason].
  const CaptionsFailed(this.reason);

  /// Why generation failed.
  final CaptionGenerationFailure reason;
}
