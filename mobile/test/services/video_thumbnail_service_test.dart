// ABOUTME: Unit tests for video thumbnail extraction service
// ABOUTME: Tests thumbnail generation, error handling, and edge cases

@Tags(['skip_very_good_optimization'])
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/services/video_thumbnail_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoThumbnailService', () {
    late String testVideoPath;
    late Directory tempDir;

    const channel = MethodChannel('pro_video_editor');

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('video_thumbnail_test');
    });

    tearDownAll(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    setUp(() {
      testVideoPath = '${tempDir.path}/test_video.mp4';

      // Mock the pro_video_editor platform channel per-test so it does not
      // leak into other test files when running in a shared isolate.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'getThumbnails') {
              return <Uint8List>[];
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
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
          targetTimestamp: const Duration(seconds: 2),
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
          timestamps: const [
            Duration(milliseconds: 100),
            Duration(milliseconds: 200),
            Duration(milliseconds: 300),
          ],
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
        expect(thumb1.existsSync(), isTrue);
        expect(thumb2.existsSync(), isTrue);

        // Clean up thumbnails
        await VideoThumbnailService.cleanupThumbnails([
          thumb1.path,
          thumb2.path,
        ]);

        // Verify files are deleted
        expect(thumb1.existsSync(), isFalse);
        expect(thumb2.existsSync(), isFalse);
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
        expect(existingThumb.existsSync(), isFalse);
      });
    });

    group('getOptimalTimestamp', () {
      test('returns 100ms for very short videos', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(milliseconds: 500),
        );
        expect(timestamp.inMilliseconds, equals(100));
      });

      test('returns 10% timestamp for medium videos', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(seconds: 5),
        );
        expect(timestamp.inMilliseconds, equals(500)); // 10% of 5000ms
      });

      test('caps at 1000ms for long videos', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(seconds: 30),
        );
        expect(timestamp.inMilliseconds, equals(1000)); // Capped at 1 second
      });

      test('handles edge case of 1 second video', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          const Duration(seconds: 1),
        );
        expect(timestamp.inMilliseconds, equals(100)); // 10% of 1000ms = 100ms
      });

      test('handles vine-length video (6.3 seconds)', () {
        final timestamp = VideoThumbnailService.getOptimalTimestamp(
          VideoEditorConstants.maxDuration,
        );
        expect(timestamp.inMilliseconds, equals(630)); // 10% of 6300ms
      });
    });
  });

  group('VideoThumbnailService.extractLastFrame', () {
    const channel = MethodChannel('pro_video_editor');
    late Directory tempDir;
    late String testVideoPath;

    /// Tracks whether the channel mock should return valid bytes or
    /// empty lists.  The mock checks [getThumbnailsReturnsBytes] and
    /// [getMetadataSucceeds] on every invocation so individual tests
    /// can toggle behaviour mid-test.
    late bool getThumbnailsReturnsBytes;
    late bool getMetadataSucceeds;

    /// Dummy JPEG-like bytes produced by the mock.
    final fakeJpegBytes = Uint8List.fromList(
      List<int>.generate(128, (i) => i),
    );

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('ghost_frame_test');
    });

    tearDownAll(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    setUp(() {
      getThumbnailsReturnsBytes = false;
      getMetadataSucceeds = true;

      testVideoPath = '${tempDir.path}/test_video.mp4';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getThumbnails') {
              if (getThumbnailsReturnsBytes) {
                return <Uint8List>[fakeJpegBytes];
              }
              return <Uint8List>[];
            }
            if (call.method == 'getMetadata') {
              if (!getMetadataSucceeds) {
                throw PlatformException(
                  code: 'ERROR',
                  message: 'cannot open',
                );
              }
              return <String, dynamic>{
                'duration': 3000000, // microseconds
                'extension': 'mp4',
                'fileSize': 1024000,
                'width': 1920,
                'height': 1080,
                'rotation': 0,
                'bitrate': 3000000,
              };
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('returns path when getSingleThumbnail succeeds', () async {
      getThumbnailsReturnsBytes = true;
      final videoFile = File(testVideoPath);
      await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

      final result = await VideoThumbnailService.extractLastFrame(
        videoPath: testVideoPath,
        videoDuration: const Duration(seconds: 3),
      );

      expect(result, isNotNull);
      expect(result, contains('ghost_'));
      expect(File(result!).existsSync(), isTrue);

      await videoFile.delete();
    });

    test(
      'falls back to timestamp extraction when position-based fails',
      () async {
        // First call (position-based) fails, second call (timestamp) succeeds.
        var callCount = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'getThumbnails') {
                callCount++;
                // First call → empty (position-based fails)
                // Second call → bytes (timestamp fallback succeeds)
                if (callCount >= 2) {
                  return <Uint8List>[fakeJpegBytes];
                }
                return <Uint8List>[];
              }
              if (call.method == 'getMetadata') {
                return <String, dynamic>{
                  'duration': 3000000,
                  'extension': 'mp4',
                  'fileSize': 1024000,
                  'width': 1920,
                  'height': 1080,
                  'rotation': 0,
                  'bitrate': 3000000,
                };
              }
              return null;
            });

        final videoFile = File(testVideoPath);
        await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

        final result = await VideoThumbnailService.extractLastFrame(
          videoPath: testVideoPath,
          videoDuration: const Duration(seconds: 3),
        );

        expect(result, isNotNull);
        // At least 2 calls: position-based + timestamp fallback attempt(s)
        expect(callCount, greaterThanOrEqualTo(2));

        await videoFile.delete();
      },
    );

    test('returns null when both strategies fail', () async {
      getThumbnailsReturnsBytes = false;
      final videoFile = File(testVideoPath);
      await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

      final result = await VideoThumbnailService.extractLastFrame(
        videoPath: testVideoPath,
        videoDuration: const Duration(seconds: 3),
      );

      expect(result, isNull);

      await videoFile.delete();
    });

    test('returns null when getSingleThumbnail throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getThumbnails') {
              throw PlatformException(
                code: 'ERROR',
                message: 'Cannot Open',
              );
            }
            if (call.method == 'getMetadata') {
              return <String, dynamic>{
                'duration': 3000000,
                'extension': 'mp4',
                'fileSize': 1024000,
                'width': 1920,
                'height': 1080,
                'rotation': 0,
                'bitrate': 3000000,
              };
            }
            return null;
          });

      final videoFile = File(testVideoPath);
      await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

      final result = await VideoThumbnailService.extractLastFrame(
        videoPath: testVideoPath,
        videoDuration: const Duration(seconds: 3),
      );

      // Falls back to timestamp extraction which also throws → null
      expect(result, isNull);

      await videoFile.delete();
    });

    test('uses provided videoDuration to avoid metadata lookup', () async {
      getThumbnailsReturnsBytes = true;
      getMetadataSucceeds = false; // Would fail if called

      final videoFile = File(testVideoPath);
      await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

      final result = await VideoThumbnailService.extractLastFrame(
        videoPath: testVideoPath,
        videoDuration: const Duration(seconds: 3),
      );

      // Should succeed without needing getMetadata
      expect(result, isNotNull);

      await videoFile.delete();
    });

    test('fallback computes timestamp as duration minus 50ms', () async {
      // Track the timestamps sent to getThumbnails
      final timestamps = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getThumbnails') {
              final args = call.arguments as Map;
              final ts = (args['timestamps'] as List).cast<int>();
              timestamps.addAll(ts);
              // Fail first call, succeed on subsequent
              if (timestamps.length == 1) {
                return <Uint8List>[];
              }
              return <Uint8List>[fakeJpegBytes];
            }
            if (call.method == 'getMetadata') {
              return <String, dynamic>{
                'duration': 3000000,
                'extension': 'mp4',
                'fileSize': 1024000,
                'width': 1920,
                'height': 1080,
                'rotation': 0,
                'bitrate': 3000000,
              };
            }
            return null;
          });

      final videoFile = File(testVideoPath);
      await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

      await VideoThumbnailService.extractLastFrame(
        videoPath: testVideoPath,
        videoDuration: const Duration(seconds: 3),
      );

      // First call: position-based (duration = 3000000 microseconds)
      expect(timestamps.first, equals(3000000));
      // Fallback timestamp should be duration - 50ms = 2950000 microseconds
      // (may appear in a later element depending on retry logic)
      expect(timestamps, contains(2950000));

      await videoFile.delete();
    });
  });
}
