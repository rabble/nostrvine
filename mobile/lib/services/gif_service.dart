// ABOUTME: Service for converting captured frames into GIF animations
// ABOUTME: Handles frame processing, optimization, and GIF encoding for vine content

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum GifQuality {
  low,
  medium,
  high,
}

/// Exception thrown when GIF processing fails
class GifProcessingException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;
  
  const GifProcessingException(
    this.message, [
    this.originalError,
    this.stackTrace,
  ]);
  
  @override
  String toString() => 'GifProcessingException: $message';
}

/// Retry configuration for GIF operations
class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final Duration timeout;
  
  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 10),
    this.timeout = const Duration(minutes: 2),
  });
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
  // GIF configuration constants
  static const int maxGifWidth = 320;
  static const int maxGifHeight = 320;
  static const int defaultFrameDelay = 200; // 200ms = 5 FPS
  
  // Retry configuration
  final RetryConfig _retryConfig;
  
  GifService({RetryConfig? retryConfig})
      : _retryConfig = retryConfig ?? const RetryConfig();

  /// Execute operation with exponential backoff retry logic
  Future<T> _executeWithRetry<T>(
    String operationName,
    Future<T> Function() operation, {
    bool Function(dynamic error)? isRetriable,
  }) async {
    Duration currentDelay = _retryConfig.initialDelay;
    dynamic lastError;
    StackTrace? lastStackTrace;
    
    for (int attempt = 0; attempt <= _retryConfig.maxRetries; attempt++) {
      try {
        debugPrint('🔄 $operationName: Attempt ${attempt + 1}/${_retryConfig.maxRetries + 1}');
        
        final result = await operation().timeout(_retryConfig.timeout);
        
        if (attempt > 0) {
          debugPrint('✅ $operationName: Succeeded after ${attempt + 1} attempts');
        }
        
        return result;
        
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        
        debugPrint('❌ $operationName: Attempt ${attempt + 1} failed: $error');
        
        // Check if we should retry
        if (attempt >= _retryConfig.maxRetries) {
          debugPrint('💥 $operationName: Max retries exceeded, giving up');
          break;
        }
        
        // Check if error is retriable
        if (isRetriable != null && !isRetriable(error)) {
          debugPrint('🚫 $operationName: Error not retriable, giving up');
          break;
        }
        
        // Wait before retry with exponential backoff
        debugPrint('⏳ $operationName: Waiting ${currentDelay.inMilliseconds}ms before retry');
        await Future.delayed(currentDelay);
        
        // Calculate next delay with jitter
        currentDelay = Duration(
          milliseconds: min(
            (currentDelay.inMilliseconds * _retryConfig.backoffMultiplier).round(),
            _retryConfig.maxDelay.inMilliseconds,
          ),
        );
        
        // Add random jitter to avoid thundering herd
        final jitter = Random().nextDouble() * 0.1; // 0-10% jitter
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * (1 + jitter)).round(),
        );
      }
    }
    
    // All retries failed
    throw GifProcessingException(
      '$operationName: All retry attempts failed',
      lastError,
      lastStackTrace,
    );
  }

  /// Check if an error is retriable
  bool _isRetriable(dynamic error) {
    // Memory errors are generally not retriable
    if (error.toString().toLowerCase().contains('memory')) {
      return false;
    }
    
    // Argument errors suggest bad input data, not retriable
    if (error is ArgumentError) {
      return false;
    }
    
    // Format errors suggest corrupted data, not retriable
    if (error.toString().toLowerCase().contains('format') ||
        error.toString().toLowerCase().contains('corrupt')) {
      return false;
    }
    
    // Timeout and IO errors are retriable
    if (error is TimeoutException ||
        error.toString().toLowerCase().contains('timeout') ||
        error.toString().toLowerCase().contains('io')) {
      return true;
    }
    
    // Unknown errors are retriable by default
    return true;
  }

  /// Comprehensive input validation with detailed error messages
  void _validateInput(
    List<Uint8List> frames,
    int originalWidth,
    int originalHeight,
    int? customFrameDelay,
  ) {
    // Frame count validation
    if (frames.isEmpty) {
      throw ArgumentError('Cannot create GIF from empty frame list');
    }
    
    if (frames.length > 120) { // 120 frames = 24 seconds at 5fps
      throw ArgumentError('Too many frames: ${frames.length}. Maximum supported: 120');
    }
    
    if (frames.length < 2) {
      throw ArgumentError('Need at least 2 frames for animation. Got: ${frames.length}');
    }
    
    // Dimension validation
    if (originalWidth <= 0 || originalHeight <= 0) {
      throw ArgumentError('Invalid dimensions: ${originalWidth}x$originalHeight. Must be positive');
    }
    
    if (originalWidth > 4096 || originalHeight > 4096) {
      throw ArgumentError('Dimensions too large: ${originalWidth}x$originalHeight. Maximum: 4096x4096');
    }
    
    // Memory estimation validation
    final estimatedMemoryMB = _estimateMemoryUsage(frames, originalWidth, originalHeight);
    if (estimatedMemoryMB > 500) { // 500MB limit
      throw ArgumentError('Estimated memory usage too high: ${estimatedMemoryMB}MB. Maximum: 500MB');
    }
    
    // Frame delay validation
    if (customFrameDelay != null) {
      if (customFrameDelay < 50) {
        throw ArgumentError('Frame delay too short: ${customFrameDelay}ms. Minimum: 50ms');
      }
      if (customFrameDelay > 5000) {
        throw ArgumentError('Frame delay too long: ${customFrameDelay}ms. Maximum: 5000ms');
      }
    }
    
    // Individual frame validation
    for (int i = 0; i < frames.length; i++) {
      final frame = frames[i];
      if (frame.isEmpty) {
        throw ArgumentError('Frame $i is empty');
      }
      
      // Check for reasonable frame size
      if (frame.length > 50 * bytesPerMB) { // 50MB per frame max
        throw ArgumentError('Frame $i too large: ${frame.length} bytes. Maximum: ${50 * bytesPerMB} bytes');
      }
    }
    
    debugPrint('✅ Input validation passed: ${frames.length} frames, ${originalWidth}x$originalHeight, estimated ${estimatedMemoryMB}MB memory usage');
  }

  /// Estimate memory usage for processing
  double _estimateMemoryUsage(List<Uint8List> frames, int width, int height) {
    // Raw frame data
    final rawDataMB = frames.fold(0, (sum, frame) => sum + frame.length) / bytesPerMB;
    
    // Decoded image data (RGBA, so 4 bytes per pixel)
    final decodedDataMB = (frames.length * width * height * 4) / bytesPerMB;
    
    // Processing overhead (temporary buffers, encoding, etc.)
    final overheadMB = (decodedDataMB * 0.5).clamp(10, 100); // 50% overhead, min 10MB, max 100MB
    
    return rawDataMB + decodedDataMB + overheadMB;
  }
  
  // JPEG format constants
  static const int jpegMagicByte1 = 0xFF;
  static const int jpegMagicByte2 = 0xD8;
  static const int rgbChannelsPerPixel = 3;
  
  // Quality-based color palette constants
  static const int lowQualityColors = 64;
  static const int mediumQualityColors = 128;
  static const int highQualityColors = 256;
  
  // Dimension calculation constants
  static const int lowQualityMaxDimension = 240;
  static const int mediumQualityMaxDimension = 320;
  static const int highQualityMaxDimension = 480;
  static const int dimensionAlignment = 2; // For even dimensions
  
  // Thumbnail generation constants
  static const int defaultThumbnailSize = 120;
  static const int thumbnailJpegQuality = 85;
  
  // Size estimation constants
  static const int maxColorsInPalette = 256;
  static const int bitsPerByte = 8;
  static const int gifHeaderOverheadBytes = 1024;
  
  // File size calculation constants
  static const int bytesPerKB = 1024;
  static const int bytesPerMB = 1024 * 1024;
  
  /// Convert captured frames to optimized GIF with retry logic and enhanced error handling
  Future<GifResult> createGifFromFrames({
    required List<Uint8List> frames,
    required int originalWidth,
    required int originalHeight,
    GifQuality quality = GifQuality.medium,
    int? customFrameDelay,
  }) async {
    // Enhanced input validation
    _validateInput(frames, originalWidth, originalHeight, customFrameDelay);
    
    final stopwatch = Stopwatch()..start();
    
    try {
      debugPrint('🎬 Starting GIF creation: ${frames.length} frames, ${originalWidth}x${originalHeight}, quality: $quality');
      
      // Step 1: Process frames for GIF optimization with retry
      final processedFrames = await _executeWithRetry(
        'Frame Processing',
        () => _processFramesForGif(frames, originalWidth, originalHeight, quality),
        isRetriable: _isRetriable,
      );
      
      // Step 2: Create GIF animation with retry
      final gifBytes = await _executeWithRetry(
        'GIF Encoding',
        () => _encodeGifAnimation(processedFrames, customFrameDelay ?? defaultFrameDelay),
        isRetriable: _isRetriable,
      );
      
      final processingTime = stopwatch.elapsed;
      
      debugPrint('✅ GIF creation completed in ${processingTime.inMilliseconds}ms: ${gifBytes.length} bytes');
      
      // Final validation and metrics
      final result = GifResult(
        gifBytes: gifBytes,
        frameCount: frames.length,
        width: processedFrames.first.width,
        height: processedFrames.first.height,
        processingTime: processingTime,
        originalSize: frames.fold(0, (sum, frame) => sum + frame.length),
        compressedSize: gifBytes.length,
        quality: quality,
      );
      
      _logPerformanceMetrics(result, frames.length);
      
      return result;
      
    } on ArgumentError catch (e) {
      debugPrint('❌ GIF creation failed due to invalid input: $e');
      rethrow; // Don't wrap argument errors
    } on GifProcessingException catch (e) {
      debugPrint('❌ GIF processing failed: $e');
      rethrow; // Don't double-wrap our exceptions
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error during GIF creation: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      throw GifProcessingException(
        'Failed to create GIF: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Log performance metrics for monitoring
  void _logPerformanceMetrics(GifResult result, int originalFrameCount) {
    final compressionRatio = result.originalSize > 0 
        ? (result.compressedSize / result.originalSize * 100).toStringAsFixed(1)
        : 'N/A';
    
    final processingSpeed = result.processingTime.inMilliseconds > 0
        ? (originalFrameCount / (result.processingTime.inMilliseconds / 1000)).toStringAsFixed(1)
        : 'N/A';
    
    debugPrint('📊 GIF Performance Metrics:');
    debugPrint('   Size: ${result.originalSize} → ${result.compressedSize} bytes ($compressionRatio%)');
    debugPrint('   Time: ${result.processingTime.inMilliseconds}ms ($processingSpeed fps)');
    debugPrint('   Dimensions: ${result.width}x${result.height}');
    debugPrint('   Quality: ${result.quality}');
    debugPrint('   Frames: ${result.frameCount}');
  }
  
  /// Process frames for optimal GIF creation with graceful degradation
  Future<List<img.Image>> _processFramesForGif(
    List<Uint8List> rawFrames,
    int originalWidth,
    int originalHeight,
    GifQuality quality,
  ) async {
    final processedFrames = <img.Image>[];
    int failedFrames = 0;
    int corruptedFrames = 0;
    
    debugPrint('🖼️ Processing ${rawFrames.length} frames for GIF creation');
    
    // Calculate target dimensions (maintain aspect ratio)
    final targetDimensions = _calculateTargetDimensions(
      originalWidth,
      originalHeight,
      quality,
    );
    
    debugPrint('📐 Target dimensions: ${targetDimensions.width}x${targetDimensions.height}');
    
    for (int i = 0; i < rawFrames.length; i++) {
      try {
        final rawFrame = rawFrames[i];
        
        // Validate frame data
        if (rawFrame.isEmpty) {
          debugPrint('⚠️ Frame $i is empty, skipping');
          failedFrames++;
          continue;
        }
        
        // Convert raw bytes to Image with timeout
        final image = await _convertRawBytesToImage(
          rawFrame,
          originalWidth,
          originalHeight,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⏱️ Frame $i conversion timed out');
            return null;
          },
        );
        
        if (image == null) {
          corruptedFrames++;
          debugPrint('⚠️ Failed to convert frame $i (corrupted data), skipping');
          
          // Apply graceful degradation - if too many frames are corrupted, fail early
          if (corruptedFrames > rawFrames.length * 0.3) { // 30% corruption threshold
            throw GifProcessingException(
              'Too many corrupted frames: $corruptedFrames/${rawFrames.length}. '
              'Video data may be corrupted.'
            );
          }
          continue;
        }
        
        // Validate image dimensions
        if (image.width != originalWidth || image.height != originalHeight) {
          debugPrint('⚠️ Frame $i has unexpected dimensions: ${image.width}x${image.height}, expected ${originalWidth}x$originalHeight');
        }
        
        // Resize and optimize frame with error handling
        try {
          final optimizedFrame = _optimizeFrameForGif(
            image,
            targetDimensions.width,
            targetDimensions.height,
            quality,
          );
          
          processedFrames.add(optimizedFrame);
          
        } catch (e) {
          debugPrint('⚠️ Failed to optimize frame $i: $e');
          failedFrames++;
          continue;
        }
        
      } catch (e) {
        debugPrint('⚠️ Error processing frame $i: $e');
        failedFrames++;
        continue;
      }
    }
    
    // Final validation
    if (processedFrames.isEmpty) {
      throw GifProcessingException(
        'No frames could be processed. Failed: $failedFrames, Corrupted: $corruptedFrames'
      );
    }
    
    // Check minimum viable frame count
    if (processedFrames.length < 2) {
      throw GifProcessingException(
        'Not enough frames for animation: ${processedFrames.length}. Need at least 2.'
      );
    }
    
    // Warn about significant frame loss
    final successRate = (processedFrames.length / rawFrames.length * 100);
    if (successRate < 70) { // Less than 70% success rate
      debugPrint('⚠️ Low frame processing success rate: ${successRate.toStringAsFixed(1)}%');
      debugPrint('   Processed: ${processedFrames.length}/${rawFrames.length}');
      debugPrint('   Failed: $failedFrames, Corrupted: $corruptedFrames');
    } else {
      debugPrint('✅ Frame processing completed: ${processedFrames.length}/${rawFrames.length} frames (${successRate.toStringAsFixed(1)}%)');
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
      if (frameBytes.length >= 2 && frameBytes[0] == jpegMagicByte1 && frameBytes[1] == jpegMagicByte2) {
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
      final expectedSize = width * height * rgbChannelsPerPixel;
      if (frameBytes.length != expectedSize) {
        debugPrint('⚠️ Unexpected raw frame size: expected $expectedSize, got ${frameBytes.length}');
        return null;
      }
      
      debugPrint('🖼️ Processing raw RGB frame (${frameBytes.length} bytes)');
      
      // Create image from RGB bytes
      final image = img.Image(
        width: width, 
        height: height,
        numChannels: rgbChannelsPerPixel,
      );
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final index = (y * width + x) * rgbChannelsPerPixel;
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
        return img.quantize(resized, numberOfColors: lowQualityColors);
      
      case GifQuality.medium:
        // Balanced quality and size
        return img.quantize(resized, numberOfColors: mediumQualityColors);
      
      case GifQuality.high:
        // Higher quality, larger file size
        return img.quantize(resized, numberOfColors: highQualityColors);
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
      GifQuality.low => lowQualityMaxDimension,
      GifQuality.medium => mediumQualityMaxDimension,
      GifQuality.high => highQualityMaxDimension,
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
    targetWidth = (targetWidth / dimensionAlignment).round() * dimensionAlignment;
    targetHeight = (targetHeight / dimensionAlignment).round() * dimensionAlignment;
    
    return (width: targetWidth, height: targetHeight);
  }
  
  /// Generate preview thumbnail from first frame
  Future<Uint8List?> generateThumbnail({
    required List<Uint8List> frames,
    required int originalWidth,
    required int originalHeight,
    int thumbnailSize = defaultThumbnailSize,
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
      final jpegBytes = img.encodeJpg(thumbnail, quality: thumbnailJpegQuality);
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
      GifQuality.low => lowQualityColors,
      GifQuality.medium => mediumQualityColors,
      GifQuality.high => highQualityColors,
    };
    
    // Rough estimation: pixels per frame * colors * frames + overhead
    final bitsPerPixel = (colors / maxColorsInPalette) * bitsPerByte;
    final bytesPerFrame = (width * height * bitsPerPixel / bitsPerByte).round();
    final overhead = gifHeaderOverheadBytes; // GIF header and metadata
    
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
  double get fileSizeMB => compressedSize / GifService.bytesPerMB;
  
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

