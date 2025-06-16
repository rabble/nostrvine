// ABOUTME: Service for converting captured frames into GIF animations
// ABOUTME: Handles frame processing, optimization, and GIF encoding for vine content

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum GifQuality {
  low,
  medium,
  high,
}

// Helper function for isolate-based GIF encoding to prevent UI blocking
Uint8List _encodeGifInIsolate(Map<String, dynamic> params) {
  final frames = params['frames'] as List<img.Image>;
  final frameDelayMs = params['frameDelayMs'] as int;
  
  // Create GIF encoder for animation
  final encoder = img.GifEncoder();
  
  // Start encoding with first frame
  encoder.encode(frames.first);
  
  // Add subsequent frames
  for (int i = 1; i < frames.length; i++) {
    encoder.addFrame(frames[i], duration: frameDelayMs);
  }
  
  // Finish encoding
  final finalData = encoder.finish();
  
  if (finalData == null || finalData.isEmpty) {
    throw Exception('Failed to encode GIF animation - encoder returned null/empty');
  }
  
  return Uint8List.fromList(finalData);
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
  
  /// Convert frame bytes to Image object (supports both JPEG and RGB)
  Future<img.Image?> _convertRawBytesToImage(
    Uint8List frameBytes,
    int width,
    int height,
  ) async {
    try {
      // Check if this looks like JPEG data (starts with FFD8)
      if (frameBytes.length >= 2 && frameBytes[0] == 0xFF && frameBytes[1] == 0xD8) {
        debugPrint('🖼️ Processing JPEG frame (${frameBytes.length} bytes)');
        
        // Decode JPEG directly
        final image = img.decodeJpg(frameBytes);
        if (image != null) {
          debugPrint('✅ JPEG decoded: ${image.width}x${image.height}');
          return image;
        } else {
          debugPrint('❌ Failed to decode JPEG frame');
          return null;
        }
      }
      
      // Fallback: assume RGB format from camera service
      final expectedSize = width * height * 3;
      if (frameBytes.length != expectedSize) {
        debugPrint('⚠️ Unexpected raw frame size: expected $expectedSize, got ${frameBytes.length}');
        return null;
      }
      
      debugPrint('🖼️ Processing raw RGB frame (${frameBytes.length} bytes)');
      
      // Create image from RGB bytes
      final image = img.Image(
        width: width, 
        height: height,
        numChannels: 3,
      );
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final index = (y * width + x) * 3;
          final r = frameBytes[index];
          final g = frameBytes[index + 1];
          final b = frameBytes[index + 2];
          
          image.setPixelRgb(x, y, r, g, b);
        }
      }
      
      return image;
    } catch (e) {
      debugPrint('❌ Error converting frame bytes to image: $e');
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
      
      // Create proper animated GIF using isolate for performance
      debugPrint('🎬 Creating animated GIF with ${frames.length} frames');
      debugPrint('⚡ Running GIF encoding in isolate to prevent UI blocking');
      
      // Use compute() to run encoding in a separate isolate for better performance
      final animatedGifBytes = await compute(_encodeGifInIsolate, {
        'frames': frames,
        'frameDelayMs': frameDelayMs,
      });
      
      debugPrint('✅ Encoded animated GIF: ${frames.length} frames, ${frameDelayMs}ms delay');
      debugPrint('📊 Animation size: ${animatedGifBytes.length} bytes');
      debugPrint('⚡ Encoding completed in isolate without blocking UI');
      
      return animatedGifBytes;
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