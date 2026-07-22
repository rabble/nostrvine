// ABOUTME: Converts extracted WAV audio into the 16 kHz mono 16-bit PCM the
// ABOUTME: Android recognizer wants. Pure-Dart RIFF parse, downmix, resample.

import 'dart:io';
import 'dart:isolate';

import 'package:caption_generator/src/exceptions.dart';
import 'package:flutter/foundation.dart';

/// The audio a caller should hand to the platform recognizer, plus ownership
/// of any temporary artifact created while preparing it.
///
/// [WavPreprocessor.prepareForRecognition] returns one of these instead of a
/// bare path so the caller knows whether it now owns a package-created temp
/// file. Always [dispose] the result once transcription is done.
class PreparedRecognitionAudio {
  PreparedRecognitionAudio._(this.path, this._workDirectory);

  /// The audio file the recognizer should read.
  final String path;

  /// Package-owned temp directory holding the converted file, or `null` when
  /// [path] is the untouched input (canonical passthrough).
  final Directory? _workDirectory;

  /// Whether [path] is a package-created temporary file the caller owns.
  bool get isTemporary => _workDirectory != null;

  /// Deletes the temporary artifact, if any.
  ///
  /// Safe on a passthrough result and safe to call more than once. Best
  /// effort: a leftover temp file is harmless and must never surface as an
  /// error over the transcription result.
  Future<void> dispose() =>
      WavPreprocessor._deleteWorkDirQuietly(_workDirectory);
}

