// ABOUTME: Tests for the WAV-to-16kHz-mono-PCM recognition preprocessor.
// ABOUTME: Covers conversion, passthrough, malformed input, and edge chunks.

import 'dart:io';

import 'package:caption_generator/src/exceptions.dart';
import 'package:caption_generator/src/wav_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/wav_builder.dart';

void main() {
  group(WavPreprocessor, () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('wav_preprocessor_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    String writeWav(String name, List<int> bytes) {
      final path = '${tempDir.path}/$name';
      File(path).writeAsBytesSync(bytes);
      return path;
    }

    String outputPathFor(String inputPath) => '$inputPath.out.wav';

    test('converts 44.1 kHz stereo PCM16 to 16 kHz mono', () async {
      final inputPath = writeWav(
        'stereo.wav',
        buildWav(
          channels: [
            List.filled(4410, 0.5),
            List.filled(4410, -0.25),
          ],
        ),
      );

      final resultPath = await WavPreprocessor.prepareForRecognition(
        inputPath: inputPath,
        outputPath: outputPathFor(inputPath),
      );

      expect(resultPath, equals(outputPathFor(inputPath)));
      final decoded = DecodedWav.parse(
        File(resultPath).readAsBytesSync(),
      );
      expect(decoded.formatCode, equals(1));
      expect(decoded.channels, equals(1));
      expect(decoded.sampleRate, equals(16000));
      expect(decoded.bitsPerSample, equals(16));
      expect(decoded.samples, hasLength(4410 * 16000 ~/ 44100));
      // Stereo downmix of constant 0.5 and -0.25 averages to 0.125.
      final expected = (0.125 * 32767).round();
      for (final sample in decoded.samples) {
        expect(sample, closeTo(expected, 2));
      }
    });

    test(
      'converted output round-trips through the parser as canonical',
      () async {
        // Regression: the encoder once wrote its magic tags big-endian
        // ("FFIR"/"EVAW"), which only the native-side parser caught. Feeding
        // the output back through the real parser pins header validity.
        final inputPath = writeWav(
          'roundtrip.wav',
          buildWav(
            channels: [
              List.filled(4410, 0.5),
              List.filled(4410, -0.25),
            ],
          ),
        );

        final convertedPath = await WavPreprocessor.prepareForRecognition(
          inputPath: inputPath,
          outputPath: outputPathFor(inputPath),
        );

        final secondPass = await WavPreprocessor.prepareForRecognition(
          inputPath: convertedPath,
          outputPath: '$convertedPath.again.wav',
        );

        expect(secondPass, equals(convertedPath));
        expect(File('$convertedPath.again.wav').existsSync(), isFalse);
      },
    );

    test('returns the input path unchanged for 16 kHz mono PCM16', () async {
      final inputPath = writeWav(
        'mono16k.wav',
        buildWav(channels: [List.filled(1600, 0.25)], sampleRate: 16000),
      );

      final resultPath = await WavPreprocessor.prepareForRecognition(
        inputPath: inputPath,
        outputPath: outputPathFor(inputPath),
      );

      expect(resultPath, equals(inputPath));
      expect(File(outputPathFor(inputPath)).existsSync(), isFalse);
    });

    test('converts 32-bit float samples to 16-bit integers', () async {
      final inputPath = writeWav(
        'float.wav',
        buildWav(
          channels: [List.filled(1600, 0.5)],
          sampleRate: 16000,
          float32: true,
        ),
      );

      final resultPath = await WavPreprocessor.prepareForRecognition(
        inputPath: inputPath,
        outputPath: outputPathFor(inputPath),
      );

      expect(resultPath, equals(outputPathFor(inputPath)));
      final decoded = DecodedWav.parse(File(resultPath).readAsBytesSync());
      expect(decoded.sampleRate, equals(16000));
      expect(decoded.samples, hasLength(1600));
      final expected = (0.5 * 32767).round();
      for (final sample in decoded.samples) {
        expect(sample, closeTo(expected, 2));
      }
    });

    test('upsamples with linear interpolation', () async {
      // A linear ramp stays a linear ramp under linear interpolation.
      final ramp = List.generate(800, (i) => i / 800);
      final inputPath = writeWav(
        'ramp.wav',
        buildWav(channels: [ramp], sampleRate: 8000),
      );

      final resultPath = await WavPreprocessor.prepareForRecognition(
        inputPath: inputPath,
        outputPath: outputPathFor(inputPath),
      );

      final decoded = DecodedWav.parse(File(resultPath).readAsBytesSync());
      expect(decoded.samples, hasLength(1600));
      // Output index 800 maps to source index 400, i.e. ramp value 400/800.
      expect(decoded.samples[800], closeTo((0.5 * 32767).round(), 50));
      expect(decoded.samples[400], closeTo((0.25 * 32767).round(), 50));
    });

    test('skips junk chunks and honors odd-size padding', () async {
      final inputPath = writeWav(
        'junk.wav',
        buildWav(
          channels: [List.filled(441, 0.5)],
          includeJunkChunk: true,
        ),
      );

      final resultPath = await WavPreprocessor.prepareForRecognition(
        inputPath: inputPath,
        outputPath: outputPathFor(inputPath),
      );

      final decoded = DecodedWav.parse(File(resultPath).readAsBytesSync());
      expect(decoded.sampleRate, equals(16000));
      expect(decoded.samples, isNotEmpty);
    });

    test('reads WAVE_FORMAT_EXTENSIBLE PCM16', () async {
      final inputPath = writeWav(
        'extensible.wav',
        buildWav(
          channels: [
            List.filled(441, 0.5),
            List.filled(441, 0.5),
          ],
          extensible: true,
        ),
      );

      final resultPath = await WavPreprocessor.prepareForRecognition(
        inputPath: inputPath,
        outputPath: outputPathFor(inputPath),
      );

      final decoded = DecodedWav.parse(File(resultPath).readAsBytesSync());
      expect(decoded.channels, equals(1));
      expect(decoded.sampleRate, equals(16000));
    });

    test('throws $UnsupportedAudioFormatException for a non-RIFF file', () {
      final inputPath = writeWav('not_a_wav.wav', 'hello world'.codeUnits);

      expect(
        () => WavPreprocessor.prepareForRecognition(
          inputPath: inputPath,
          outputPath: outputPathFor(inputPath),
        ),
        throwsA(isA<UnsupportedAudioFormatException>()),
      );
    });

    test('throws $UnsupportedAudioFormatException for 8-bit PCM', () {
      final inputPath = writeWav(
        'pcm8.wav',
        buildWav(channels: [List.filled(441, 0.5)], bitsPerSample: 8),
      );

      expect(
        () => WavPreprocessor.prepareForRecognition(
          inputPath: inputPath,
          outputPath: outputPathFor(inputPath),
        ),
        throwsA(isA<UnsupportedAudioFormatException>()),
      );
    });

    test('throws $UnsupportedAudioFormatException for unsupported codes', () {
      final inputPath = writeWav(
        'alaw.wav',
        buildWav(channels: [List.filled(441, 0.5)], formatCode: 6),
      );

      expect(
        () => WavPreprocessor.prepareForRecognition(
          inputPath: inputPath,
          outputPath: outputPathFor(inputPath),
        ),
        throwsA(isA<UnsupportedAudioFormatException>()),
      );
    });

    test('throws for a zero-channel fmt chunk', () {
      final bytes = buildWav(channels: [List.filled(441, 0.5)]);
      // Channel count lives at bytes 22-23 (fmt body offset 2); zero it out.
      bytes[22] = 0;
      bytes[23] = 0;
      final inputPath = writeWav('zero_channels.wav', bytes);

      expect(
        () => WavPreprocessor.prepareForRecognition(
          inputPath: inputPath,
          outputPath: outputPathFor(inputPath),
        ),
        throwsA(isA<UnsupportedAudioFormatException>()),
      );
    });

    test('throws when the data chunk is missing', () {
      final inputPath = writeWav(
        'no_data.wav',
        buildWav(channels: [List.filled(441, 0.5)], omitDataChunk: true),
      );

      expect(
        () => WavPreprocessor.prepareForRecognition(
          inputPath: inputPath,
          outputPath: outputPathFor(inputPath),
        ),
        throwsA(isA<UnsupportedAudioFormatException>()),
      );
    });

    test('throws when the fmt chunk is missing', () {
      final inputPath = writeWav(
        'no_fmt.wav',
        buildWav(channels: [List.filled(441, 0.5)], omitFmtChunk: true),
      );

      expect(
        () => WavPreprocessor.prepareForRecognition(
          inputPath: inputPath,
          outputPath: outputPathFor(inputPath),
        ),
        throwsA(isA<UnsupportedAudioFormatException>()),
      );
    });

    test('throws $AudioFileNotFoundException for a missing input', () {
      expect(
        () => WavPreprocessor.prepareForRecognition(
          inputPath: '${tempDir.path}/missing.wav',
          outputPath: '${tempDir.path}/out.wav',
        ),
        throwsA(isA<AudioFileNotFoundException>()),
      );
    });
  });
}
