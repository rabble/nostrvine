// ABOUTME: Tests for FFmpegEncoder utility verifying encoder selection and filter building
// ABOUTME: Ensures correct hardware/software fallback and platform-specific behavior

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/ffmpeg_encoder.dart';

void main() {
  group('FFmpegEncoder', () {
    group('platform detection', () {
      test('isApplePlatform returns correct value', () {
        // This will be true on macOS/iOS, false otherwise
        expect(
          FFmpegEncoder.isApplePlatform,
          equals(Platform.isIOS || Platform.isMacOS),
        );
      });

      test('isAndroid returns correct value', () {
        expect(FFmpegEncoder.isAndroid, equals(Platform.isAndroid));
      });
    });

    group('encoder args', () {
      test('getSoftwareEncoderArgs returns libx264 with ultrafast preset', () {
        final args = FFmpegEncoder.getSoftwareEncoderArgs();
        expect(args, contains('libx264'));
        expect(args, contains('ultrafast'));
        expect(args, contains('crf 23'));
      });

      test('getHardwareEncoderArgs returns platform-appropriate encoder', () {
        final args = FFmpegEncoder.getHardwareEncoderArgs();

        if (Platform.isIOS || Platform.isMacOS) {
          expect(args, contains('h264_videotoolbox'));
        } else if (Platform.isAndroid) {
          // Android uses software encoding due to MediaCodec issues with filter_complex
          expect(args, contains('libx264'));
        } else {
          // Other platforms fall back to software
          expect(args, contains('libx264'));
        }
      });
    });

    group('buildCommand', () {
      test('builds command with all parameters', () {
        final cmd = FFmpegEncoder.buildCommand(
          input: '/path/to/input.mp4',
          output: '/path/to/output.mp4',
          videoFilter: 'scale=720:1280',
          audioArgs: '-c:a aac',
          extraArgs: '-r 30',
          useHardwareEncoder: false,
          overwrite: true,
        );

        expect(cmd, contains('-y')); // overwrite flag
        expect(cmd, contains('-i "/path/to/input.mp4"'));
        expect(cmd, contains('-vf "scale=720:1280"'));
        expect(cmd, contains('libx264')); // software encoder
        expect(cmd, contains('-c:a aac'));
        expect(cmd, contains('-r 30'));
        expect(cmd, contains('"/path/to/output.mp4"'));
      });

      test('builds command without optional parameters', () {
        final cmd = FFmpegEncoder.buildCommand(
          input: '/path/to/input.mp4',
          output: '/path/to/output.mp4',
        );

        expect(cmd, contains('-y'));
        expect(cmd, contains('-i "/path/to/input.mp4"'));
        expect(cmd, contains('"/path/to/output.mp4"'));
        // Should not contain -vf if no filter provided
        expect(cmd, isNot(contains('-vf ""')));
      });

      test('respects overwrite flag', () {
        final cmdWithOverwrite = FFmpegEncoder.buildCommand(
          input: '/path/to/input.mp4',
          output: '/path/to/output.mp4',
          overwrite: true,
        );
        expect(cmdWithOverwrite, contains('-y'));

        final cmdWithoutOverwrite = FFmpegEncoder.buildCommand(
          input: '/path/to/input.mp4',
          output: '/path/to/output.mp4',
          overwrite: false,
        );
        expect(cmdWithoutOverwrite, isNot(contains('-y')));
      });
    });

    group('injectFormatFilter', () {
      test('returns existing filter unchanged', () {
        final result = FFmpegEncoder.injectFormatFilter('scale=720:1280');
        expect(result, equals('scale=720:1280'));
      });

      test('handles null filter', () {
        final result = FFmpegEncoder.injectFormatFilter(null);
        expect(result, isNull);
      });
    });
  });
}
