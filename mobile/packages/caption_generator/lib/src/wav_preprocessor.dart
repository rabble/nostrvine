// ABOUTME: Converts extracted WAV audio into 16 kHz mono 16-bit PCM for Vosk.
// ABOUTME: Pure-Dart RIFF parsing, channel downmix, and linear resampling.

import 'dart:io';
import 'dart:typed_data';

import 'package:caption_generator/src/exceptions.dart';

/// Rewrites WAV audio into the canonical format the Android Vosk recognizer
/// consumes: 16 kHz, mono, 16-bit integer PCM.
///
/// Accepts the WAV flavors `pro_video_editor` audio extraction produces
/// (16-bit integer or 32-bit float PCM, any sample rate and channel count,
/// including `WAVE_FORMAT_EXTENSIBLE` wrappers of those).
abstract final class WavPreprocessor {
  /// Sample rate the recognizer input is converted to.
  static const int targetSampleRate = 16000;

  static const int _pcmFormat = 1;
  static const int _floatFormat = 3;
  static const int _extensibleFormat = 0xFFFE;

  /// Prepares the WAV at [inputPath] for speech recognition.
  ///
  /// Returns [inputPath] unchanged when the audio is already 16 kHz mono
  /// 16-bit PCM; otherwise writes the converted audio to [outputPath] and
  /// returns that. Callers own deleting [outputPath] afterwards.
  ///
  /// Throws:
  ///
  /// * [AudioFileNotFoundException] if [inputPath] does not exist.
  /// * [UnsupportedAudioFormatException] if the file is not a readable
  ///   RIFF/WAVE file in a supported PCM encoding.
  static Future<String> prepareForRecognition({
    required String inputPath,
    required String outputPath,
  }) async {
    final file = File(inputPath);
    if (!file.existsSync()) {
      throw AudioFileNotFoundException(inputPath);
    }
    final wav = _ParsedWav.parse(await file.readAsBytes());
    if (wav.sampleRate == targetSampleRate &&
        wav.channels == 1 &&
        !wav.isFloat32) {
      return inputPath;
    }
    final mono = wav.decodeMonoSamples();
    final resampled = _resampleLinear(mono, wav.sampleRate, targetSampleRate);
    await File(outputPath).writeAsBytes(
      _encodePcm16Wav(resampled, targetSampleRate),
    );
    return outputPath;
  }

  /// Linear-interpolation resampler; quality is sufficient for speech
  /// recognition input (this is not a playback path).
  static Float64List _resampleLinear(
    Float64List input,
    int sourceRate,
    int targetRate,
  ) {
    if (sourceRate == targetRate || input.isEmpty) return input;
    final outputLength = input.length * targetRate ~/ sourceRate;
    final output = Float64List(outputLength);
    final step = sourceRate / targetRate;
    for (var i = 0; i < outputLength; i++) {
      final sourcePosition = i * step;
      final index = sourcePosition.floor();
      final nextIndex = index + 1 < input.length ? index + 1 : index;
      final fraction = sourcePosition - index;
      output[i] = input[index] * (1 - fraction) + input[nextIndex] * fraction;
    }
    return output;
  }

  static Uint8List _encodePcm16Wav(Float64List samples, int sampleRate) {
    const headerSize = 44;
    final dataSize = samples.length * 2;
    final bytes = Uint8List(headerSize + dataSize);
    final data = ByteData.view(bytes.buffer)
      ..setUint32(0, 0x46464952, Endian.little) // "RIFF"
      ..setUint32(4, 36 + dataSize, Endian.little)
      ..setUint32(8, 0x45564157, Endian.little) // "WAVE"
      ..setUint32(12, 0x20746d66, Endian.little) // "fmt "
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, _pcmFormat, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, sampleRate * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x61746164, Endian.little) // "data"
      ..setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      data.setInt16(
        headerSize + i * 2,
        (clamped * 32767).round(),
        Endian.little,
      );
    }
    return bytes;
  }
}

class _ParsedWav {
  _ParsedWav._({
    required this.sampleRate,
    required this.channels,
    required this.isFloat32,
    required Uint8List bytes,
    required int dataOffset,
    required int dataLength,
  }) : _bytes = bytes,
       _dataOffset = dataOffset,
       _dataLength = dataLength;

