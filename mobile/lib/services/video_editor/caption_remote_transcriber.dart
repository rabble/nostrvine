// ABOUTME: Server-side transcription seam for the captions editor.
// ABOUTME: Wraps the Blossom /transcribe endpoint and maps WebVTT to segments.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:caption_generator/caption_generator.dart';
import 'package:openvine/services/subtitle_service.dart';

/// Transcribes a local audio file into timed [CaptionSegment]s off-device.
///
/// Mirrors [CaptionGenerator.generateCaptions] so it can stand in for the
/// on-device recognizer in [CaptionGenerationService]. Implementations throw
/// on failure; the service falls back to on-device transcription when they do.
abstract class CaptionRemoteTranscriber {
  /// Transcribes the audio at [audioPath] using [localeIdentifier] as the
  /// recognition-language hint.
  Future<List<CaptionSegment>> transcribe({
    required String audioPath,
    required String localeIdentifier,
  });
}

/// Thrown when the server could not produce a transcript (auth, network, or a
/// non-success response). Signals the caller to fall back to on-device.
class CaptionRemoteTranscriptionException implements Exception {
  /// Creates the exception with a human-readable [message].
  const CaptionRemoteTranscriptionException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'CaptionRemoteTranscriptionException: $message';
}

/// [CaptionRemoteTranscriber] backed by the Divine Blossom `/transcribe`
/// endpoint (server-side transcription, higher quality than on-device).
class BlossomCaptionTranscriber implements CaptionRemoteTranscriber {
  /// Creates the transcriber over [_blossom].
  const BlossomCaptionTranscriber(this._blossom);

  final BlossomUploadService _blossom;

  @override
  Future<List<CaptionSegment>> transcribe({
    required String audioPath,
    required String localeIdentifier,
  }) async {
    final bytes = await File(audioPath).readAsBytes();
    final vtt = await _blossom.transcribeAudio(
      bytes: bytes,
      language: localeIdentifier,
    );
    if (vtt == null) {
      throw const CaptionRemoteTranscriptionException(
        'Server returned no transcript',
      );
    }
    // An empty VTT is a valid "no speech" result, not a failure.
    return [
      for (final cue in SubtitleService.parseVtt(vtt))
        CaptionSegment(
          text: cue.text,
          start: Duration(milliseconds: cue.start),
          end: Duration(milliseconds: cue.end),
        ),
    ];
  }
}
