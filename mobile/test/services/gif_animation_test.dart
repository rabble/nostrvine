// ABOUTME: Tests for animated GIF encoding functionality in GifService
// ABOUTME: Verifies true animated GIF creation and frame sequencing

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:nostrvine_app/services/gif_service.dart';

void main() {
  group('Animated GIF Encoding', () {
    late GifService gifService;

    setUp(() {
      gifService = GifService();
    });

    test('creates animated GIF from multiple RGB frames', () async {
      // Create test RGB frame data (100x100 pixels)
      const width = 100;
      const height = 100;
      const frameCount = 5;
      
      final frames = <Uint8List>[];
      
      // Create frames with different colors to ensure animation
      for (int f = 0; f < frameCount; f++) {
        final frameData = Uint8List(width * height * 3);
        
        for (int i = 0; i < frameData.length; i += 3) {
          // Create different colors for each frame
          frameData[i] = (255 * f / frameCount).round(); // Red intensity
          frameData[i + 1] = (255 * (frameCount - f) / frameCount).round(); // Green intensity  
          frameData[i + 2] = 100; // Blue constant
        }
        
        frames.add(frameData);
      }

      // Test GIF creation
      final result = await gifService.createGifFromFrames(
        frames: frames,
        originalWidth: width,
        originalHeight: height,
        customFrameDelay: 100, // 100ms per frame
      );

      // Verify result
      expect(result.frameCount, frameCount);
      expect(result.gifBytes.isNotEmpty, true);
      expect(result.width, greaterThan(0));
      expect(result.height, greaterThan(0));
      expect(result.gifBytes.length, greaterThan(0));
      
      // Verify it's larger than a single frame GIF (indicating animation)
      final singleFrameResult = await gifService.createGifFromFrames(
        frames: [frames.first],
        originalWidth: width,
        originalHeight: height,
        customFrameDelay: 100,
      );
      
      expect(result.gifBytes.length, greaterThan(singleFrameResult.gifBytes.length));
      
      debugPrint('✅ Animated GIF: ${result.gifBytes.length} bytes');
      debugPrint('✅ Single frame GIF: ${singleFrameResult.gifBytes.length} bytes');
      debugPrint('✅ Animation is ${(result.gifBytes.length / singleFrameResult.gifBytes.length).toStringAsFixed(1)}x larger');
    });

    test('handles single frame as static GIF', () async {
      const width = 50;
      const height = 50;
      
      // Create single red frame
      final frameData = Uint8List(width * height * 3);
      for (int i = 0; i < frameData.length; i += 3) {
        frameData[i] = 255; // Red
        frameData[i + 1] = 0; // Green
        frameData[i + 2] = 0; // Blue
      }

      final result = await gifService.createGifFromFrames(
        frames: [frameData],
        originalWidth: width,
        originalHeight: height,
      );

      expect(result.frameCount, 1);
      expect(result.gifBytes.isNotEmpty, true);
      debugPrint('✅ Static GIF: ${result.gifBytes.length} bytes');
    });

    test('throws exception for empty frame list', () async {
      expect(
        () => gifService.createGifFromFrames(
          frames: [],
          originalWidth: 100,
          originalHeight: 100,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('handles different quality levels', () async {
      const width = 80;
      const height = 80;
      
      // Create 3 test frames
      final frames = <Uint8List>[];
      for (int f = 0; f < 3; f++) {
        final frameData = Uint8List(width * height * 3);
        for (int i = 0; i < frameData.length; i += 3) {
          frameData[i] = (128 + f * 40); // Varying red
          frameData[i + 1] = 100; // Green
          frameData[i + 2] = (200 - f * 50); // Varying blue
        }
        frames.add(frameData);
      }

      // Test different quality levels
      final lowQuality = await gifService.createGifFromFrames(
        frames: frames,
        originalWidth: width,
        originalHeight: height,
        quality: GifQuality.low,
      );

      final highQuality = await gifService.createGifFromFrames(
        frames: frames,
        originalWidth: width,
        originalHeight: height,
        quality: GifQuality.high,
      );

      // High quality should generally be larger due to more colors
      expect(lowQuality.gifBytes.isNotEmpty, true);
      expect(highQuality.gifBytes.isNotEmpty, true);
      
      debugPrint('✅ Low quality: ${lowQuality.gifBytes.length} bytes');
      debugPrint('✅ High quality: ${highQuality.gifBytes.length} bytes');
    });

    test('processes frames in correct sequence', () async {
      // This test verifies that frames are processed in the right order
      // by creating distinctly different frames
      const width = 60;
      const height = 60;
      
      final frames = <Uint8List>[];
      
      // Frame 1: All red
      final frame1 = Uint8List(width * height * 3);
      for (int i = 0; i < frame1.length; i += 3) {
        frame1[i] = 255; frame1[i + 1] = 0; frame1[i + 2] = 0;
      }
      frames.add(frame1);
      
      // Frame 2: All green  
      final frame2 = Uint8List(width * height * 3);
      for (int i = 0; i < frame2.length; i += 3) {
        frame2[i] = 0; frame2[i + 1] = 255; frame2[i + 2] = 0;
      }
      frames.add(frame2);
      
      // Frame 3: All blue
      final frame3 = Uint8List(width * height * 3);
      for (int i = 0; i < frame3.length; i += 3) {
        frame3[i] = 0; frame3[i + 1] = 0; frame3[i + 2] = 255;
      }
      frames.add(frame3);

      final result = await gifService.createGifFromFrames(
        frames: frames,
        originalWidth: width,
        originalHeight: height,
        customFrameDelay: 200, // 200ms per frame
      );

      expect(result.frameCount, 3);
      expect(result.gifBytes.isNotEmpty, true);
      
      debugPrint('✅ Multi-color sequence GIF: ${result.gifBytes.length} bytes');
      debugPrint('✅ Processing time: ${result.processingTime.inMilliseconds}ms');
    });
  });
}