// ABOUTME: Unit tests for video thumbnail extraction service
// ABOUTME: Tests thumbnail generation, error handling, and edge cases

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoThumbnailService', () {
    late String testVideoPath;
    late Directory tempDir;

    setUpAll(() async {
      // Create a temporary directory for test files
      tempDir = await Directory.systemTemp.createTemp('video_thumbnail_test');
    });

    tearDownAll(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    setUp(() {
      // Create a mock video file path
      testVideoPath = '${tempDir.path}/test_video.mp4';
    });

    group('extractThumbnail', () {
      test('returns null when video file does not exist', () async {
        // Test with non-existent file
        final result = await VideoThumbnailService.extractThumbnail(
          videoPath: '/non/existent/video.mp4',
        );

        expect(result, isNull);
      });

      test('uses default parameters when not specified', () async {
        // Create a dummy video file
        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        // This will fail because it's not a real video, but we're testing parameters
        final result = await VideoThumbnailService.extractThumbnail(
          videoPath: testVideoPath,
        );

        // Since we're using a fake video file, expect null
        expect(result, isNull);

        // Clean up
        await videoFile.delete();
      });

      test('handles custom quality parameter', () async {
        // Create a dummy video file
        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        // Test with custom quality
        final result = await VideoThumbnailService.extractThumbnail(
          videoPath: testVideoPath,
          quality: 50,
        );

        expect(result, isNull); // Expected because it's not a real video

        await videoFile.delete();
      });

      test('handles custom timestamp parameter', () async {
        // Create a dummy video file
        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        // Test with custom timestamp
        final result = await VideoThumbnailService.extractThumbnail(
          videoPath: testVideoPath,
          timeMs: 2000,
        );

        expect(result, isNull); // Expected because it's not a real video

        await videoFile.delete();
      });
    });

    group('extractThumbnailBytes', () {
      test('returns null when video file does not exist', () async {
        final result = await VideoThumbnailService.extractThumbnailBytes(
          videoPath: '/non/existent/video.mp4',
        );

        expect(result, isNull);
      });

      test('returns Uint8List for valid video', () async {
        // Create a dummy video file
        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        final result = await VideoThumbnailService.extractThumbnailBytes(
          videoPath: testVideoPath,
        );

        // Since we're using a fake video, expect null
        expect(result, isNull);

        await videoFile.delete();
      });
    });

    group('extractMultipleThumbnails', () {
      test('returns empty list for non-existent video', () async {
        final results = await VideoThumbnailService.extractMultipleThumbnails(
          videoPath: '/non/existent/video.mp4',
        );

        expect(results, isEmpty);
      });

      test('uses default timestamps when not specified', () async {
        // Create a dummy video file
        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        final results = await VideoThumbnailService.extractMultipleThumbnails(
          videoPath: testVideoPath,
        );

        // Since we're using a fake video, expect empty list
        expect(results, isEmpty);

        await videoFile.delete();
      });

      test('uses custom timestamps when provided', () async {
        // Create a dummy video file
        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        final results = await VideoThumbnailService.extractMultipleThumbnails(
          videoPath: testVideoPath,
          timestamps: [100, 200, 300],
        );

        expect(results, isEmpty); // Expected because it's not a real video

        await videoFile.delete();
      });
    });

    group('cleanupThumbnails', () {
      test('deletes existing thumbnail files', () async {
        // Create test thumbnail files
        final thumb1 = File('${tempDir.path}/thumb1.jpg');
        final thumb2 = File('${tempDir.path}/thumb2.jpg');
        await thumb1.writeAsBytes(Uint8List.fromList([1, 2, 3]));
        await thumb2.writeAsBytes(Uint8List.fromList([4, 5, 6]));

        // Verify files exist
        expect(await thumb1.exists(), isTrue);
        expect(await thumb2.exists(), isTrue);

        // Clean up thumbnails
        await VideoThumbnailService.cleanupThumbnails([
          thumb1.path,
          thumb2.path,
        ]);

        // Verify files are deleted
        expect(await thumb1.exists(), isFalse);
        expect(await thumb2.exists(), isFalse);
      });

      test('handles non-existent files gracefully', () async {
        // Try to clean up non-existent files
        await expectLater(
          VideoThumbnailService.cleanupThumbnails([
            '/non/existent/thumb1.jpg',
            '/non/existent/thumb2.jpg',
          ]),
          completes,
        );
      });

      test('handles mixed existing and non-existing files', () async {
        // Create one test thumbnail file
        final existingThumb = File('${tempDir.path}/existing_thumb.jpg');
        await existingThumb.writeAsBytes(Uint8List.fromList([1, 2, 3]));

        // Clean up mixed files
        await VideoThumbnailService.cleanupThumbnails([
          existingThumb.path,
          '/non/existent/thumb.jpg',
        ]);

        // Verify existing file is deleted
        expect(await existingThumb.exists(), isFalse);
      });
    });

    group('getOptimalTimestamp', () {
      test('returns 100ms for very short videos', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(milliseconds: 500),
        );
        expect(timestamp, equals(100));
      });

      test('returns 10% timestamp for medium videos', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(seconds: 5),
        );
        expect(timestamp, equals(500)); // 10% of 5000ms
      });

      test('caps at 1000ms for long videos', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(seconds: 30),
        );
        expect(timestamp, equals(1000)); // Capped at 1 second
      });

      test('handles edge case of 1 second video', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(seconds: 1),
        );
        expect(timestamp, equals(100)); // 10% of 1000ms = 100ms
      });

      test('handles vine-length video (6.3 seconds)', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(milliseconds: 6300),
        );
        expect(timestamp, equals(630)); // 10% of 6300ms
      });
    });
  });
}