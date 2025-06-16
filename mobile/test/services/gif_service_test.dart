// ABOUTME: Unit tests for GifService frame-to-GIF conversion functionality
// ABOUTME: Tests TDD approach for GIF encoding, optimization, and error handling

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/gif_service.dart';

void main() {
  group('GifService', () {
    late GifService gifService;
    
    setUp(() {
      gifService = GifService();
    });

    group('Configuration Constants', () {
      test('should have correct GIF dimension limits', () {
        expect(GifService.maxGifWidth, equals(320));
        expect(GifService.maxGifHeight, equals(320));
      });

      test('should have correct default frame delay for 5 FPS', () {
        expect(GifService.defaultFrameDelay, equals(200)); // 200ms = 5 FPS
      });
    });

    group('Frame Validation', () {
      test('should throw error for empty frame list', () async {
        expect(
          () => gifService.createGifFromFrames(
            frames: [],
            originalWidth: 640,
            originalHeight: 480,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle valid frame parameters', () {
        // Test parameter validation without actual processing
        // Use correctly sized frame (640 * 480 * 3 bytes for RGB)
        final future = gifService.createGifFromFrames(
          frames: [_createTestFrame(640, 480)],
          originalWidth: 640,
          originalHeight: 480,
        );
        
        expect(future, isA<Future<GifResult>>());
      });
    });

    group('Quality Settings', () {
      test('should have all quality levels defined', () {
        expect(GifQuality.values, contains(GifQuality.low));
        expect(GifQuality.values, contains(GifQuality.medium));
        expect(GifQuality.values, contains(GifQuality.high));
      });
    });

    group('Dimension Calculation', () {
      test('should calculate target dimensions for different qualities', () {
        final service = GifService();
        
        // We can't directly test the private method, but we can test the concept
        // through the public estimateGifSize method which uses similar logic
        
        final lowEstimate = service.estimateGifSize(
          frameCount: 30,
          quality: GifQuality.low,
        );
        
        final highEstimate = service.estimateGifSize(
          frameCount: 30,
          quality: GifQuality.high,
        );
        
        // High quality should result in larger estimated size
        expect(highEstimate, greaterThan(lowEstimate));
      });
    });

    group('Size Estimation', () {
      test('should estimate GIF size correctly for different frame counts', () {
        final estimatedSize10 = gifService.estimateGifSize(
          frameCount: 10,
          quality: GifQuality.medium,
        );
        
        final estimatedSize30 = gifService.estimateGifSize(
          frameCount: 30,
          quality: GifQuality.medium,
        );
        
        // More frames should result in larger size
        expect(estimatedSize30, greaterThan(estimatedSize10));
      });

      test('should provide reasonable size estimates', () {
        final estimatedSize = gifService.estimateGifSize(
          frameCount: 30,
          quality: GifQuality.medium,
          width: 320,
          height: 320,
        );
        
        // Should be reasonable (less than 10MB for a 6-second vine)
        expect(estimatedSize, lessThan(10 * 1024 * 1024));
        expect(estimatedSize, greaterThan(0));
      });

      test('should scale with quality settings', () {
        final lowSize = gifService.estimateGifSize(
          frameCount: 30,
          quality: GifQuality.low,
        );
        
        final mediumSize = gifService.estimateGifSize(
          frameCount: 30,
          quality: GifQuality.medium,
        );
        
        final highSize = gifService.estimateGifSize(
          frameCount: 30,
          quality: GifQuality.high,
        );
        
        expect(lowSize, lessThan(mediumSize));
        expect(mediumSize, lessThan(highSize));
      });
    });

    group('Thumbnail Generation', () {
      test('should return null for empty frames', () async {
        final thumbnail = await gifService.generateThumbnail(
          frames: [],
          originalWidth: 640,
          originalHeight: 480,
        );
        
        expect(thumbnail, isNull);
      });

      test('should accept valid thumbnail parameters', () {
        // Test that the method signature is correct
        final future = gifService.generateThumbnail(
          frames: [_createTestFrame(640, 480)],
          originalWidth: 640,
          originalHeight: 480,
          thumbnailSize: 120,
        );
        
        expect(future, isA<Future<Uint8List?>>());
      });
    });

    group('GifResult', () {
      test('should create valid GIF result', () {
        final result = GifResult(
          gifBytes: Uint8List(1000),
          frameCount: 30,
          width: 320,
          height: 320,
          processingTime: const Duration(milliseconds: 500),
          originalSize: 10000,
          compressedSize: 1000,
          quality: GifQuality.medium,
        );
        
        expect(result.frameCount, equals(30));
        expect(result.width, equals(320));
        expect(result.height, equals(320));
        expect(result.compressionRatio, equals(0.1));
        expect(result.fileSizeMB, closeTo(0.00095, 0.0001));
      });

      test('should calculate compression ratio correctly', () {
        final result = GifResult(
          gifBytes: Uint8List(500),
          frameCount: 10,
          width: 240,
          height: 240,
          processingTime: Duration.zero,
          originalSize: 1000,
          compressedSize: 500,
          quality: GifQuality.low,
        );
        
        expect(result.compressionRatio, equals(0.5)); // 50% compression
      });

      test('should handle zero original size gracefully', () {
        final result = GifResult(
          gifBytes: Uint8List(500),
          frameCount: 10,
          width: 240,
          height: 240,
          processingTime: Duration.zero,
          originalSize: 0,
          compressedSize: 500,
          quality: GifQuality.low,
        );
        
        expect(result.compressionRatio, equals(0.0));
      });

      test('should provide meaningful string representation', () {
        final result = GifResult(
          gifBytes: Uint8List(1024 * 1024), // 1MB
          frameCount: 30,
          width: 320,
          height: 320,
          processingTime: const Duration(milliseconds: 750),
          originalSize: 2 * 1024 * 1024, // 2MB
          compressedSize: 1024 * 1024, // 1MB
          quality: GifQuality.medium,
        );
        
        final resultString = result.toString();
        
        expect(resultString, contains('frames: 30'));
        expect(resultString, contains('320x320'));
        expect(resultString, contains('750ms'));
        expect(resultString, contains('medium'));
        expect(resultString, contains('1.00MB'));
        expect(resultString, contains('50.0%'));
      });
    });

    group('Error Handling', () {
      test('should define GifProcessingException', () {
        final exception = GifProcessingException('Test error');
        
        expect(exception.message, equals('Test error'));
        expect(exception.toString(), contains('GifProcessingException'));
        expect(exception.toString(), contains('Test error'));
      });
    });

    group('Integration with Camera Service', () {
      test('should handle typical vine recording parameters', () {
        // Test that GifService can handle typical output from CameraService
        const frameCount = 30; // 6 seconds * 5 FPS
        const width = 640;
        const height = 480;
        
        final estimatedSize = gifService.estimateGifSize(
          frameCount: frameCount,
          quality: GifQuality.medium,
          width: width,
          height: height,
        );
        
        // Should be manageable size for mobile app
        expect(estimatedSize, lessThan(5 * 1024 * 1024)); // Less than 5MB
        expect(estimatedSize, greaterThan(10 * 1024)); // More than 10KB
      });
    });
  });
}

/// Helper function to create test frame data
Uint8List _createTestFrame(int width, int height) {
  // Create RGB frame data with test pattern
  final frameSize = width * height * 3;
  final data = Uint8List(frameSize);
  
  // Fill with simple test pattern
  for (int i = 0; i < frameSize; i += 3) {
    data[i] = 128;     // R
    data[i + 1] = 128; // G
    data[i + 2] = 128; // B
  }
  
  return data;
}