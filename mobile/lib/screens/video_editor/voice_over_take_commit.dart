// ABOUTME: Helpers for committing recorded voice-over takes to the timeline:
// ABOUTME: probing real on-disk durations and reclaiming unplaced take files.

import 'dart:io';
import 'dart:math' as math;

import 'package:models/models.dart' show AudioEvent;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Probes the real on-disk duration (seconds) of a recorded voice-over [take].
///
/// The recorder's live duration is derived from amplitude-sample counts and can
/// drift from the encoded file, so the committed timeline window uses the probed
/// value. Falls back to the recorder's estimate when the path is missing, the
/// probe returns a non-positive duration, or the probe throws.
Future<double> resolveRecordedTakeDurationSecs(AudioEvent take) async {
  // Clamp to non-negative so the documented "falls back to the estimate"
  // contract can never propagate a negative duration onto the timeline.
  final estimate = math.max(0.0, take.duration ?? 0);
  final path = take.localFilePath;
  if (path == null || path.isEmpty) return estimate;
  try {
    final metadata = await ProVideoEditor.instance.getMetadata(
      EditorVideo.file(path),
    );
    final secs = metadata.duration.inMilliseconds / 1000.0;
    return secs > 0 ? secs : estimate;
  } catch (e, s) {
    Log.error(
      'Failed to probe voice-over take duration for ${take.id}',
      name: 'VideoEditorScreen',
      category: LogCategory.video,
      error: e,
      stackTrace: s,
    );
    return estimate;
  }
}

/// Deletes the local files backing [takes], ignoring any that are already gone.
///
/// Used to reclaim recorded takes that were committed via Done but then never
/// placed on the timeline (an early return after the recorder closes). Those
/// files belong to no draft, so without this they would orphan permanently in
/// the unswept `voice_over_recordings` folder.
Future<void> deleteVoiceOverTakeFiles(Iterable<AudioEvent>? takes) async {
  if (takes == null) return;
  for (final take in takes) {
    final path = take.localFilePath;
    if (path == null || path.isEmpty) continue;
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      await file.delete();
    } catch (e, s) {
      Log.error(
        'Failed to delete unplaced voice-over take file for ${take.id}',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
        error: e,
        stackTrace: s,
      );
    }
  }
}
