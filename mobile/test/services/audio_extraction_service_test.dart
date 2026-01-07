// ABOUTME: Unit tests for AudioExtractionService
// ABOUTME: Tests audio extraction result model, exceptions, and cleanup logic

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/audio_extraction_service.dart';

void main() {
  group('AudioExtractionResult', () {
    test('creates result with all required fields', () {
      const result = AudioExtractionResult(
        audioFilePath: '/path/to/audio.aac',
        duration: 6.5,
        fileSize: 102400,
        sha256Hash: 'abc123def456',
        mimeType: 'audio/aac',
      );

      expect(result.audioFilePath, equals('/path/to/audio.aac'));
      expect(result.duration, equals(6.5));
      expect(result.fileSize, equals(102400));
      expect(result.sha256Hash, equals('abc123def456'));
      expect(result.mimeType, equals('audio/aac'));
    });

    test('toString provides human-readable output', () {
      const result = AudioExtractionResult(
        audioFilePath: '/path/to/audio.aac',
        duration: 6.5,
        fileSize: 102400,
        sha256Hash: 'abc123def456',
        mimeType: 'audio/aac',
      );

      final str = result.toString();

      expect(str, contains('6.50s'));
      expect(str, contains('100.00KB'));
      expect(str, contains('audio/aac'));
    });

    test('fileSize displays correctly in KB', () {
      const result = AudioExtractionResult(
        audioFilePath: '/path/to/audio.aac',
        duration: 3.0,
        fileSize: 51200, // 50 KB
        sha256Hash: 'hash',
        mimeType: 'audio/aac',
      );

      final str = result.toString();
      expect(str, contains('50.00KB'));
    });
  });

  group('AudioExtractionException', () {
    test('creates exception with message only', () {
      const exception = AudioExtractionException('Test error');

      expect(exception.message, equals('Test error'));
      expect(exception.cause, isNull);
      expect(
        exception.toString(),
        equals('AudioExtractionException: Test error'),
      );
    });

    test('creates exception with message and cause', () {
      final cause = Exception('Underlying error');
      final exception = AudioExtractionException('Test error', cause: cause);

      expect(exception.message, equals('Test error'));
      expect(exception.cause, equals(cause));
      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('caused by:'));
    });

    test('toString includes cause when present', () {
      const exception = AudioExtractionException(
        'FFmpeg failed',
        cause: 'Error: No audio stream found',
      );

      final str = exception.toString();
      expect(str, contains('FFmpeg failed'));
      expect(str, contains('caused by:'));
      expect(str, contains('No audio stream found'));
    });
  });

  group('AudioExtractionService', () {
    late AudioExtractionService service;

    setUp(() {
      service = AudioExtractionService();
    });

    test('throws exception when video file does not exist', () async {
      const nonExistentPath = '/path/that/does/not/exist/video.mp4';

      expect(
        () => service.extractAudio(nonExistentPath),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Video file not found',
          ),
        ),
      );
    });

    test('cleanupTemporaryFiles handles empty list', () async {
      // Should not throw
      await service.cleanupTemporaryFiles([]);
    });

    test(
      'cleanupTemporaryFiles handles non-existent files gracefully',
      () async {
        // Should not throw even for non-existent files
        await service.cleanupTemporaryFiles([
          '/non/existent/file1.aac',
          '/non/existent/file2.aac',
        ]);
      },
    );

    test('cleanupAudioFile delegates to cleanupTemporaryFiles', () async {
      // Should not throw for non-existent file
      await service.cleanupAudioFile('/non/existent/audio.aac');
    });

    group('with temporary files', () {
      late Directory tempDir;
      late File tempFile;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('audio_test_');
        tempFile = File('${tempDir.path}/test_audio.aac');
        await tempFile.writeAsString('test content');
      });

      tearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {
          // Ignore cleanup errors in teardown
        }
      });

      test('cleanupTemporaryFiles deletes existing files', () async {
        expect(await tempFile.exists(), isTrue);

        await service.cleanupTemporaryFiles([tempFile.path]);

        expect(await tempFile.exists(), isFalse);
      });

      test('cleanupAudioFile deletes single file', () async {
        expect(await tempFile.exists(), isTrue);

        await service.cleanupAudioFile(tempFile.path);

        expect(await tempFile.exists(), isFalse);
      });
    });
  });

  group('AudioExtractionService integration', () {
    // These tests require FFmpeg and actual video files
    // They are skipped by default but can be enabled for local testing

    test(
      'extracts audio from video file',
      () async {
        // This test requires a real video file with audio
        // Skip in CI, only run locally when test video is available
        final testVideoPath = 'test/fixtures/test_video_with_audio.mp4';
        final testVideo = File(testVideoPath);

        if (!testVideo.existsSync()) {
          // Skip if test video is not available
          return;
        }

        final service = AudioExtractionService();

        final result = await service.extractAudio(testVideoPath);

        expect(result.audioFilePath, endsWith('.aac'));
        expect(result.duration, greaterThan(0));
        expect(result.fileSize, greaterThan(0));
        expect(result.sha256Hash, isNotEmpty);
        expect(result.sha256Hash.length, equals(64)); // SHA-256 hex length
        expect(result.mimeType, equals('audio/aac'));

        // Cleanup
        await service.cleanupAudioFile(result.audioFilePath);
      },
      skip: 'Requires test video file with audio track',
    );

    test(
      'throws exception for video without audio',
      () async {
        // This test requires a video file without audio
        final testVideoPath = 'test/fixtures/test_video_no_audio.mp4';
        final testVideo = File(testVideoPath);

        if (!testVideo.existsSync()) {
          return;
        }

        final service = AudioExtractionService();

        expect(
          () => service.extractAudio(testVideoPath),
          throwsA(
            isA<AudioExtractionException>().having(
              (e) => e.message,
              'message',
              'Video has no audio track',
            ),
          ),
        );
      },
      skip: 'Requires test video file without audio track',
    );
  });
}