  factory _ParsedWav.parse(Uint8List bytes) {
    if (bytes.length < 12 ||
        !_hasAsciiTag(bytes, 0, 'RIFF') ||
        !_hasAsciiTag(bytes, 8, 'WAVE')) {
      throw const UnsupportedAudioFormatException('Not a RIFF/WAVE file');
    }
    final data = ByteData.sublistView(bytes);
    int? formatCode;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? dataOffset;
    int? dataLength;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      final bodyOffset = offset + 8;
      if (_hasAsciiTag(bytes, offset, 'fmt ') &&
          chunkSize >= 16 &&
          bodyOffset + 16 <= bytes.length) {
        formatCode = data.getUint16(bodyOffset, Endian.little);
        channels = data.getUint16(bodyOffset + 2, Endian.little);
        sampleRate = data.getUint32(bodyOffset + 4, Endian.little);
        bitsPerSample = data.getUint16(bodyOffset + 14, Endian.little);
        if (formatCode == WavPreprocessor._extensibleFormat &&
            chunkSize >= 40 &&
            bodyOffset + 26 <= bytes.length) {
          // WAVE_FORMAT_EXTENSIBLE: the real format is the first two bytes of
          // the SubFormat GUID at offset 24 of the fmt chunk body.
          formatCode = data.getUint16(bodyOffset + 24, Endian.little);
        }
      } else if (_hasAsciiTag(bytes, offset, 'data')) {
        dataOffset = bodyOffset;
        final available = bytes.length - bodyOffset;
        dataLength = chunkSize < available ? chunkSize : available;
      }
      // Chunks are word-aligned: odd-sized chunks carry one padding byte.
      offset = bodyOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }
    if (formatCode == null ||
        channels == null ||
        sampleRate == null ||
        bitsPerSample == null) {
      throw const UnsupportedAudioFormatException('WAV has no fmt chunk');
    }
    if (dataOffset == null || dataLength == null) {
      throw const UnsupportedAudioFormatException('WAV has no data chunk');
    }
    if (channels < 1 || sampleRate < 1) {
      throw UnsupportedAudioFormatException(
        'Invalid WAV format: $channels channel(s) at $sampleRate Hz',
      );
    }
    final isFloat32 =
        formatCode == WavPreprocessor._floatFormat && bitsPerSample == 32;
    final isPcm16 =
        formatCode == WavPreprocessor._pcmFormat && bitsPerSample == 16;
    if (!isFloat32 && !isPcm16) {
      throw UnsupportedAudioFormatException(
        'Unsupported WAV encoding: format code $formatCode '
        'at $bitsPerSample bits per sample',
      );
    }
    return _ParsedWav._(
      sampleRate: sampleRate,
      channels: channels,
      isFloat32: isFloat32,
      bytes: bytes,
      dataOffset: dataOffset,
      dataLength: dataLength,
    );
  }

  final int sampleRate;
  final int channels;
  final bool isFloat32;
  final Uint8List _bytes;
  final int _dataOffset;
  final int _dataLength;

  /// Decodes the PCM payload to doubles in [-1, 1], averaging all channels
  /// down to mono.
  Float64List decodeMonoSamples() {
    final data = ByteData.sublistView(_bytes);
    final bytesPerSample = isFloat32 ? 4 : 2;
    final frameSize = bytesPerSample * channels;
    final frameCount = _dataLength ~/ frameSize;
    final samples = Float64List(frameCount);
    for (var frame = 0; frame < frameCount; frame++) {
      var sum = 0.0;
      final frameOffset = _dataOffset + frame * frameSize;
      for (var channel = 0; channel < channels; channel++) {
        final sampleOffset = frameOffset + channel * bytesPerSample;
        sum += isFloat32
            ? data.getFloat32(sampleOffset, Endian.little)
            : data.getInt16(sampleOffset, Endian.little) / 32768.0;
      }
      samples[frame] = sum / channels;
    }
    return samples;
  }

  static bool _hasAsciiTag(Uint8List bytes, int offset, String tag) {
    for (var i = 0; i < tag.length; i++) {
      if (bytes[offset + i] != tag.codeUnitAt(i)) return false;
    }
    return true;
  }
}
