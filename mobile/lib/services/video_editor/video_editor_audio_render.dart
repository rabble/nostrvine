// ABOUTME: Maps editor audio events to render audio tracks and resolves them
// ABOUTME: to local files for muxing, keeping render audio logic in one place

import 'dart:io';

import 'package:models/models.dart' show AudioEvent;
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Builds the render [AudioTrack] for the currently selected sound.
AudioTrack audioTrackFromSoundForRender(AudioEvent sound) {
  return AudioTrack(
    id: sound.id,
    title: sound.title ?? '',
    subtitle: sound.source ?? '',
    duration: Duration(seconds: sound.duration?.toInt() ?? 0),
    audio: sound.isBundled
        ? EditorAudio.asset(sound.assetPath!)
        : sound.isLocalImport && sound.localFilePath != null
        ? EditorAudio.file(File(sound.localFilePath!))
        : EditorAudio.network(sound.url!),
    startTime: sound.startOffset,
  );
}

/// Builds the render [AudioTrack] for a timeline audio [track] taken from the
/// editor meta.
///
/// Returns `null` (and logs a warning) when the track has no resolvable audio
/// source, so a single unusable track is skipped instead of aborting the whole
/// render with a thrown null-check. Routes bundled → asset, local-import or
/// absolute path → file, and everything else (http(s)) → network.
AudioTrack? audioTrackFromMetaForRender(AudioEvent track) {
  final EditorAudio audio;
  if (track.isBundled && track.assetPath != null) {
    audio = EditorAudio.asset(track.assetPath!);
  } else if (track.isLocalImport && track.localFilePath != null) {
    audio = EditorAudio.file(File(track.localFilePath!));
  } else if (track.url != null && track.url!.isNotEmpty) {
    audio = track.url!.startsWith('/')
        ? EditorAudio.file(File(track.url!))
        : EditorAudio.network(track.url!);
  } else {
    Log.warning(
      'Skipping audio track ${track.id} for render: no resolvable source',
      name: 'VideoEditorAudioRender',
      category: LogCategory.video,
    );
    return null;
  }

  final sourceDuration = Duration(
    milliseconds: ((track.duration ?? 0) * 1000).toInt(),
  );
  return AudioTrack(
    id: track.id,
    title: track.title ?? '',
    subtitle: track.source ?? '',
    duration: sourceDuration,
    audio: audio,
    startTime: track.startTime,
    endTime: track.endTime,
    audioStartTime: track.startOffset,
    // End of the *source* audio — not startOffset + full length, which runs
    // the requested range past the file end whenever startOffset > 0.
    audioEndTime: sourceDuration,
    volume: track.volume,
  );
}

/// Resolves each render [AudioTrack] to a [VideoAudioTrack] with a local file
/// path, downloading network sources on demand.
///
/// A track that cannot be resolved (e.g. a failed network download) is skipped
/// and logged rather than aborting the whole render. A warning is logged when
/// audio was requested but none could be resolved, so a silent (audio-less)
/// export is diagnosable from logs.
Future<List<VideoAudioTrack>> resolveRenderAudioTracks(
  List<AudioTrack> customTracks, {
  required String logName,
}) async {
  final audioTracks = <VideoAudioTrack>[];
  for (final track in customTracks) {
    try {
      final audioPath = await track.audio.safeFilePath();
      audioTracks.add(
        VideoAudioTrack(
          path: audioPath,
          startTime: track.startTime,
          endTime: track.endTime,
          audioStartTime: track.audioStartTime,
          audioEndTime: track.audioEndTime,
          loop: track.loop,
          volume: track.volume,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        'Failed to resolve audio track ${track.id} for render — skipping it',
        name: logName,
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  if (customTracks.isNotEmpty && audioTracks.isEmpty) {
    Log.warning(
      'Render produced no usable audio from ${customTracks.length} '
      'requested track(s); custom audio will be missing from the output',
      name: logName,
      category: LogCategory.video,
    );
  }

  return audioTracks;
}
