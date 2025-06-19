// ABOUTME: Performance regression tests for video processing pipeline
// ABOUTME: Ensures performance doesn't degrade with code changes and meets SLA requirements

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/services/gif_service.dart';
import 'package:nostrvine_app/services/camera_service.dart';
import '../helpers/test_video_files.dart';

void main() {
  group('Video Processing Performance Regression Tests', () {
    late GifService gifService;
    late CameraService cameraService;

    setUp(() {
      gifService = GifService();
      cameraService = CameraService();
    });

    tearDown(() {
      try {
        cameraService.dispose();
      } catch (e) {
        // May already be disposed
      }
    });

    group('GIF Processing Performance SLA', () {
      test('standard vine (30 frames, 640x480) should process under 1 second', () async {
        // ARRANGE: Standard vine recording
        final frames = TestVideoFiles.createVideoFrames(
          frameCount: 30,
          width: 640,
          height: 480,
          pattern: VideoTestPattern.gradient,
        );

        // ACT: Process with timing
        final stopwatch = Stopwatch()..start();
        
        final result = await gifService.createGifFromFrames(
          frames: frames,
          originalWidth: 640,
          originalHeight: 480,
          quality: GifQuality.medium,
        );
        
        stopwatch.stop();

        // ASSERT: Performance SLA
        expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 1000)),
               reason: 'Standard vine processing exceeded 1 second SLA');
        
        // ASSERT: Quality requirements
        expect(result.frameCount, equals(30));
        expect(result.gifBytes.isNotEmpty, isTrue);
        expect(result.compressionRatio, lessThan(1.0));

        print('✅ Standard vine: ${stopwatch.elapsedMilliseconds}ms, '
              '${result.fileSizeMB.toStringAsFixed(2)}MB output');
      });

      test('high quality processing should complete under 2 seconds', () async {
        // ARRANGE: High quality processing
        final frames = TestVideoFiles.createVideoFrames(
          frameCount: 30,
          width: 640,
          height: 480,
          pattern: VideoTestPattern.animated,
        );

        // ACT: Process with high quality
        final stopwatch = Stopwatch()..start();
        
        final result = await gifService.createGifFromFrames(
          frames: frames,
          originalWidth: 640,
          originalHeight: 480,
          quality: GifQuality.high,
        );
        
        stopwatch.stop();

        // ASSERT: Performance SLA for high quality
        expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 2000)),
               reason: 'High quality processing exceeded 2 second SLA');

        expect(result.frameCount, equals(30));
        expect(result.quality, GifQuality.high);

        print('✅ High quality: ${stopwatch.elapsedMilliseconds}ms, '
              '${result.fileSizeMB.toStringAsFixed(2)}MB output');
      });

      test('low quality processing should complete under 500ms', () async {
        // ARRANGE: Low quality for quick processing
        final frames = TestVideoFiles.createVideoFrames(
          frameCount: 30,
          width: 640,
          height: 480,
          pattern: VideoTestPattern.solid,
        );

        // ACT: Process with low quality
        final stopwatch = Stopwatch()..start();
        
        final result = await gifService.createGifFromFrames(
          frames: frames,
          originalWidth: 640,
          originalHeight: 480,
          quality: GifQuality.low,
        );
        
        stopwatch.stop();

        // ASSERT: Performance SLA for low quality
        expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)),
               reason: 'Low quality processing exceeded 500ms SLA');

        expect(result.frameCount, equals(30));
        expect(result.quality, GifQuality.low);

        print('✅ Low quality: ${stopwatch.elapsedMilliseconds}ms, '
              '${result.fileSizeMB.toStringAsFixed(2)}MB output');
      });

      test('thumbnail generation should complete under 200ms', () async {
        // ARRANGE: Frame for thumbnail
        final frames = TestVideoFiles.createVideoFrames(
          frameCount: 1,
          width: 640,
          height: 480,
          pattern: VideoTestPattern.gradient,
        );

        // ACT: Generate thumbnail with timing
        final stopwatch = Stopwatch()..start();
        
        final thumbnail = await gifService.generateThumbnail(
          frames: frames,
          originalWidth: 640,
          originalHeight: 480,
          thumbnailSize: 120,
        );
        
        stopwatch.stop();

        // ASSERT: Performance SLA for thumbnail
        expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 200)),
               reason: 'Thumbnail generation exceeded 200ms SLA');

        expect(thumbnail, isNotNull);
        expect(thumbnail!.isNotEmpty, isTrue);

        print('✅ Thumbnail: ${stopwatch.elapsedMilliseconds}ms, '
              '${thumbnail!.length} bytes output');
      });
    });

    group('Memory Usage Performance', () {
      test('should process 30 frames without excessive memory allocation', () async {
        // ARRANGE: Standard frame set
        final frames = TestVideoFiles.createVideoFrames(
          frameCount: 30,
          width: 640,
          height: 480,
          pattern: VideoTestPattern.gradient,
        );

        // Calculate expected memory usage
        final frameSize = frames.first.length;
        final totalInputMemory = frameSize * frames.length;
        final inputMemoryMB = totalInputMemory / (1024 * 1024);

        print('Input memory usage: ${inputMemoryMB.toStringAsFixed(2)}MB');

        // ACT: Process frames
        final result = await gifService.createGifFromFrames(
          frames: frames,
          originalWidth: 640,
          originalHeight: 480,
          quality: GifQuality.medium,
        );

        // ASSERT: Output should be compressed
        final outputMemoryMB = result.fileSizeMB;
        expect(outputMemoryMB, lessThan(inputMemoryMB * 0.8), // At least 20% compression
               reason: 'GIF compression should reduce memory usage significantly');

        print('✅ Memory efficiency: ${inputMemoryMB.toStringAsFixed(2)}MB → '
              '${outputMemoryMB.toStringAsFixed(2)}MB '
              '(${(result.compressionRatio * 100).toStringAsFixed(1)}% compression)');
      });

      test('should handle large frame counts efficiently', () async {
        // ARRANGE: Large frame count (simulating long recording)
        final frames = TestVideoFiles.createVideoFrames(
          frameCount: 150, // 30 seconds at 5fps
          width: 320,
          height: 240,
          pattern: VideoTestPattern.solid, // Simple pattern for predictable performance
        );

        final stopwatch = Stopwatch()..start();

        // ACT: Process large frame count
        final result = await gifService.createGifFromFrames(
          frames: frames,
          originalWidth: 320,
          originalHeight: 240,
          quality: GifQuality.low, // Use low quality for efficiency
        );

        stopwatch.stop();

        // ASSERT: Should complete in reasonable time even with many frames
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)),
               reason: 'Large frame count processing took too long');

        expect(result.frameCount, equals(150));
        expect(result.fileSizeMB, lessThan(10.0), // Should stay under 10MB
               reason: 'Large GIF output exceeded size expectations');

        print('✅ Large frame count: ${stopwatch.elapsedMilliseconds}ms for 150 frames, '
              '${result.fileSizeMB.toStringAsFixed(2)}MB output');
      });
    });

    group('Scaling Performance Tests', () {
      test('processing time should scale linearly with frame count', () async {
        final frameCounts = [10, 20, 30, 60];
        final processingTimes = <int, int>{};

        for (final frameCount in frameCounts) {
          final frames = TestVideoFiles.createVideoFrames(
            frameCount: frameCount,
            width: 320,
            height: 240,
            pattern: VideoTestPattern.solid,
          );

          final stopwatch = Stopwatch()..start();
          
          await gifService.createGifFromFrames(
            frames: frames,
            originalWidth: 320,
            originalHeight: 240,
            quality: GifQuality.low,
          );
          
          stopwatch.stop();
          processingTimes[frameCount] = stopwatch.elapsedMilliseconds;
        }

        // ASSERT: Processing time should scale reasonably with frame count
        final time10 = processingTimes[10]!;
        final time60 = processingTimes[60]!;
        
        // 60 frames shouldn't take more than 8x the time of 10 frames
        expect(time60, lessThan(time10 * 8),
               reason: 'Processing time scaling is worse than expected');

        print('Scaling performance:');
        processingTimes.forEach((frames, ms) {
          print('  $frames frames: ${ms}ms (${(ms / frames).toStringAsFixed(1)}ms/frame)');
        });
      });

      test('processing time should scale reasonably with resolution', () async {
        final resolutions = [
          {'width': 160, 'height': 120, 'name': '160x120'},
          {'width': 320, 'height': 240, 'name': '320x240'},
          {'width': 640, 'height': 480, 'name': '640x480'},
        ];
        
        final processingTimes = <String, int>{};

        for (final res in resolutions) {
          final frames = TestVideoFiles.createVideoFrames(
            frameCount: 30,
            width: res['width'] as int,
            height: res['height'] as int,
            pattern: VideoTestPattern.solid,
          );

          final stopwatch = Stopwatch()..start();
          
          await gifService.createGifFromFrames(
            frames: frames,
            originalWidth: res['width'] as int,
            originalHeight: res['height'] as int,
            quality: GifQuality.medium,
          );
          
          stopwatch.stop();
          processingTimes[res['name'] as String] = stopwatch.elapsedMilliseconds;
        }

        // ASSERT: Higher resolution should take more time, but not excessively
        final time160 = processingTimes['160x120']!;
        final time640 = processingTimes['640x480']!;
        
        expect(time640, greaterThan(time160),
               reason: 'Higher resolution should take more processing time');
        
        expect(time640, lessThan(time160 * 20),
               reason: 'Processing time should not scale exponentially with resolution');

        print('Resolution scaling performance:');
        processingTimes.forEach((resolution, ms) {
          print('  $resolution: ${ms}ms');
        });
      });
    });

    group('Concurrent Processing Performance', () {
      test('should handle multiple concurrent GIF processing requests', () async {
        // ARRANGE: Multiple processing requests
        final processingTasks = List.generate(3, (index) {
          final frames = TestVideoFiles.createVideoFrames(
            frameCount: 30,
            width: 320,
            height: 240,
            pattern: VideoTestPattern.values[index % VideoTestPattern.values.length],
          );
          
          return () => gifService.createGifFromFrames(
            frames: frames,
            originalWidth: 320,
            originalHeight: 240,
            quality: GifQuality.medium,
          );
        });

        // ACT: Execute concurrent processing
        final stopwatch = Stopwatch()..start();
        
        final results = await Future.wait(
          processingTasks.map((task) => task()),
        );
        
        stopwatch.stop();

        // ASSERT: All processing should complete successfully
        expect(results.length, equals(3));
        
        for (int i = 0; i < results.length; i++) {
          expect(results[i].frameCount, equals(30));
          expect(results[i].gifBytes.isNotEmpty, isTrue);
        }

        // Total time shouldn't be much more than single processing time
        // (allowing for some overhead but ensuring parallelization works)
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 4)),
               reason: 'Concurrent processing took too long - may not be parallelized properly');

        print('✅ Concurrent processing: ${stopwatch.elapsedMilliseconds}ms for 3 simultaneous tasks');
      });
    });

    group('Resource Cleanup Performance', () {
      test('should release resources promptly after processing', () async {
        // ARRANGE: Create large processing task
        final frames = TestVideoFiles.createVideoFrames(
          frameCount: 60,
          width: 640,
          height: 480,
          pattern: VideoTestPattern.animated,
        );

        // ACT: Process and measure
        final result = await gifService.createGifFromFrames(
          frames: frames,
          originalWidth: 640,
          originalHeight: 480,
          quality: GifQuality.medium,
        );

        // Force garbage collection to test cleanup
        // (Note: In Dart, we can't force GC, but we can at least verify the operation completed)
        
        // ASSERT: Processing completed successfully
        expect(result.frameCount, equals(60));
        expect(result.gifBytes.isNotEmpty, isTrue);

        // Verify we can immediately process another batch (tests resource cleanup)
        final frames2 = TestVideoFiles.createVideoFrames(
          frameCount: 30,
          width: 320,
          height: 240,
          pattern: VideoTestPattern.solid,
        );

        final result2 = await gifService.createGifFromFrames(
          frames: frames2,
          originalWidth: 320,
          originalHeight: 240,
          quality: GifQuality.medium,
        );

        expect(result2.frameCount, equals(30));
        expect(result2.gifBytes.isNotEmpty, isTrue);

        print('✅ Resource cleanup: Successfully processed sequential large tasks');
      });
    });

    group('Performance Regression Benchmarks', () {
      test('benchmark: standard vine processing baseline', () async {
        // This test establishes a baseline for standard processing
        // If this test starts failing in CI, it indicates a performance regression
        
        final frames = TestVideoFiles.createVideoFrames(
          frameCount: 30,
          width: 640,
          height: 480,
          pattern: VideoTestPattern.gradient,
        );

        final runs = <Duration>[];
        
        // Run multiple times to get stable measurement
        for (int i = 0; i < 5; i++) {
          final stopwatch = Stopwatch()..start();
          
          await gifService.createGifFromFrames(
            frames: frames,
            originalWidth: 640,
            originalHeight: 480,
            quality: GifQuality.medium,
          );
          
          stopwatch.stop();
          runs.add(stopwatch.elapsed);
        }

        // Calculate statistics
        final totalMs = runs.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
        final averageMs = totalMs / runs.length;
        final maxMs = runs.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
        final minMs = runs.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);

        print('Performance Baseline Results:');
        print('  Average: ${averageMs.toStringAsFixed(1)}ms');
        print('  Min: ${minMs}ms, Max: ${maxMs}ms');
        print('  Variation: ${(maxMs - minMs)}ms');

        // ASSERT: Performance should be consistent and within reasonable bounds
        expect(averageMs, lessThan(1000), // Average under 1 second
               reason: 'Performance regression detected - processing too slow');
        
        expect(maxMs - minMs, lessThan(500), // Variation under 500ms
               reason: 'Performance is too inconsistent');

        // Store this as a reference point for future regression testing
        print('📊 BENCHMARK: Standard vine processing = ${averageMs.toStringAsFixed(1)}ms average');
      });
    });
  });
}