// ABOUTME: Tests for the WAV-to-16kHz-mono-PCM recognition preprocessor.
// ABOUTME: Covers conversion, passthrough, bounds, isolation, and I/O failures.

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
      WavPreprocessor.debugConversionRanInCallerIsolate = false;
    });

    tearDown(() {
      WavPreprocessor.debugCreateWorkDirectoryOverride = null;
      tempDir.deleteSync(recursive: true);
    });

    String writeWav(String name, List<int> bytes) {
      final path = '${tempDir.path}/$name';
      File(path).writeAsBytesSync(bytes);
      return path;
    }

    Future<PreparedRecognitionAudio> prepare(String inputPath) =>
        WavPreprocessor.prepareForRecognition(inputPath: inputPath);

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

      final prepared = await prepare(inputPath);
      addTearDown(prepared.dispose);

      expect(prepared.isTemporary, isTrue);
      expect(prepared.path, isNot(equals(inputPath)));
      final decoded = DecodedWav.parse(File(prepared.path).readAsBytesSync());
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
      // The original input is never modified.
      expect(File(inputPath).existsSync(), isTrue);
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

        final converted = await prepare(inputPath);
        addTearDown(converted.dispose);

        final secondPass = await prepare(converted.path);

        expect(secondPass.isTemporary, isFalse);
        expect(secondPass.path, equals(converted.path));
      },
    );

    test('returns the input path unchanged for 16 kHz mono PCM16', () async {
      final inputPath = writeWav(
        'mono16k.wav',
        buildWav(channels: [List.filled(1600, 0.25)], sampleRate: 16000),
      );

      final prepared = await prepare(inputPath);

      expect(prepared.isTemporary, isFalse);
      expect(prepared.path, equals(inputPath));
      // dispose on a passthrough result is a safe no-op.
      await prepared.dispose();
      expect(File(inputPath).existsSync(), isTrue);
    });

    test(
      're-encodes 16 kHz mono EXTENSIBLE PCM16 instead of passthrough',
      () async {
        // The audio is already 16 kHz mono 16-bit PCM, but wrapped in a
        // WAVE_FORMAT_EXTENSIBLE fmt chunk the minimal native Android reader
        // rejects, so it must be rewritten to a plain-PCM fmt chunk rather than
        // passed through unchanged.
        final inputPath = writeWav(
          'mono16k_extensible.wav',
          buildWav(
            channels: [List.filled(1600, 0.25)],
            sampleRate: 16000,
            extensible: true,
          ),
        );

        final prepared = await prepare(inputPath);
        addTearDown(prepared.dispose);

        expect(prepared.isTemporary, isTrue);
        final decoded = DecodedWav.parse(File(prepared.path).readAsBytesSync());
        expect(decoded.formatCode, equals(1));
        expect(decoded.channels, equals(1));
        expect(decoded.sampleRate, equals(16000));
      },
    );

    test('converts 32-bit float samples to 16-bit integers', () async {
      final inputPath = writeWav(
        'float.wav',
        buildWav(
          channels: [List.filled(1600, 0.5)],
          sampleRate: 16000,
          float32: true,
        ),
      );

      final prepared = await prepare(inputPath);
      addTearDown(prepared.dispose);

      expect(prepared.isTemporary, isTrue);
      final decoded = DecodedWav.parse(File(prepared.path).readAsBytesSync());
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

      final prepared = await prepare(inputPath);
      addTearDown(prepared.dispose);

      final decoded = DecodedWav.parse(File(prepared.path).readAsBytesSync());
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

      final prepared = await prepare(inputPath);
      addTearDown(prepared.dispose);

      final decoded = DecodedWav.parse(File(prepared.path).readAsBytesSync());
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

      final prepared = await prepare(inputPath);
      addTearDown(prepared.dispose);

      final decoded = DecodedWav.parse(File(prepared.path).readAsBytesSync());
      expect(decoded.channels, equals(1));
      expect(decoded.sampleRate, equals(16000));
    });

    group('cleanup and isolation', () {
      test('dispose removes the converted temp file', () async {
        final inputPath = writeWav(
          'cleanup.wav',
          buildWav(
            channels: [List.filled(4410, 0.5), List.filled(4410, -0.25)],
          ),
        );

        final prepared = await prepare(inputPath);
        expect(File(prepared.path).existsSync(), isTrue);

        await prepared.dispose();
        expect(File(prepared.path).existsSync(), isFalse);
        // dispose is idempotent.
        await prepared.dispose();
      });

      test(
        'runs the conversion in a worker isolate, not the caller',
        () async {
          final inputPath = writeWav(
            'isolated.wav',
            buildWav(
              channels: [List.filled(4410, 0.5), List.filled(4410, -0.25)],
            ),
          );

          final prepared = await prepare(inputPath);
          addTearDown(prepared.dispose);

          expect(prepared.isTemporary, isTrue);
          // The flag the conversion sets in the worker isolate is invisible
          // here, so it stays false — proving the heavy work left the caller
          // isolate. If conversion ever moves back on-caller this flips true.
          expect(WavPreprocessor.debugConversionRanInCallerIsolate, isFalse);

          // Control: invoked directly, the same routine sets the flag in the
          // current isolate, so the assertion above fails loudly on regression.
          WavPreprocessor.debugConversionRanInCallerIsolate = false;
          await WavPreprocessor.runPreparation(
            inputPath,
            '${tempDir.path}/direct.wav',
          );
          expect(WavPreprocessor.debugConversionRanInCallerIsolate, isTrue);
        },
      );

      test(
        'gives concurrent conversions of one source distinct temp files',
        () async {
          final inputPath = writeWav(
            'shared.wav',
            buildWav(
              channels: [List.filled(4410, 0.5), List.filled(4410, -0.25)],
            ),
          );

          final results = await Future.wait([
            prepare(inputPath),
            prepare(inputPath),
          ]);
          addTearDown(() => Future.wait(results.map((r) => r.dispose())));

          expect(results[0].path, isNot(equals(results[1].path)));
          expect(File(results[0].path).existsSync(), isTrue);
          expect(File(results[1].path).existsSync(), isTrue);
          expect(File(inputPath).existsSync(), isTrue);
        },
      );
    });

    group('rejects out-of-bounds input', () {
      test('throws for a sample rate below the supported floor', () {
        final inputPath = writeWav(
          'low_rate.wav',
          buildWav(channels: [List.filled(441, 0.5)], sampleRate: 2000),
        );

        expect(
          () => prepare(inputPath),
          throwsA(isA<UnsupportedAudioFormatException>()),
        );
      });

      test('throws for a sample rate above the supported ceiling', () {
        final inputPath = writeWav(
          'high_rate.wav',
          buildWav(channels: [List.filled(441, 0.5)], sampleRate: 200000),
        );

        expect(
          () => prepare(inputPath),
          throwsA(isA<UnsupportedAudioFormatException>()),
        );
      });

      test('rejects a clip that converts beyond the frame limit', () {
        final inputPath = writeWav(
          'long.wav',
          buildWav(
            channels: [List.filled(4410, 0.5), List.filled(4410, -0.25)],
          ),
        );

        // 4410 frames at 44.1 kHz convert to 1600 frames at 16 kHz; a 100-frame
        // cap forces the too-long rejection with a small fixture.
        expect(
          () => WavPreprocessor.runPreparation(
            inputPath,
            '${tempDir.path}/out.wav',
            maxConvertedFrames: 100,
          ),
          throwsA(isA<UnsupportedAudioFormatException>()),
        );
      });

      test('rejects an oversized/sparse data chunk before reading it', () {
        // A tiny file whose data chunk header lies about being ~2 GiB: the
        // bounded metadata parse must reject on the declared size rather than
        // trust it and allocate. Regression for reading the whole payload
        // before the size check.
        final inputPath = writeWav(
          'sparse.wav',
          buildWav(
            channels: [List.filled(441, 0.5), List.filled(441, -0.25)],
            declaredDataSizeOverride: 0x7FFFFFF0,
          ),
        );

        expect(
          () => prepare(inputPath),
          throwsA(isA<UnsupportedAudioFormatException>()),
        );
      });

      test('bounds a canonical clip instead of passing it through', () {
        // A canonical 16 kHz mono file would passthrough zero-copy, but the
        // size/duration limits must still apply — otherwise a large or long
        // canonical clip is streamed to the recognizer unbounded. A low frame
        // cap forces rejection before the passthrough return.
        final inputPath = writeWav(
          'canonical_long.wav',
          buildWav(channels: [List.filled(1600, 0.25)], sampleRate: 16000),
        );

        expect(
          () => WavPreprocessor.runPreparation(
            inputPath,
            '${tempDir.path}/out.wav',
            maxConvertedFrames: 100,
          ),
          throwsA(isA<UnsupportedAudioFormatException>()),
        );
      });
    });

    group('maps I/O failures to typed exceptions', () {
      test('read failure throws $TranscriptionFailedException', () {
        // Opening a missing input fails; runPreparation skips the facade's
        // existence guard, so this exercises the read path's mapping directly.
        expect(
          () => WavPreprocessor.runPreparation(
            '${tempDir.path}/does_not_exist.wav',
            '${tempDir.path}/out.wav',
          ),
          throwsA(isA<TranscriptionFailedException>()),
        );
      });

      test(
        'temp directory creation failure throws $TranscriptionFailedException',
        () async {
          WavPreprocessor.debugCreateWorkDirectoryOverride = (_) async =>
              throw const FileSystemException('temp unavailable');
          final inputPath = writeWav(
            'src.wav',
            buildWav(
              channels: [List.filled(441, 0.5), List.filled(441, -0.25)],
            ),
          );

          await expectLater(
            prepare(inputPath),
            throwsA(isA<TranscriptionFailedException>()),
          );
        },
      );

      test('write failure throws $TranscriptionFailedException', () {
        final inputPath = writeWav(
          'src.wav',
          buildWav(
            channels: [List.filled(441, 0.5), List.filled(441, -0.25)],
          ),
        );

        expect(
          () => WavPreprocessor.runPreparation(
            inputPath,
            '${tempDir.path}/missing_dir/out.wav',
          ),
          throwsA(isA<TranscriptionFailedException>()),
        );
      });
    });

    group('rejects malformed WAV headers', () {
      test('throws $UnsupportedAudioFormatException for a non-RIFF file', () {
        final inputPath = writeWav('not_a_wav.wav', 'hello world'.codeUnits);

        expect(
          () => prepare(inputPath),
          throwsA(isA<UnsupportedAudioFormatException>()),
        );
      });

      test('throws $UnsupportedAudioFormatException for 8-bit PCM', () {
        final inputPath = writeWav(
          'pcm8.wav',
          buildWav(channels: [List.filled(441, 0.5)], bitsPerSample: 8),
        );

        expect(
          () => prepare(inputPath),
          throwsA(isA<UnsupportedAudioFormatException>()),
        );
      });

      test('throws $UnsupportedAudioFormatException for unsupported codes', () {
        final inputPath = writeWav(
          'alaw.wav',
          buildWav(channels: [List.filled(441, 0.5)], formatCode: 6),
        );

        expect(
          () => prepare(inputPath),
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
          () => prepare(inputPath),
          throwsA(isA<UnsupportedAudioFormatException>()),
        );
      });

      test('throws when the data chunk is missing', () {
        final inputPath = writeWav(
          'no_data.wav',
          buildWav(channels: [List.filled(441, 0.5)], omitDataChunk: true),
        );

        expect(
          () => prepare(inputPath),
          throwsA(isA<UnsupportedAudioFormatException>()),
        );
      });

      test('throws when the fmt chunk is missing', () {
        final inputPath = writeWav(
          'no_fmt.wav',
          buildWav(channels: [List.filled(441, 0.5)], omitFmtChunk: true),
        );

        expect(
          () => prepare(inputPath),
          throwsA(isA<UnsupportedAudioFormatException>()),
        );
      });

      test('throws $AudioFileNotFoundException for a missing input', () {
        expect(
          () => prepare('${tempDir.path}/missing.wav'),
          throwsA(isA<AudioFileNotFoundException>()),
        );
      });
    });
  });
}
