// ABOUTME: Unit tests for AudioExtractionService
// ABOUTME: Tests audio extraction result model, exceptions, cleanup, and
// ABOUTME: core extraction path with ProVideoEditor mock.

@Tags(['skip_very_good_optimization'])
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Mock ProVideoEditor that provides controllable behavior for testing
/// the core audio extraction path.
class _MockProVideoEditor extends ProVideoEditor {
  bool hasAudio = true;
  Duration videoDuration = const Duration(seconds: 6);
  bool shouldThrowOnExtract = false;
  bool shouldThrowNoTrack = false;
  bool shouldThrowOnHasAudio = false;
  bool shouldThrowOnGetMetadata = false;

  @override
  void initializeStream() {
    // No-op for testing
  }

  @override
  Future<bool> hasAudioTrack(
    EditorVideo value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    if (shouldThrowOnHasAudio) throw Exception('hasAudioTrack failed');
    return hasAudio;
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    if (shouldThrowOnGetMetadata) throw Exception('getMetadata failed');
    return VideoMetadata(
      duration: videoDuration,
      extension: 'mp4',
      fileSize: 1024000,
      resolution: const Size(1920, 1080),
      rotation: 0,
      bitrate: 3000000,
    );
  }

  @override
  Future<String> extractAudioToFile(
    String filePath,
    AudioExtractConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    if (shouldThrowNoTrack) throw const AudioNoTrackException();
    if (shouldThrowOnExtract) throw Exception('extraction failed');
    // Create a small file to simulate extraction
    final file = File(filePath);
    await file.writeAsBytes([0x00, 0x01, 0x02, 0x03]);
    return filePath;
  }
}

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
      await expectLater(service.cleanupTemporaryFiles([]), completes);
    });

    test(
      'cleanupTemporaryFiles handles non-existent files gracefully',
      () async {
        await expectLater(
          service.cleanupTemporaryFiles([
            '/non/existent/file1.aac',
            '/non/existent/file2.aac',
          ]),
          completes,
        );
      },
    );

    test('cleanupAudioFile delegates to cleanupTemporaryFiles', () async {
      await expectLater(
        service.cleanupAudioFile('/non/existent/audio.aac'),
        completes,
      );
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
        expect(tempFile.existsSync(), isTrue);

        await service.cleanupTemporaryFiles([tempFile.path]);

        expect(tempFile.existsSync(), isFalse);
      });

      test('cleanupAudioFile deletes single file', () async {
        expect(tempFile.existsSync(), isTrue);

        await service.cleanupAudioFile(tempFile.path);

        expect(tempFile.existsSync(), isFalse);
      });
    });
  });

  group('AudioExtractionService with ProVideoEditor mock', () {
    late AudioExtractionService service;
    late _MockProVideoEditor mockEditor;
    late Directory tempDir;
    late File fakeVideoFile;

    setUp(() async {
      service = AudioExtractionService();
      mockEditor = _MockProVideoEditor();
      ProVideoEditor.instance = mockEditor;

      tempDir = await Directory.systemTemp.createTemp('extraction_test_');
      fakeVideoFile = File('${tempDir.path}/test_video.mp4');
      await fakeVideoFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Intentional no-op: ignore cleanup errors in teardown.
      }
    });

    test('extractAudio returns result when video has audio', () async {
      final result = await service.extractAudio(fakeVideoFile.path);

      expect(result.audioFilePath, endsWith('.aac'));
      expect(result.duration, equals(6));
      expect(result.fileSize, greaterThan(0));
      expect(result.sha256Hash, isNotEmpty);
      expect(result.sha256Hash.length, equals(64));
      expect(result.mimeType, equals('audio/m4a'));

      // Cleanup extraction output
      final outputFile = File(result.audioFilePath);
      if (outputFile.existsSync()) {
        await outputFile.delete();
      }
    });

    test('extractAudio throws when video has no audio track', () async {
      mockEditor.hasAudio = false;

      expect(
        () => service.extractAudio(fakeVideoFile.path),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Video has no audio track',
          ),
        ),
      );
    });

    test('extractAudio throws when hasAudioTrack check fails', () async {
      mockEditor.shouldThrowOnHasAudio = true;

      expect(
        () => service.extractAudio(fakeVideoFile.path),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Video has no audio track',
          ),
        ),
      );
    });

    test('extractAudio throws when getMetadata fails', () async {
      mockEditor.shouldThrowOnGetMetadata = true;

      expect(
        () => service.extractAudio(fakeVideoFile.path),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Could not determine audio duration',
          ),
        ),
      );
    });

    test('extractAudio throws when duration is zero', () async {
      mockEditor.videoDuration = Duration.zero;

      expect(
        () => service.extractAudio(fakeVideoFile.path),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Could not determine audio duration',
          ),
        ),
      );
    });

    test(
      'extractAudio handles AudioNoTrackException from extraction',
      () async {
        mockEditor.shouldThrowNoTrack = true;

        expect(
          () => service.extractAudio(fakeVideoFile.path),
          throwsA(
            isA<AudioExtractionException>().having(
              (e) => e.message,
              'message',
              'Video has no audio track',
            ),
          ),
        );
      },
    );

    test('extractAudio handles generic extraction failure', () async {
      mockEditor.shouldThrowOnExtract = true;

      expect(
        () => service.extractAudio(fakeVideoFile.path),
        throwsA(
          isA<AudioExtractionException>().having(
            (e) => e.message,
            'message',
            'Failed to extract audio',
          ),
        ),
      );
    });

    test('extractAudio uses correct duration from video metadata', () async {
      mockEditor.videoDuration = const Duration(seconds: 3, milliseconds: 500);

      final result = await service.extractAudio(fakeVideoFile.path);

      expect(result.duration, equals(3.5));

      // Cleanup extraction output
      final outputFile = File(result.audioFilePath);
      if (outputFile.existsSync()) {
        await outputFile.delete();
      }
    });
  });
}
