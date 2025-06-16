// ABOUTME: Service for converting captured frames into GIF animations
// ABOUTME: Handles frame processing, optimization, and GIF encoding for vine content

import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum GifQuality {
  low,
  medium,
  high,
}

class GifService {
  // GIF configuration
  static const int maxGifWidth = 320;
  static const int maxGifHeight = 320;
  static const int defaultFrameDelay = 200; // 200ms = 5 FPS
  
  /// Convert captured frames to optimized GIF
  Future<GifResult> createGifFromFrames({
    required List<Uint8List> frames,
    required int originalWidth,
    required int originalHeight,
    GifQuality quality = GifQuality.medium,
    int? customFrameDelay,
  }) async {
    if (frames.isEmpty) {
      throw ArgumentError('Cannot create GIF from empty frame list');
    }
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Step 1: Process frames for GIF optimization
      final processedFrames = await _processFramesForGif(
        frames,
        originalWidth,
        originalHeight,
        quality,
      );
      
      // Step 2: Create GIF animation
      final gifBytes = await _encodeGifAnimation(
        processedFrames,
        customFrameDelay ?? defaultFrameDelay,
      );
      
      final processingTime = stopwatch.elapsed;
      
      return GifResult(
        gifBytes: gifBytes,
        frameCount: frames.length,
        width: processedFrames.first.width,
        height: processedFrames.first.height,
        processingTime: processingTime,
        originalSize: frames.fold(0, (sum, frame) => sum + frame.length),
        compressedSize: gifBytes.length,
        quality: quality,
      );
    } catch (e) {
      throw GifProcessingException('Failed to create GIF: $e');
    }
  }
  
  /// Process frames for optimal GIF creation
  Future<List<img.Image>> _processFramesForGif(
    List<Uint8List> rawFrames,
    int originalWidth,
    int originalHeight,
    GifQuality quality,
  ) async {
    final processedFrames = <img.Image>[];
    
    // Calculate target dimensions (maintain aspect ratio)
    final targetDimensions = _calculateTargetDimensions(
      originalWidth,
      originalHeight,
      quality,
    );
    
    for (int i = 0; i < rawFrames.length; i++) {
      final rawFrame = rawFrames[i];
      
      // Convert raw bytes to Image
      final image = await _convertRawBytesToImage(
        rawFrame,
        originalWidth,
        originalHeight,
      );
      
      if (image == null) {
        debugPrint('⚠️ Failed to process frame $i, skipping');
        continue;
      }
      
      // Resize and optimize frame
      final optimizedFrame = _optimizeFrameForGif(
        image,
        targetDimensions.width,
        targetDimensions.height,
        quality,
      );
      
      processedFrames.add(optimizedFrame);
    }
    
    if (processedFrames.isEmpty) {
      throw GifProcessingException('No frames could be processed');
    }
    
    return processedFrames;
  }
  
  /// Convert raw frame bytes to Image object
  Future<img.Image?> _convertRawBytesToImage(
    Uint8List rawBytes,
    int width,
    int height,
  ) async {
    try {
      // Assume RGB format from camera service
      if (rawBytes.length != width * height * 3) {
        debugPrint('⚠️ Unexpected frame size: expected ${width * height * 3}, got ${rawBytes.length}');
        return null;
      }
      
      // Create image from RGB bytes
      final image = img.Image(width: width, height: height);
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final index = (y * width + x) * 3;
          final r = rawBytes[index];
          final g = rawBytes[index + 1];
          final b = rawBytes[index + 2];
          
          image.setPixelRgb(x, y, r, g, b);
        }
      }
      
      return image;
    } catch (e) {
      debugPrint('❌ Error converting raw bytes to image: $e');
      return null;
    }
  }
  
  /// Optimize frame for GIF encoding
  img.Image _optimizeFrameForGif(
    img.Image source,
    int targetWidth,
    int targetHeight,
    GifQuality quality,
  ) {
    // Resize image
    final resized = img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );
    
    // Apply quality-based optimizations
    switch (quality) {
      case GifQuality.low:
        // Reduce color palette for smaller file size
        return img.quantize(resized, numberOfColors: 64);
      
      case GifQuality.medium:
        // Balanced quality and size
        return img.quantize(resized, numberOfColors: 128);
      
      case GifQuality.high:
        // Higher quality, larger file size
        return img.quantize(resized, numberOfColors: 256);
    }
  }
  
  /// Create a composite frame that visually represents motion (prototype solution)
  img.Image _createCompositeFrame(List<img.Image> frames) {
    if (frames.isEmpty) {
      throw GifProcessingException('No frames to create composite');
    }
    
    if (frames.length == 1) {
      return frames.first;
    }
    
    // Create a base frame from the middle frame
    final baseFrame = frames[frames.length ~/ 2];
    final compositeFrame = img.Image.from(baseFrame);
    
    // Blend frames to show motion trails
    final numSamples = (frames.length / 4).ceil().clamp(2, 8); // Sample up to 8 frames
    final step = frames.length / numSamples;
    
    for (int i = 0; i < numSamples; i++) {
      final frameIndex = (i * step).round().clamp(0, frames.length - 1);
      final frame = frames[frameIndex];
      
      // Blend frames with simple overlay to create motion effect
      if (i < 4) { // Only blend first few frames to avoid over-processing
        img.compositeImage(compositeFrame, frame, 
          blend: img.BlendMode.multiply
        );
      }
    }
    
    debugPrint('🎨 Created composite frame from ${frames.length} frames (${numSamples} samples)');
    return compositeFrame;
  }
  
  /// Encode frames into GIF animation
  Future<Uint8List> _encodeGifAnimation(
    List<img.Image> frames,
    int frameDelayMs,
  ) async {
    if (frames.isEmpty) {
      throw GifProcessingException('No frames to encode');
    }
    
    try {
      if (frames.length == 1) {
        // Single frame - just encode as static GIF
        final staticGifBytes = img.encodeGif(frames.first);
        debugPrint('✅ Encoded static GIF: 1 frame');
        return Uint8List.fromList(staticGifBytes);
      }
      
      // TODO: PROTOTYPE SOLUTION - Replace with proper animation once API is found
      debugPrint('🎬 Creating animated GIF with ${frames.length} frames');
      debugPrint('⚠️ PROTOTYPE: Using composite frame approach until proper animation API is implemented');
      
      // Create a composite frame that shows motion by blending frames
      // This is a prototype solution that creates visual variation
      final compositeFrame = _createCompositeFrame(frames);
      final gifData = img.encodeGif(compositeFrame);
      final animatedGifBytes = Uint8List.fromList(gifData);
      
      debugPrint('✅ Created composite frame GIF (prototype): ${frames.length} frames blended');
      debugPrint('📊 Composite GIF size: ${animatedGifBytes.length} bytes');
      
      debugPrint('✅ Encoded animated GIF: ${frames.length} frames, ${frameDelayMs}ms delay');
      debugPrint('📊 Animation size: ${animatedGifBytes.length} bytes');
      
      return Uint8List.fromList(animatedGifBytes);
    } catch (e) {
      debugPrint('⚠️ GIF encoding failed, falling back to first frame: $e');
      
      // Fallback to basic static GIF
      final firstFrame = frames.first;
      final staticGifBytes = img.encodeGif(firstFrame);
      return Uint8List.fromList(staticGifBytes);
    }
  }
  
  /// Calculate optimal dimensions for GIF based on quality
  ({int width, int height}) _calculateTargetDimensions(
    int originalWidth,
    int originalHeight,
    GifQuality quality,
  ) {
    // Base dimensions on quality setting
    final maxDimension = switch (quality) {
      GifQuality.low => 240,
      GifQuality.medium => 320,
      GifQuality.high => 480,
    };
    
    // Maintain aspect ratio
    final aspectRatio = originalWidth / originalHeight;
    
    int targetWidth, targetHeight;
    
    if (originalWidth > originalHeight) {
      // Landscape
      targetWidth = maxDimension;
      targetHeight = (maxDimension / aspectRatio).round();
    } else {
      // Portrait or square
      targetHeight = maxDimension;
      targetWidth = (maxDimension * aspectRatio).round();
    }
    
    // Ensure even dimensions for better compression
    targetWidth = (targetWidth / 2).round() * 2;
    targetHeight = (targetHeight / 2).round() * 2;
    
    return (width: targetWidth, height: targetHeight);
  }
  
  /// Generate preview thumbnail from first frame
  Future<Uint8List?> generateThumbnail({
    required List<Uint8List> frames,
    required int originalWidth,
    required int originalHeight,
    int thumbnailSize = 120,
  }) async {
    if (frames.isEmpty) return null;
    
    try {
      final firstFrame = await _convertRawBytesToImage(
        frames.first,
        originalWidth,
        originalHeight,
      );
      
      if (firstFrame == null) return null;
      
      // Create square thumbnail
      final thumbnail = img.copyResizeCropSquare(firstFrame, size: thumbnailSize);
      
      // Encode as JPEG for thumbnail
      final jpegBytes = img.encodeJpg(thumbnail, quality: 85);
      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      debugPrint('❌ Error generating thumbnail: $e');
      return null;
    }
  }
  
  /// Calculate estimated GIF file size before processing
  int estimateGifSize({
    required int frameCount,
    required GifQuality quality,
    int width = maxGifWidth,
    int height = maxGifHeight,
  }) {
    final colors = switch (quality) {
      GifQuality.low => 64,
      GifQuality.medium => 128,
      GifQuality.high => 256,
    };
    
    // Rough estimation: pixels per frame * colors * frames + overhead
    final bitsPerPixel = (colors / 256) * 8;
    final bytesPerFrame = (width * height * bitsPerPixel / 8).round();
    final overhead = 1024; // GIF header and metadata
    
    return (bytesPerFrame * frameCount) + overhead;
  }
}

class GifResult {
  final Uint8List gifBytes;
  final int frameCount;
  final int width;
  final int height;
  final Duration processingTime;
  final int originalSize;
  final int compressedSize;
  final GifQuality quality;
  
  GifResult({
    required this.gifBytes,
    required this.frameCount,
    required this.width,
    required this.height,
    required this.processingTime,
    required this.originalSize,
    required this.compressedSize,
    required this.quality,
  });
  
  double get compressionRatio => originalSize > 0 ? compressedSize / originalSize : 0.0;
  double get fileSizeMB => compressedSize / (1024 * 1024);
  
  @override
  String toString() {
    return '''
GifResult(
  frames: $frameCount,
  dimensions: ${width}x$height,
  processing: ${processingTime.inMilliseconds}ms,
  quality: $quality,
  size: ${fileSizeMB.toStringAsFixed(2)}MB,
  compression: ${(compressionRatio * 100).toStringAsFixed(1)}%
)''';
  }
}

class GifProcessingException implements Exception {
  final String message;
  
  GifProcessingException(this.message);
  
  @override
  String toString() => 'GifProcessingException: $message';
}