// ABOUTME: Orchestrates the full subtitle generation pipeline.
// ABOUTME: Transcribe with Whisper -> publish Kind 39307 -> update video event.

import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/whisper_transcription_service.dart';

/// Stages of subtitle generation for progress reporting.
enum SubtitleGenerationStage {
  downloadingModel,
  extractingAudio,
  transcribing,
  publishingSubtitles,
  publishingEvent,
  done,
}

/// Exception for subtitle generation failures.
class SubtitleGenerationException implements Exception {
  SubtitleGenerationException(this.message);
  final String message;

  @override
  String toString() => 'SubtitleGenerationException: $message';
}

/// Orchestrates the full subtitle generation pipeline:
/// 1. Download Whisper model (if needed)
/// 2. Transcribe video with Whisper
/// 3. Publish subtitle as Kind 39307 Nostr event
/// 4. Republish video event with text-track tag
class SubtitleGenerationService {
  SubtitleGenerationService({
    required WhisperTranscriptionService whisperService,
    required AuthService authService,
    required VideoEventPublisher eventPublisher,
    required NostrClient nostrClient,
  }) : _whisperService = whisperService,
       _authService = authService,
       _eventPublisher = eventPublisher,
       _nostrClient = nostrClient;

  final WhisperTranscriptionService _whisperService;
  final AuthService _authService;
  final VideoEventPublisher _eventPublisher;
  final NostrClient _nostrClient;

  static const int subtitleEventKind = 39307;

  /// Generate subtitles and publish them for [video].
  ///
  /// [videoFilePath] is the local path to the video file.
  /// [onStage] reports progress through the pipeline stages.
  ///
  /// Throws [SubtitleGenerationException] on failure.
  Future<void> generateAndPublish({
    required VideoEvent video,
    required String videoFilePath,
    void Function(SubtitleGenerationStage)? onStage,
  }) async {
    // Stage 1: Download model if needed
    onStage?.call(SubtitleGenerationStage.downloadingModel);
    await _whisperService.ensureModel();

    // Stage 2: Extracting audio (whisper handles this internally)
    onStage?.call(SubtitleGenerationStage.extractingAudio);

    // Stage 3: Transcribe
    onStage?.call(SubtitleGenerationStage.transcribing);
    final cues = await _whisperService.transcribe(videoFilePath);

    if (cues.isEmpty) {
      throw SubtitleGenerationException('No speech detected');
    }

    final vttString = SubtitleService.generateVtt(cues);

    // Stage 4: Publish subtitle event (Kind 39307)
    onStage?.call(SubtitleGenerationStage.publishingSubtitles);
    final dTag = 'subtitles:${video.vineId}';

    final subtitleEvent = await _authService.createAndSignEvent(
      kind: subtitleEventKind,
      content: vttString,
      tags: [
        ['d', dTag],
        ['a', '34236:${video.pubkey}:${video.vineId}'],
        ['m', 'text/vtt'],
        ['l', 'en', 'ISO-639-1'],
        ['alt', 'Subtitles for: ${video.title ?? video.vineId}'],
      ],
    );

    if (subtitleEvent == null) {
      throw SubtitleGenerationException('Failed to sign subtitle event');
    }

    final publishResult = await _nostrClient.publishEvent(subtitleEvent);
    if (publishResult == null) {
      throw SubtitleGenerationException('Failed to publish subtitle event');
    }

    // Stage 5: Republish video event with text-track tag
    onStage?.call(SubtitleGenerationStage.publishingEvent);
    final textTrackRef = '$subtitleEventKind:${video.pubkey}:$dTag';

    await _eventPublisher.republishWithSubtitles(
      existingEvent: video,
      textTrackRef: textTrackRef,
      textTrackLang: 'en',
    );

    onStage?.call(SubtitleGenerationStage.done);
  }
}
