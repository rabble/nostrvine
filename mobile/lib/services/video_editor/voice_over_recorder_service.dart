// ABOUTME: Microphone capture service for the video editor's voice-over flow.
// ABOUTME: Wraps the `record` package and normalizes amplitude for the waveform.

import 'dart:async';

import 'package:record/record.dart';

/// Captures microphone audio for the voice-over recorder.
///
/// Kept free of permission and UI concerns: the caller (the
/// `VoiceOverCubit`) gates recording behind a microphone permission check
/// and owns the recorded files. This abstraction exists so the cubit can be
/// unit-tested with a fake recorder instead of hitting native audio APIs.
abstract class VoiceOverRecorderService {
  /// Starts recording to [path], which should be an `.m4a` file path.
  ///
  /// Throws if the microphone is unavailable or permission was not granted.
  Future<void> start(String path);

  /// Stops the current recording.
  ///
  /// Returns the path of the written file, or `null` when nothing was
  /// recorded.
  Future<String?> stop();

  /// Normalized (`0.0`–`1.0`) amplitude updates emitted while recording.
  ///
  /// `0.0` is silence and `1.0` is the loudest level the meter represents.
  Stream<double> get amplitudeStream;

  /// Releases native recorder resources.
  Future<void> dispose();
}

/// [VoiceOverRecorderService] backed by the `record` package.
class RecordVoiceOverRecorderService implements VoiceOverRecorderService {
  /// Creates the service. An [AudioRecorder] can be injected for testing.
  RecordVoiceOverRecorderService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// Mono AAC (the package default encoder) in an MP4 container — broadly
  /// supported on iOS and Android and renderable through the editor's
  /// [EditorAudio.file] path.
  static const _config = RecordConfig(numChannels: 1);

  /// How often the meter reports a new amplitude sample.
  static const _amplitudeInterval = Duration(milliseconds: 100);

  /// Floor of the dBFS range we map onto the `0.0`–`1.0` waveform. Levels
  /// quieter than this are treated as silence.
  static const _minDb = -45.0;

  @override
  Stream<double> get amplitudeStream =>
      _recorder.onAmplitudeChanged(_amplitudeInterval).map(_normalize);

  @override
  Future<void> start(String path) => _recorder.start(_config, path: path);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();

  static double _normalize(Amplitude amplitude) {
    final db = amplitude.current;
    if (db.isNaN || db.isInfinite) return 0;
    final clamped = db.clamp(_minDb, 0.0);
    return ((clamped - _minDb) / -_minDb).clamp(0.0, 1.0);
  }
}
