// ABOUTME: Service wrapping whisper_ggml_plus for on-device speech-to-text.
// ABOUTME: Handles model download, audio transcription, and VTT generation.

import 'dart:io';

import 'package:openvine/services/subtitle_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

/// Exception thrown when transcription fails.
class TranscriptionException implements Exception {
  TranscriptionException(this.message);
  final String message;

  @override
  String toString() => 'TranscriptionException: $message';
}

/// Service for on-device speech-to-text using Whisper.
class WhisperTranscriptionService {
  WhisperTranscriptionService({WhisperModel model = WhisperModel.base})
    : _whisper = Whisper(model: model),
      _model = model;

  final Whisper _whisper;
  final WhisperModel _model;

  /// Check if the model file exists locally.
  Future<bool> isModelDownloaded() async {
    final path = await _modelPath();
    return File(path).existsSync();
  }

  /// Download the model if not already present.
  /// [onProgress] receives 0.0 to 1.0 progress updates.
  Future<void> ensureModel({void Function(double)? onProgress}) async {
    if (await isModelDownloaded()) return;

    final modelDir = await _modelDir();
    final dir = Directory(modelDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(_model.modelUri);
      final response = await request.close();

      final filePath = await _modelPath();
      final file = File(filePath);
      final sink = file.openWrite();

      final totalBytes = response.contentLength;
      var receivedBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(receivedBytes / totalBytes);
        }
      }

      await sink.close();
    } finally {
      client.close();
    }
  }

  /// Transcribe a video/audio file to a list of [SubtitleCue]s.
  ///
  /// Throws [TranscriptionException] if the model has not been downloaded.
  /// Returns an empty list if no speech segments are detected.
  Future<List<SubtitleCue>> transcribe(String filePath) async {
    final modelPath = await _modelPath();
    if (!File(modelPath).existsSync()) {
      throw TranscriptionException(
        'Model not downloaded. Call ensureModel() first.',
      );
    }

    final response = await _whisper.transcribe(
      transcribeRequest: TranscribeRequest(audio: filePath),
      modelPath: modelPath,
    );

    final segments = response.segments;
    if (segments == null || segments.isEmpty) {
      return [];
    }

    return segments
        .map(
          (seg) => SubtitleCue(
            start: seg.fromTs.inMilliseconds,
            end: seg.toTs.inMilliseconds,
            text: seg.text.trim(),
          ),
        )
        .where((cue) => cue.text.isNotEmpty)
        .toList();
  }

  /// Generate a VTT string from a video/audio file.
  Future<String> transcribeToVtt(String filePath) async {
    final cues = await transcribe(filePath);
    return SubtitleService.generateVtt(cues);
  }

  Future<String> _modelDir() async {
    final appDir = await getApplicationSupportDirectory();
    return '${appDir.path}/whisper_models';
  }

  Future<String> _modelPath() async {
    final dir = await _modelDir();
    return '$dir/${_model.modelName}';
  }
}
