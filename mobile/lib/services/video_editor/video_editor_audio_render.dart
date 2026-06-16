// ABOUTME: Maps editor audio events to render audio tracks and resolves them
// ABOUTME: to local files for muxing, keeping render audio logic in one place

import 'dart:io';

import 'package:models/models.dart' show AudioEvent;
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'VideoEditorAudioRender';

/// Resolves the [EditorAudio] source for a render [event], or `null` when it
/// has no usable source.
///
/// Routes bundled → asset, local-import or absolute path → file, and http(s)
/// → network. Guards every nullable field so a malformed event is skipped by
/// the caller instead of throwing a null-check during render.
EditorAudio? _resolveRenderAudioSource(AudioEvent event) {
  if (event.isBundled && event.assetPath != null) {
    return EditorAudio.asset(event.assetPath!);
  }
  if (event.isLocalImport && event.localFilePath != null) {
    return EditorAudio.file(File(event.localFilePath!));
  }
  final url = event.url;
  if (url != null && url.isNotEmpty) {
    return url.startsWith('/')
        ? EditorAudio.file(File(url))
        : EditorAudio.network(url);
  }
  return null;
}

/// Builds the render [AudioTrack] for the legacy single selected sound.
///
/// The selected sound carries no timeline placement, so it is normalized to
/// start at the beginning of the video and span its source length before
/// mapping. Setting `startTime`/`endTime` is essential: a bare sound's
/// `startTime` defaults to its source `startOffset` and its `endTime` is
/// `null`, which the native renderer reads as a zero-length `[offset, 0]`
/// composition window and drops with "no time remaining in composition".
///
/// Returns `null` (and logs a warning) when the sound has no resolvable source
/// or no known duration.
AudioTrack? audioTrackFromSoundForRender(AudioEvent sound) {
  final durationMs = ((sound.duration ?? 0) * 1000).toInt();
  if (durationMs <= 0) {
    Log.warning(
      'Skipping selected sound ${sound.id} for render: unknown duration',
      name: _logName,
      category: LogCategory.video,
    );
    return null;
  }
  return audioTrackFromMetaForRender(
    sound.copyWith(
      startTime: Duration.zero,
      endTime: Duration(milliseconds: durationMs),
    ),
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
  final audio = _resolveRenderAudioSource(track);
  if (audio == null) {
    Log.warning(
      'Skipping audio track ${track.id} for render: no resolvable source',
      name: _logName,
      category: LogCategory.video,
    );
    return null;
  }

  // A persisted track can carry an invalid composition window — e.g. a sound
  // added before its duration was known ends up with endTime=0 (see
  // _openMusicLibrary). Treat any missing/inverted window as "play across the
  // whole video" (both null per VideoAudioTrack's contract) so existing drafts
  // still render audio instead of being dropped as a zero-length range.
  final endTime = track.endTime;
  final hasWindow = endTime != null && endTime > track.startTime;
  return AudioTrack(
    id: track.id,
    title: track.title ?? '',
    subtitle: track.source ?? '',
    duration: Duration(milliseconds: ((track.duration ?? 0) * 1000).toInt()),
    audio: audio,
    startTime: hasWindow ? track.startTime : null,
    endTime: hasWindow ? endTime : null,
    audioStartTime: track.startOffset,
    // audioEndTime is intentionally left at its default (null = "play to the
    // end of the file"); the composition window clips it. This drops the
    // dependency on a possibly-missing source duration, which previously
    // produced an invalid `[startOffset, 0]` source range.
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
