// ABOUTME: Generates caption cues for the editor timeline from clip audio.
// ABOUTME: Extracts per-clip WAVs, transcribes on-device, and maps timings.

import 'package:caption_generator/caption_generator.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_generation_outcome.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/video_editor/caption_remote_transcriber.dart';
import 'package:unified_logger/unified_logger.dart';

export 'package:openvine/models/video_editor/caption_generation_outcome.dart';

/// Generates caption cues from the editor's clip timeline using the OS's
/// on-device speech recognition (`caption_generator`).
///
/// Per audible clip the audio is extracted at playback speed, transcribed to
/// word segments, windowed to the clip's trim range, and shifted onto the
/// composition timeline; the combined words are then grouped into
/// display-ready cues. Voice-over and music tracks are not transcribed —
/// this is a best-effort suggestion path over the clips' own audio.
class CaptionGenerationService {
  /// Creates the service.
  CaptionGenerationService({
    required AudioExtractionService audioExtractionService,
    required CaptionGenerator captionGenerator,
    CaptionRemoteTranscriber? remoteTranscriber,
  }) : _audioExtractionService = audioExtractionService,
       _captionGenerator = captionGenerator,
       _remoteTranscriber = remoteTranscriber;

  /// Creates the service with its production dependencies.
  ///
  /// Pass [remoteTranscriber] to prefer server-side transcription (falling
  /// back to on-device per clip on failure); omit it for on-device only.
  factory CaptionGenerationService.production({
    CaptionRemoteTranscriber? remoteTranscriber,
  }) => CaptionGenerationService(
    audioExtractionService: AudioExtractionService(),
    captionGenerator: CaptionGenerator(),
    remoteTranscriber: remoteTranscriber,
  );

  final AudioExtractionService _audioExtractionService;
  final CaptionGenerator _captionGenerator;

  /// Optional server-side transcriber, preferred over [_captionGenerator] when
  /// present. Falls back to on-device per clip when a remote call fails.
  final CaptionRemoteTranscriber? _remoteTranscriber;

  static const String _logName = 'CaptionGenerationService';

  /// Transcribes [clips] into timeline-mapped caption cues.
  ///
  /// [localeIdentifier] is the BCP-47 recognition language (the app locale).
  /// Clips without a local video file, muted clips, and clips without an
  /// audio track are skipped. Never throws — failures come back as
  /// [CaptionsFailed].
  Future<CaptionGenerationOutcome> generateForClips({
    required List<DivineVideoClip> clips,
    required String localeIdentifier,
  }) async {
    final words = <CaptionSegment>[];
    var clipStart = Duration.zero;
    var totalDuration = Duration.zero;
    for (final clip in clips) {
      totalDuration += clip.playbackDuration;
    }

    for (final clip in clips) {
      final videoPath = clip.video?.file?.path;
      final start = clipStart;
      clipStart += clip.playbackDuration;
      if (videoPath == null || clip.volume <= 0) continue;

      final String audioPath;
      try {
        final extraction = await _audioExtractionService.extractAudio(
          videoPath: videoPath,
          speed: _effectiveSpeed(clip),
        );
        audioPath = extraction.audioFilePath;
      } on AudioExtractionException catch (e) {
        if (e.message.contains('no audio track')) {
          continue;
        }
        Log.warning(
          '🎬 Caption audio extraction failed for clip ${clip.id}: $e',
          name: _logName,
          category: LogCategory.video,
        );
        return const CaptionsFailed(CaptionGenerationFailure.failed);
      }

      try {
        final segments = await _transcribeClip(
          audioPath: audioPath,
          localeIdentifier: localeIdentifier,
        );
        words.addAll(_mapToTimeline(segments, clip, clipStartTime: start));
      } on CaptionGenerationException catch (e) {
        Log.warning(
          '🎬 Caption transcription failed for clip ${clip.id}: $e',
          name: _logName,
          category: LogCategory.video,
        );
        return CaptionsFailed(_mapFailure(e));
      } finally {
        await _cleanupQuietly(audioPath);
      }
    }

    if (words.isEmpty) return const CaptionsEmpty();

    final grouped = groupCaptionSegments(words);
    final cues = <CaptionCue>[
      for (final (index, segment) in grouped.indexed)
        CaptionCue(
          id: 'cue-$index',
          text: segment.text,
          start: segment.start,
          end: segment.end > totalDuration ? totalDuration : segment.end,
        ),
    ];
    return CaptionsGenerated(cues);
  }

  /// Transcribes one clip's audio, preferring the server-side transcriber and
  /// falling back to on-device recognition when it fails.
  ///
  /// Remote failures are swallowed (logged) so a flaky network never blocks
  /// generation; an on-device [CaptionGenerationException] still propagates to
  /// the caller so it can surface the right failure reason.
  Future<List<CaptionSegment>> _transcribeClip({
    required String audioPath,
    required String localeIdentifier,
  }) async {
    final remote = _remoteTranscriber;
    if (remote != null) {
      try {
        return await remote.transcribe(
          audioPath: audioPath,
          localeIdentifier: localeIdentifier,
        );
      } on Object catch (e) {
        Log.warning(
          '🎬 Remote caption transcription failed; falling back to '
          'on-device: $e',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }
    return _captionGenerator.generateCaptions(
      audioPath: audioPath,
      localeIdentifier: localeIdentifier,
    );
  }

  /// Windows [segments] (timed in the clip's full-source playback time) to
  /// the clip's trim range and shifts them onto the composition timeline.
  List<CaptionSegment> _mapToTimeline(
    List<CaptionSegment> segments,
    DivineVideoClip clip, {
    required Duration clipStartTime,
  }) {
    final windowStart = clip.sourceDurationToPlaybackDuration(clip.trimStart);
    final windowEnd = windowStart + clip.playbackDuration;
    final shift = clipStartTime - windowStart;
    return [
      for (final segment in segments)
        if (segment.end > windowStart && segment.start < windowEnd)
          CaptionSegment(
            text: segment.text,
            start: _clamp(segment.start, windowStart, windowEnd) + shift,
            end: _clamp(segment.end, windowStart, windowEnd) + shift,
          ),
    ];
  }

  static Duration _clamp(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double _effectiveSpeed(DivineVideoClip clip) {
    final speed = clip.playbackSpeed;
    return speed != null && speed > 0 ? speed : 1.0;
  }

  static CaptionGenerationFailure _mapFailure(CaptionGenerationException e) =>
      switch (e) {
        SpeechRecognizerUnavailableException() =>
          CaptionGenerationFailure.recognizerUnavailable,
        SpeechNotAuthorizedException() =>
          CaptionGenerationFailure.notAuthorized,
        UnsupportedAudioFormatException() =>
          CaptionGenerationFailure.unsupportedAudio,
        AudioFileNotFoundException() ||
        TranscriptionFailedException() => CaptionGenerationFailure.failed,
      };

  Future<void> _cleanupQuietly(String audioPath) async {
    try {
      await _audioExtractionService.cleanupAudioFile(audioPath);
    } catch (e) {
      Log.warning(
        '🎬 Failed to clean up caption extraction WAV: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }
}
