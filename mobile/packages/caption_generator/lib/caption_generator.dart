// ABOUTME: Public API for on-device closed caption generation from audio.
// ABOUTME: Uses SFSpeechRecognizer on Apple and SpeechRecognizer on Android.

import 'dart:io';

import 'package:caption_generator/caption_generator_platform_interface.dart';
import 'package:caption_generator/src/exceptions.dart';
import 'package:caption_generator/src/models/caption_segment.dart';
import 'package:caption_generator/src/wav_preprocessor.dart';
import 'package:flutter/foundation.dart';

export 'src/caption_grouper.dart';
export 'src/exceptions.dart';
export 'src/models/caption_segment.dart';

/// Generates closed captions from an audio file using the operating system's
/// on-device speech recognition.
///
/// This is a best-effort, last-resort transcription path: accuracy depends on
/// the audio quality and the on-device recognizer, so results should be
/// presented as editable suggestions rather than authoritative captions.
///
/// The input is typically the WAV file produced by `pro_video_editor` audio
/// extraction. Apple platforms accept any audio container the OS can read;
/// Android requires a 16-bit integer or 32-bit float PCM WAV, which this
/// class converts to the 16 kHz mono PCM the platform recognizer expects.
///
/// On Android the platform `SpeechRecognizer` supports file input from
/// Android 14 on; older devices and devices without Google's on-device
/// recognition service throw [SpeechRecognizerUnavailableException].
class CaptionGenerator {
  /// Creates a caption generator.
  CaptionGenerator();

  static const String _preparedWavSuffix = '.cc16k.wav';

  CaptionGeneratorPlatform get _platform => CaptionGeneratorPlatform.instance;

  /// Transcribes the audio file at [audioPath] into word-level
  /// [CaptionSegment]s ordered by start time.
  ///
  /// Use `groupCaptionSegments` to merge the word-level result into
  /// display-ready caption cues. Returns an empty list when no speech was
  /// recognized.
  ///
  /// [localeIdentifier] selects the recognition language as a BCP-47 tag
  /// (e.g. `en-US`); underscores are normalized to hyphens. Defaults to the
  /// device locale. On Android, word end times are approximated from the next
  /// word's start because the platform only reports start offsets.
  ///
  /// [preferOnDeviceRecognition] keeps recognition on-device on Apple
  /// platforms whenever the locale supports it; otherwise Apple's
  /// server-based recognition is used. Android always runs on-device.
  ///
  /// Throws:
  ///
  /// * [AudioFileNotFoundException] if [audioPath] does not exist.
  /// * [UnsupportedAudioFormatException] if the audio cannot be read
  ///   (Android WAV requirements above).
  /// * [SpeechNotAuthorizedException] if the user denied speech recognition
  ///   (Apple platforms).
  /// * [SpeechRecognizerUnavailableException] if the device or locale has no
  ///   recognizer — on Android also below Android 14 or without Google's
  ///   on-device recognition service.
  /// * [TranscriptionFailedException] for any other recognizer failure.
  /// * [UnsupportedError] on platforms other than Android, iOS, and macOS.
  Future<List<CaptionSegment>> generateCaptions({
    required String audioPath,
    String? localeIdentifier,
    bool preferOnDeviceRecognition = true,
  }) async {
    if (!File(audioPath).existsSync()) {
      throw AudioFileNotFoundException(audioPath);
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _generateOnAndroid(
        audioPath: audioPath,
        localeIdentifier: localeIdentifier,
      ),
      TargetPlatform.iOS || TargetPlatform.macOS => _platform.transcribe(
        audioPath: audioPath,
        localeIdentifier: localeIdentifier,
        preferOnDeviceRecognition: preferOnDeviceRecognition,
      ),
      _ => throw UnsupportedError(
        'caption_generator supports Android, iOS, and macOS only.',
      ),
    };
  }

  Future<List<CaptionSegment>> _generateOnAndroid({
    required String audioPath,
    required String? localeIdentifier,
  }) async {
    final preparedPath = await WavPreprocessor.prepareForRecognition(
      inputPath: audioPath,
      outputPath: '$audioPath$_preparedWavSuffix',
    );
    try {
      return await _platform.transcribe(
        audioPath: preparedPath,
        localeIdentifier: localeIdentifier,
      );
    } finally {
      if (preparedPath != audioPath) {
        _deleteQuietly(preparedPath);
      }
    }
  }

  /// Best-effort cleanup of the converted temp WAV; a leftover file in the
  /// app temp directory is harmless and must not mask the transcribe result.
  void _deleteQuietly(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
      // A failing delete needs an OS-level race or permission flip that a
      // unit test cannot portably produce, hence the coverage exclusion.
      // coverage:ignore-start
    } on FileSystemException {
      // Intentionally ignored — see doc comment.
    }
    // coverage:ignore-end
  }
}