/// Rewrites WAV audio into the canonical format the Android platform
/// `SpeechRecognizer` consumes: 16 kHz, mono, 16-bit integer PCM.
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

  static const String _convertedFileName = 'recognition_input.cc16k.wav';

  /// Lowest input sample rate we will resample. Below this a header is treated
  /// as malformed: linear upsampling to 16 kHz would inflate the sample count
  /// by more than 4x, so a low-rate header is the classic
  /// allocation-amplification vector.
  static const int _minInputSampleRate = 4000;

  /// Highest input sample rate we will resample; nothing real records above
  /// this, so a larger value signals a corrupt header.
  static const int _maxInputSampleRate = 192000;

  /// Longest clip we will resample, expressed as 16 kHz mono output frames
  /// (30 minutes). Guards against a large — but structurally valid — header
  /// driving an unbounded allocation. Short-form video never approaches this.
  static const int _maxConvertedFrames = targetSampleRate * 60 * 30;

  /// Largest PCM payload we will read into memory (64 MiB). Checked against the
  /// data chunk's declared size while parsing the header, before any payload
  /// buffer is allocated, so an oversized or sparse (huge declared size, tiny
  /// file) WAV is rejected instead of exhausting the process.
  static const int _maxDataBytes = 64 * 1024 * 1024;

  /// Set true whenever the conversion routine executes, in whichever isolate
  /// runs it. Because statics are per-isolate, a value observed in the caller
  /// isolate after [prepareForRecognition] proves whether the heavy work ran
  /// on-caller (true) or in the worker isolate (still false). Test probe only.
  @visibleForTesting
  static bool debugConversionRanInCallerIsolate = false;

  /// Overrides how the per-call working directory is created so tests can
  /// force a creation failure. `null` uses [Directory.systemTemp]. Test only.
  @visibleForTesting
  static Future<Directory> Function(String prefix)?
  debugCreateWorkDirectoryOverride;

  /// Prepares the WAV at [inputPath] for speech recognition.
  ///
  /// The header is parsed with bounded reads and its size limits validated
  /// before any payload is allocated; decoding, downmixing, resampling, and
  /// encoding then run in a worker isolate (via [Isolate.run]) so a long clip
  /// never stalls the caller and a malformed header cannot drive a runaway
  /// allocation.
  ///
  /// Returns a [PreparedRecognitionAudio] whose `path` is [inputPath] itself
  /// when the audio is already 16 kHz mono 16-bit integer PCM in a plain
  /// `fmt ` chunk (`isTemporary == false`); otherwise `path` is a unique
  /// package-owned temporary file the caller must
  /// [PreparedRecognitionAudio.dispose] after use. The original input is
  /// never modified. Each call uses its own temp directory, so overlapping
  /// conversions of the same source never collide.
  ///
  /// A `WAVE_FORMAT_EXTENSIBLE` wrapper is never passed through even when its
  /// subformat is already the target format: the minimal native Android reader
  /// only accepts a literal PCM `fmt ` chunk, so extensible files are always
  /// re-encoded to that.
  ///
  /// Throws:
  ///
  /// * [AudioFileNotFoundException] if [inputPath] does not exist.
  /// * [UnsupportedAudioFormatException] if the file is not a readable
  ///   RIFF/WAVE file in a supported PCM encoding, its sample rate is out of
  ///   range, or the payload is too large / the clip too long to prepare.
  /// * [TranscriptionFailedException] if creating the temp directory, or
  ///   reading the input or writing the converted output, fails.
  static Future<PreparedRecognitionAudio> prepareForRecognition({
    required String inputPath,
  }) async {
    if (!File(inputPath).existsSync()) {
      throw AudioFileNotFoundException(inputPath);
    }
    final workDirectory = await _createWorkDirectory();
    final outputPath = '${workDirectory.path}/$_convertedFileName';
    try {
      final didConvert = await Isolate.run(
        () => _runPreparation(
          inputPath,
          outputPath,
          _maxConvertedFrames,
          _maxDataBytes,
        ),
      );
      if (!didConvert) {
        await _deleteWorkDirQuietly(workDirectory);
        return PreparedRecognitionAudio._(inputPath, null);
      }
      return PreparedRecognitionAudio._(outputPath, workDirectory);
    } catch (_) {
      await _deleteWorkDirQuietly(workDirectory);
      rethrow;
    }
  }

  static Future<Directory> _createWorkDirectory() async {
    final create =
        debugCreateWorkDirectoryOverride ??
        (prefix) => Directory.systemTemp.createTemp(prefix);
    try {
      return await create('caption_generator');
    } on FileSystemException catch (error) {
      throw TranscriptionFailedException(
        'Could not create a working directory for audio preparation: '
        '${error.message}',
      );
    }
  }

  /// Reads, validates, and converts the WAV, writing the canonical output to
  /// [outputPath]. Returns `true` when it wrote a converted file, `false` when
  /// the input was already canonical and no output was written.
  ///
  /// Exposed for tests to drive the size-limit and read/write-failure paths
  /// directly; production always reaches it through [Isolate.run].
  @visibleForTesting
  static Future<bool> runPreparation(
    String inputPath,
    String outputPath, {
    int maxConvertedFrames = _maxConvertedFrames,
    int maxDataBytes = _maxDataBytes,
  }) =>
      _runPreparation(inputPath, outputPath, maxConvertedFrames, maxDataBytes);

  static Future<bool> _runPreparation(
    String inputPath,
    String outputPath,
    int maxConvertedFrames,
    int maxDataBytes,
  ) async {
    debugConversionRanInCallerIsolate = true;
    RandomAccessFile? raf;
    try {
      final Uint8List payload;
      final _WavHeader header;
      try {
        raf = File(inputPath).openSync();
        // Bounded metadata parse: reads only chunk headers and the fmt body,
        // never the payload, so limits are enforced before allocation.
        header = _WavHeader.readFrom(raf, raf.lengthSync());
        if (header.isCanonical) {
          return false;
        }
        header.assertConvertible(
          maxConvertedFrames: maxConvertedFrames,
          maxDataBytes: maxDataBytes,
        );
        raf.setPositionSync(header.dataOffset);
        payload = raf.readSync(header.dataLength);
      } on FileSystemException catch (error) {
        throw TranscriptionFailedException(
          'Could not read audio during preparation: ${error.message}',
        );
      }
      final mono = header.decodeMonoSamples(payload);
      final resampled = _resampleLinear(
        mono,
        header.sampleRate,
        targetSampleRate,
      );
      final encoded = _encodePcm16Wav(resampled, targetSampleRate);
      try {
        File(outputPath).writeAsBytesSync(encoded, flush: true);
      } on FileSystemException catch (error) {
        throw TranscriptionFailedException(
          'Could not write converted audio during preparation: '
          '${error.message}',
        );
      }
      return true;
    } finally {
      raf?.closeSync();
    }
  }

  static Future<void> _deleteWorkDirQuietly(Directory? directory) async {
    if (directory == null) return;
    try {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
      // A failing delete needs an OS-level race or permission flip that a
      // unit test cannot portably produce, hence the coverage exclusion.
      // coverage:ignore-start
    } on FileSystemException {
      // Intentionally ignored — a leftover temp dir is harmless.
    }
    // coverage:ignore-end
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

/// WAV metadata located by a bounded RIFF walk that never reads the payload.
class _WavHeader {
  _WavHeader._({
    required this.sampleRate,
    required this.channels,
    required this.isFloat32,
    required this.wasExtensible,
    required this.dataOffset,
    required this.dataLength,
    required this.declaredDataSize,
  });

  /// Parses the RIFF header of [raf] (whose length is [fileLength]) with
  /// bounded reads — only chunk headers and the `fmt ` body are read, so the
  /// payload is never loaded here.
  ///
  /// Throws [UnsupportedAudioFormatException] if the file is not a readable
  /// RIFF/WAVE file in a supported PCM encoding.
  factory _WavHeader.readFrom(RandomAccessFile raf, int fileLength) {
    if (fileLength < 12) {
      throw const UnsupportedAudioFormatException('Not a RIFF/WAVE file');
    }
    raf.setPositionSync(0);
    final riff = raf.readSync(12);
    if (riff.length < 12 ||
        !_hasAsciiTag(riff, 0, 'RIFF') ||
        !_hasAsciiTag(riff, 8, 'WAVE')) {
      throw const UnsupportedAudioFormatException('Not a RIFF/WAVE file');
    }
    int? formatCode;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? dataOffset;
    int? dataLength;
    int? declaredDataSize;
    var wasExtensible = false;
    var offset = 12;
    while (offset + 8 <= fileLength) {
      raf.setPositionSync(offset);
      final head = raf.readSync(8);
      if (head.length < 8) break;
      final chunkSize = ByteData.sublistView(head).getUint32(4, Endian.little);
      final bodyOffset = offset + 8;
      if (_hasAsciiTag(head, 0, 'fmt ') &&
          chunkSize >= 16 &&
          bodyOffset + 16 <= fileLength) {
        final available = fileLength - bodyOffset;
        final wanted = chunkSize >= 40 ? 40 : 16;
        final fmt = raf.readSync(wanted <= available ? wanted : available);
        final data = ByteData.sublistView(fmt);
        formatCode = data.getUint16(0, Endian.little);
        channels = data.getUint16(2, Endian.little);
        sampleRate = data.getUint32(4, Endian.little);
        bitsPerSample = data.getUint16(14, Endian.little);
        if (formatCode == WavPreprocessor._extensibleFormat &&
            chunkSize >= 40 &&
            fmt.length >= 26) {
          // WAVE_FORMAT_EXTENSIBLE: the real format is the first two bytes of
          // the SubFormat GUID at offset 24 of the fmt chunk body.
          wasExtensible = true;
          formatCode = data.getUint16(24, Endian.little);
        }
      } else if (_hasAsciiTag(head, 0, 'data')) {
        dataOffset = bodyOffset;
        declaredDataSize = chunkSize;
        final available = fileLength - bodyOffset;
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
    if (dataOffset == null || dataLength == null || declaredDataSize == null) {
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
    return _WavHeader._(
      sampleRate: sampleRate,
      channels: channels,
      isFloat32: isFloat32,
      wasExtensible: wasExtensible,
      dataOffset: dataOffset,
      dataLength: dataLength,
      declaredDataSize: declaredDataSize,
    );
  }

  final int sampleRate;
  final int channels;
  final bool isFloat32;

  /// Whether the source `fmt ` chunk was `WAVE_FORMAT_EXTENSIBLE`. Such files
  /// are always re-encoded because the native Android reader only accepts a
  /// literal PCM `fmt ` chunk.
  final bool wasExtensible;

  /// Byte offset of the payload within the file.
  final int dataOffset;

  /// Payload bytes actually present (declared size clamped to the file).
  final int dataLength;

  /// Payload size the `data` chunk header declares, used for the size guard so
  /// a sparse file (huge declared size, tiny body) is rejected up front.
  final int declaredDataSize;

  /// Whether the audio is already exactly what the recognizer wants and can be
  /// passed through untouched.
  bool get isCanonical =>
      sampleRate == WavPreprocessor.targetSampleRate &&
      channels == 1 &&
      !isFloat32 &&
      !wasExtensible;

  /// Rejects inputs whose conversion would allocate unbounded or amplified
  /// buffers, before any payload is read. Called only after [isCanonical] is
  /// `false`, i.e. a conversion is actually required.
  void assertConvertible({
    required int maxConvertedFrames,
    required int maxDataBytes,
  }) {
    if (sampleRate < WavPreprocessor._minInputSampleRate ||
        sampleRate > WavPreprocessor._maxInputSampleRate) {
      throw UnsupportedAudioFormatException(
        'Unsupported sample rate ${sampleRate}Hz '
        '(accepts ${WavPreprocessor._minInputSampleRate}'
        '-${WavPreprocessor._maxInputSampleRate}Hz)',
      );
    }
    if (declaredDataSize > maxDataBytes) {
      throw UnsupportedAudioFormatException(
        'Audio payload is too large to prepare for recognition: '
        '$declaredDataSize bytes exceeds the $maxDataBytes-byte limit',
      );
    }
    final frameSize = (isFloat32 ? 4 : 2) * channels;
    final frameCount = dataLength ~/ frameSize;
    final convertedFrames =
        frameCount * WavPreprocessor.targetSampleRate ~/ sampleRate;
    if (convertedFrames > maxConvertedFrames) {
      throw UnsupportedAudioFormatException(
        'Audio is too long to prepare for recognition: '
        '$convertedFrames frames exceeds the $maxConvertedFrames-frame limit',
      );
    }
  }

  /// Decodes the [payload] PCM (the raw `data` chunk bytes) to doubles in
  /// [-1, 1], averaging all channels down to mono.
  Float64List decodeMonoSamples(Uint8List payload) {
    final data = ByteData.sublistView(payload);
    final bytesPerSample = isFloat32 ? 4 : 2;
    final frameSize = bytesPerSample * channels;
    final frameCount = dataLength ~/ frameSize;
    final samples = Float64List(frameCount);
    for (var frame = 0; frame < frameCount; frame++) {
      var sum = 0.0;
      final frameOffset = frame * frameSize;
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
