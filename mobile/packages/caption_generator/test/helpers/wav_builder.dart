// ABOUTME: Test helper that synthesizes RIFF/WAVE byte payloads.
// ABOUTME: Supports PCM16/float32, extensible wrappers, and junk chunks.

import 'dart:typed_data';

/// Builds a WAV file from per-channel samples in the range [-1, 1].
///
/// [channels] is indexed `[channel][sample]`; all channels must have the same
/// length. [formatCode] and [bitsPerSample] override the values implied by
/// [float32] to synthesize unsupported encodings. [extensible] wraps the
/// format in a `WAVE_FORMAT_EXTENSIBLE` fmt chunk. [includeJunkChunk] inserts
/// an odd-sized unknown chunk before `fmt ` to exercise chunk skipping.
/// [omitDataChunk] and [omitFmtChunk] produce intentionally malformed files.
Uint8List buildWav({
  required List<List<double>> channels,
  int sampleRate = 44100,
  bool float32 = false,
  bool extensible = false,
  bool includeJunkChunk = false,
  bool omitDataChunk = false,
  bool omitFmtChunk = false,
  int? formatCode,
  int? bitsPerSample,
}) {
  final channelCount = channels.length;
  final sampleCount = channels.first.length;
  final bytesPerSample = float32 ? 4 : 2;
  final bits = bitsPerSample ?? (float32 ? 32 : 16);
  final effectiveFormatCode =
      formatCode ?? (extensible ? 0xFFFE : (float32 ? 3 : 1));
  final subFormatCode = float32 ? 3 : 1;

  final dataSize = sampleCount * channelCount * bytesPerSample;
  final data = ByteData(dataSize);
  var offset = 0;
  for (var sample = 0; sample < sampleCount; sample++) {
    for (var channel = 0; channel < channelCount; channel++) {
      final value = channels[channel][sample];
      if (float32) {
        data.setFloat32(offset, value, Endian.little);
      } else {
        data.setInt16(offset, (value * 32767).round(), Endian.little);
      }
      offset += bytesPerSample;
    }
  }

  final chunks = BytesBuilder();
  if (includeJunkChunk) {
    // Odd-sized unknown chunk: parsers must skip it and honor the pad byte.
    chunks
      ..add('JUNK'.codeUnits)
      ..add(_uint32(3))
      ..add([1, 2, 3, 0]);
  }
  if (!omitFmtChunk) {
    final fmtSize = extensible ? 40 : 16;
    final fmt = ByteData(fmtSize)
      ..setUint16(0, effectiveFormatCode, Endian.little)
      ..setUint16(2, channelCount, Endian.little)
      ..setUint32(4, sampleRate, Endian.little)
      ..setUint32(8, sampleRate * channelCount * bytesPerSample, Endian.little)
      ..setUint16(12, channelCount * bytesPerSample, Endian.little)
      ..setUint16(14, bits, Endian.little);
    if (extensible) {
      fmt
        ..setUint16(16, 22, Endian.little) // cbSize
        ..setUint16(18, bits, Endian.little) // valid bits per sample
        ..setUint32(20, 0, Endian.little) // channel mask
        // SubFormat GUID: format code + fixed PCM GUID tail.
        ..setUint16(24, subFormatCode, Endian.little);
      const guidTail = [
        0x00, 0x00, 0x00, 0x00, 0x10, 0x00, //
        0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71,
      ];
      for (var i = 0; i < guidTail.length; i++) {
        fmt.setUint8(26 + i, guidTail[i]);
      }
    }
    chunks
      ..add('fmt '.codeUnits)
      ..add(_uint32(fmtSize))
      ..add(fmt.buffer.asUint8List());
  }
  if (!omitDataChunk) {
    chunks
      ..add('data'.codeUnits)
      ..add(_uint32(dataSize))
      ..add(data.buffer.asUint8List());
  }

  final body = chunks.takeBytes();
  final wav = BytesBuilder()
    ..add('RIFF'.codeUnits)
    ..add(_uint32(4 + body.length))
    ..add('WAVE'.codeUnits)
    ..add(body);
  return wav.takeBytes();
}

/// Decoded header and samples of a mono 16-bit PCM WAV produced by the
/// preprocessor, for assertions in tests.
class DecodedWav {
  DecodedWav._({
    required this.formatCode,
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.samples,
  });

  /// Parses the canonical 44-byte-header WAV the preprocessor writes.
  ///
  /// Throws a [FormatException] when a chunk tag is not the expected ASCII —
  /// the regression that shipped big-endian "FFIR"/"EVAW" tags proved that
  /// reading fields at fixed offsets alone validates nothing.
  factory DecodedWav.parse(Uint8List bytes) {
    void expectTag(int offset, String tag) {
      final actual = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      if (actual != tag) {
        throw FormatException('Expected "$tag" at byte $offset, got "$actual"');
      }
    }

    expectTag(0, 'RIFF');
    expectTag(8, 'WAVE');
    expectTag(12, 'fmt ');
    expectTag(36, 'data');
    final data = ByteData.sublistView(bytes);
    final dataSize = data.getUint32(40, Endian.little);
    final samples = Int16List(dataSize ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = data.getInt16(44 + i * 2, Endian.little);
    }
    return DecodedWav._(
      formatCode: data.getUint16(20, Endian.little),
      channels: data.getUint16(22, Endian.little),
      sampleRate: data.getUint32(24, Endian.little),
      bitsPerSample: data.getUint16(34, Endian.little),
      samples: samples,
    );
  }

  final int formatCode;
  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final Int16List samples;
}

Uint8List _uint32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);
