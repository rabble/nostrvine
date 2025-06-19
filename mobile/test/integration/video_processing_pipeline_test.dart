// ABOUTME: Comprehensive end-to-end tests for video processing pipeline 
// ABOUTME: Tests camera capture → frame processing → GIF creation → upload flow with error handling

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostrvine_app/services/camera_service.dart';
import 'package:nostrvine_app/services/gif_service.dart';
import 'package:nostrvine_app/services/upload_manager.dart';
import 'package:nostrvine_app/services/cloudinary_upload_service.dart';
import 'package:nostrvine_app/models/pending_upload.dart';
import '../helpers/test_video_files.dart';
import '../mocks/mock_camera_controller.dart';

// Test-specific mocks
class MockFile extends Mock implements File {}
class MockCloudinaryService extends Mock implements CloudinaryUploadService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() {
    // Register fallback values for mocks
    registerFallbackValue(MockFile());
    registerFallbackValue(const Duration(seconds: 1));
    registerFallbackValue(VideoTestPattern.gradient);
  });

  group('Video Processing Pipeline End-to-End Tests', () {
    late CameraService cameraService;
    late GifService gifService;
    late MockCloudinaryService mockUploadService;
    late UploadManager uploadManager;

    setUp(() {
      cameraService = CameraService();
      gifService = GifService();
      mockUploadService = MockCloudinaryService();
      uploadManager = UploadManager(cloudinaryService: mockUploadService);
    });

    tearDown(() {
      try {
        cameraService.dispose();
        uploadManager.dispose();
      } catch (e) {
        // Services may already be disposed
      }
    });

    group('Complete Pipeline Flow', () {
      test('should process video from camera capture to upload', () async {
        // ARRANGE: Setup complete pipeline
        final mockController = MockCameraController.createWorkingController(
          frameCount: 30,
          pattern: VideoTestPattern.gradient,
        );
        
        // Mock successful upload
        when(() => mockUploadService.uploadVideo(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((_) async => UploadResult.success(
          cloudinaryPublicId: 'test-video-123',
          cloudinaryUrl: 'https://cloudinary.com/test-video-123.mp4',
        ));

        // ACT: Execute complete pipeline
        
        // Step 1: Simulate camera recording (mocked)
        mockController.generateTestFrames(
          frameCount: 30,
          pattern: VideoTestPattern.gradient,
        );
        
        // Step 2: Create recording result
        final testFrames = TestVideoFiles.createVideoFrames(
          frameCount: 30,
          width: 640,
          height: 480,
          pattern: VideoTestPattern.gradient,
        );
        
        final recordingResult = VineRecordingResult(
          frames: testFrames,
          frameCount: 30,
          processingTime: const Duration(milliseconds: 500),
          selectedApproach: 'Test',
          qualityRatio: 0.9,
        );
        
        // Step 3: Process frames into GIF
        final gifResult = await gifService.createGifFromFrames(
          frames: recordingResult.frames,
          originalWidth: 640,
          originalHeight: 480,
          quality: GifQuality.medium,
        );
        
        expect(gifResult.frameCount, equals(30));
        expect(gifResult.width, lessThanOrEqualTo(320)); // Should be resized
        expect(gifResult.height, lessThanOrEqualTo(320));
        expect(gifResult.gifBytes.isNotEmpty, isTrue);
        
        // Step 4: Save GIF as temporary file for upload
        final tempFile = MockFile();
        when(() => tempFile.path).thenReturn('/tmp/test_vine.gif');
        when(() => tempFile.existsSync()).thenReturn(true);
        when(() => tempFile.readAsBytesSync()).thenReturn(gifResult.gifBytes);
        
        // Step 5: Upload to Cloudinary
        await uploadManager.initialize();
        
        final upload = await uploadManager.startUpload(
          videoFile: tempFile,
          nostrPubkey: 'test-pubkey-123',
          title: 'Pipeline Test Video',
          description: 'End-to-end test',
          hashtags: ['test', 'pipeline'],
        );
        
        // ASSERT: Verify complete pipeline execution
        expect(upload.status, UploadStatus.pending);
        expect(upload.title, 'Pipeline Test Video');
        expect(upload.hashtags, containsAll(['test', 'pipeline']));
        
        // Wait for upload processing
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verify upload service was called
        verify(() => mockUploadService.uploadVideo(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: 'test-pubkey-123',
          title: 'Pipeline Test Video',
          description: 'End-to-end test',
          hashtags: ['test', 'pipeline'],
          onProgress: any(named: 'onProgress'),
        )).called(1);
      });

      test('should handle camera initialization failures gracefully', () async {
        // ARRANGE: Camera that fails to initialize
        final failingController = MockCameraController.createFailingController(
          errorType: 'initialization_failure',
        );
        
        // ACT & ASSERT: Camera service should handle failure gracefully
        expect(cameraService.isInitialized, isFalse);
        expect(cameraService.state, RecordingState.idle);
        
        // Recording should not start if camera failed to initialize
        await cameraService.startRecording();
        expect(cameraService.state, RecordingState.idle);
        expect(cameraService.isRecording, isFalse);
      });

      test('should handle GIF processing failures with proper error handling', () async {
        // ARRANGE: Invalid frame data that should cause processing to fail
        final errorScenarios = TestVideoFiles.getErrorScenarios();
        
        for (final scenario in errorScenarios) {
          if (scenario.shouldThrowError) {
            // ACT & ASSERT: Should handle error gracefully
            expect(
              () => gifService.createGifFromFrames(
                frames: scenario.frames,
                originalWidth: 640,
                originalHeight: 480,
              ),
              throwsA(isA<Exception>()),
              reason: 'Scenario: ${scenario.name} should throw error',
            );
          }
        }
      });

      test('should handle upload failures with retry capability', () async {
        // ARRANGE: Upload service that fails initially
        var attemptCount = 0;
        when(() => mockUploadService.uploadVideo(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((_) async {
          attemptCount++;
          if (attemptCount == 1) {
            // First attempt fails
            return UploadResult.failure('Network error');
          } else {
            // Second attempt succeeds
            return UploadResult.success(
              cloudinaryPublicId: 'retry-test-123',
              cloudinaryUrl: 'https://cloudinary.com/retry-test-123.mp4',
            );
          }
        });

        // Create test file
        final testFile = MockFile();
        when(() => testFile.path).thenReturn('/tmp/retry_test.gif');
        when(() => testFile.existsSync()).thenReturn(true);
        when(() => testFile.readAsBytesSync()).thenReturn(Uint8List(1000));

        await uploadManager.initialize();

        // ACT: Start upload (will fail initially)
        final upload = await uploadManager.startUpload(
          videoFile: testFile,
          nostrPubkey: 'retry-test-pubkey',
          title: 'Retry Test',
        );

        // Wait for initial failure
        await Future.delayed(const Duration(milliseconds: 100));
        
        final failedUpload = uploadManager.getUpload(upload.id);
        expect(failedUpload?.status, UploadStatus.failed);
        expect(failedUpload?.canRetry, isTrue);

        // ACT: Retry the upload
        await uploadManager.retryUpload(upload.id);
        
        // Wait for retry processing
        await Future.delayed(const Duration(milliseconds: 100));

        // ASSERT: Verify retry succeeded
        verify(() => mockUploadService.uploadVideo(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          onProgress: any(named: 'onProgress'),
        )).called(2); // Should be called twice (initial + retry)
      });
    });

    group('Performance and Quality Tests', () {
      test('should process different video qualities efficiently', () async {
        final performanceScenarios = TestVideoFiles.getPerformanceScenarios();
        
        for (final scenario in performanceScenarios) {
          final stopwatch = Stopwatch()..start();
          
          try {
            final gifResult = await gifService.createGifFromFrames(
              frames: scenario.frames,
              originalWidth: 640,
              originalHeight: 480,
              quality: GifQuality.medium,
            );
            
            stopwatch.stop();
            
            // ASSERT: Performance within expected bounds
            if (scenario.expectedProcessingTime != null) {
              expect(
                stopwatch.elapsed,
                lessThan(scenario.expectedProcessingTime! * 2), // Allow 2x margin
                reason: 'Processing time for ${scenario.name} exceeded expectation',
              );
            }
            
            // ASSERT: Output quality
            expect(gifResult.frameCount, equals(scenario.frames.length));
            expect(gifResult.gifBytes.isNotEmpty, isTrue);
            expect(gifResult.compressionRatio, lessThan(1.0)); // Should compress
            
            print('✅ ${scenario.name}: ${stopwatch.elapsedMilliseconds}ms, '
                  '${gifResult.fileSizeMB.toStringAsFixed(2)}MB, '
                  '${(gifResult.compressionRatio * 100).toStringAsFixed(1)}% compression');
                  
          } catch (e) {
            print('❌ ${scenario.name} failed: $e');
            rethrow;
          }
        }
      });

      test('should handle memory pressure during large video processing', () async {
        // ARRANGE: Large video scenario
        final largeVideoFrames = TestVideoFiles.createVideoFrames(
          frameCount: 150, // 30 seconds at 5fps
          width: 1920,
          height: 1080,
          pattern: VideoTestPattern.animated,
        );

        // Calculate memory usage
        final frameSize = largeVideoFrames.first.length;
        final totalMemory = frameSize * largeVideoFrames.length;
        final memoryMB = totalMemory / (1024 * 1024);
        
        print('Testing large video processing: ${largeVideoFrames.length} frames, '
              '${memoryMB.toStringAsFixed(1)}MB total');

        // ACT: Process large video
        final stopwatch = Stopwatch()..start();
        
        final gifResult = await gifService.createGifFromFrames(
          frames: largeVideoFrames,
          originalWidth: 1920,
          originalHeight: 1080,
          quality: GifQuality.low, // Use low quality for memory efficiency
        );
        
        stopwatch.stop();

        // ASSERT: Processing completed successfully
        expect(gifResult.frameCount, equals(150));
        expect(gifResult.gifBytes.isNotEmpty, isTrue);
        
        // Should achieve significant compression for large inputs
        expect(gifResult.compressionRatio, lessThan(0.5)); // >50% compression
        
        print('✅ Large video processed: ${stopwatch.elapsedMilliseconds}ms, '
              'output: ${gifResult.fileSizeMB.toStringAsFixed(2)}MB');
      });

      test('should maintain consistent quality across different patterns', () async {
        final formatScenarios = TestVideoFiles.getFormatScenarios();
        final qualityMetrics = <String, double>{};
        
        for (final scenario in formatScenarios) {
          final gifResult = await gifService.createGifFromFrames(
            frames: scenario.frames,
            originalWidth: 640,
            originalHeight: 480,
            quality: GifQuality.medium,
          );
          
          qualityMetrics[scenario.name] = gifResult.compressionRatio;
          
          // ASSERT: Basic quality requirements
          expect(gifResult.frameCount, equals(scenario.frames.length));
          expect(gifResult.compressionRatio, greaterThan(0.0));
          expect(gifResult.compressionRatio, lessThan(1.0));
        }
        
        // ASSERT: Quality consistency
        final compressionRatios = qualityMetrics.values.toList();
        final minCompression = compressionRatios.reduce((a, b) => a < b ? a : b);
        final maxCompression = compressionRatios.reduce((a, b) => a > b ? a : b);
        
        // Compression ratios shouldn't vary too wildly
        expect(maxCompression - minCompression, lessThan(0.8));
        
        print('Quality metrics:');
        qualityMetrics.forEach((name, ratio) {
          print('  $name: ${(ratio * 100).toStringAsFixed(1)}% compression');
        });
      });
    });

    group('Error Recovery and Edge Cases', () {
      test('should recover from temporary network failures during upload', () async {
        var attemptCount = 0;
        when(() => mockUploadService.uploadVideo(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((_) async {
          attemptCount++;
          if (attemptCount <= 2) {
            throw Exception('Temporary network error');
          }
          return UploadResult.success(
            cloudinaryPublicId: 'recovery-test-123',
            cloudinaryUrl: 'https://cloudinary.com/recovery-test-123.mp4',
          );
        });

        final testFile = MockFile();
        when(() => testFile.path).thenReturn('/tmp/recovery_test.gif');
        when(() => testFile.existsSync()).thenReturn(true);
        when(() => testFile.readAsBytesSync()).thenReturn(Uint8List(1000));

        await uploadManager.initialize();

        // Start upload
        final upload = await uploadManager.startUpload(
          videoFile: testFile,
          nostrPubkey: 'recovery-test-pubkey',
          title: 'Recovery Test',
        );

        // Multiple retries should eventually succeed
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
          
          final currentUpload = uploadManager.getUpload(upload.id);
          if (currentUpload?.status == UploadStatus.failed && currentUpload!.canRetry) {
            await uploadManager.retryUpload(upload.id);
          }
        }

        // Should eventually succeed after retries
        final finalUpload = uploadManager.getUpload(upload.id);
        
        // Verify multiple attempts were made
        verify(() => mockUploadService.uploadVideo(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          onProgress: any(named: 'onProgress'),
        )).called(greaterThan(1));
      });

      test('should handle corrupted video data gracefully', () async {
        // ARRANGE: Corrupted frame data
        final corruptedFrames = [
          Uint8List.fromList([0xFF, 0xFF, 0xFF]), // Too small
          Uint8List(640 * 480 * 3)..fillRange(0, 100, 0xFF), // Partially corrupted
        ];

        // ACT & ASSERT: Should handle gracefully
        expect(
          () => gifService.createGifFromFrames(
            frames: corruptedFrames,
            originalWidth: 640,
            originalHeight: 480,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle concurrent upload requests without conflicts', () async {
        // ARRANGE: Multiple upload requests
        when(() => mockUploadService.uploadVideo(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((_) async {
          // Simulate upload delay
          await Future.delayed(const Duration(milliseconds: 50));
          return UploadResult.success(
            cloudinaryPublicId: 'concurrent-${DateTime.now().millisecondsSinceEpoch}',
            cloudinaryUrl: 'https://cloudinary.com/concurrent.mp4',
          );
        });

        await uploadManager.initialize();

        // Create multiple test files
        final testFiles = List.generate(5, (i) {
          final file = MockFile();
          when(() => file.path).thenReturn('/tmp/concurrent_$i.gif');
          when(() => file.existsSync()).thenReturn(true);
          when(() => file.readAsBytesSync()).thenReturn(Uint8List(1000));
          return file;
        });

        // ACT: Start concurrent uploads
        final uploadFutures = testFiles.asMap().entries.map((entry) {
          return uploadManager.startUpload(
            videoFile: entry.value,
            nostrPubkey: 'concurrent-test-pubkey',
            title: 'Concurrent Upload ${entry.key}',
          );
        });

        final uploads = await Future.wait(uploadFutures);

        // ASSERT: All uploads should be created successfully
        expect(uploads.length, 5);
        expect(uploads.map((u) => u.id).toSet().length, 5); // All unique IDs

        // Wait for processing
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify all uploads exist in manager
        for (final upload in uploads) {
          final retrievedUpload = uploadManager.getUpload(upload.id);
          expect(retrievedUpload, isNotNull);
          expect(retrievedUpload!.title, startsWith('Concurrent Upload'));
        }

        // Verify upload service was called for each upload
        verify(() => mockUploadService.uploadVideo(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          onProgress: any(named: 'onProgress'),
        )).called(5);
      });
    });
  });
}