// ABOUTME: Derives a recorded clip's true length from its media tracks
// ABOUTME: so the editor timeline matches the file the export is built from

import 'package:pro_video_editor/pro_video_editor.dart';

/// How far a clip's audio may fall short of its video before the gap counts as
/// content rather than a track-end mismatch.
///
/// Capture stops the audio and video writers independently, so the two tracks
/// end a fraction of a second apart; a survey of published mp4s put the worst
/// case at ~0.4s. A larger gap means the clip is genuinely meant to outlast its
/// audio — a stop-motion still held past a short sound, or a source with a
/// broken audio track — and shortening it would swallow content.
const clipTrackEndTolerance = Duration(milliseconds: 500);

/// The point where every track of a recorded clip still has content, or `null`
/// when the clip's recorded length should be kept as it is.
///
/// An mp4's container duration is its *longest* track, so a clip whose audio
/// writer stopped first declares a length whose tail has picture but no sound.
/// Treating that declared length as the clip's length puts the editor timeline
/// out of step with the media: trims, layer anchors and transitions are all
/// authored against a tail that the export cannot fill.
///
/// Returns `null` when there is nothing to correct — no audio track, tracks
/// already ending together, or a shortfall beyond [clipTrackEndTolerance].
Duration? commonTrackEnd(VideoMetadata metadata) {
  final audioDuration = metadata.audioDuration;
  if (audioDuration == null) return null;
  if (audioDuration >= metadata.duration) return null;
  if (metadata.duration - audioDuration > clipTrackEndTolerance) return null;
  return audioDuration;
}
