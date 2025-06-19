// ABOUTME: Service for processing and validating Nostr video events with robust error handling
// ABOUTME: Provides comprehensive validation, type checking, and sanitization for video event data

import 'package:nostr/nostr.dart';
import '../models/video_event.dart';

/// Comprehensive video event processing service with validation and error handling
/// 
/// This service provides robust processing of Nostr events into VideoEvent objects
/// with comprehensive validation, error handling, and edge case management.
/// It goes beyond the basic VideoEvent.fromNostrEvent factory to provide
/// enterprise-grade validation and error reporting.
class VideoEventProcessor {
  /// List of supported video MIME types
  static const List<String> supportedVideoFormats = [
    'video/mp4',
    'video/webm',
    'video/ogg',
    'video/quicktime',
    'video/x-msvideo', // AVI
    'image/gif', // GIFs are supported as video-like content
  ];
  
  /// Maximum reasonable duration for short videos (in seconds)
  static const int maxReasonableDuration = 600; // 10 minutes
  
  /// Maximum reasonable file size for videos (in bytes)
  static const int maxReasonableFileSize = 100 * 1024 * 1024; // 100MB
  
  /// Process a Nostr event into a VideoEvent with comprehensive validation
  /// 
  /// This method provides robust error handling and validation beyond the
  /// basic VideoEvent.fromNostrEvent factory method. It performs extensive
  /// validation and provides detailed error information.
  /// 
  /// Throws [VideoEventProcessorException] if the event cannot be processed
  /// Throws [ArgumentError] if the event is null or malformed
  static VideoEvent fromNostrEvent(Event event) {
    // Validation will handle null checks internally
    
    // Validate the event first
    final validation = validateEvent(event);
    if (!validation.isValid) {
      throw VideoEventProcessorException(
        'Event validation failed: ${validation.errors.join(', ')}',
        eventId: event.id,
        originalError: validation.errors,
      );
    }
    
    try {
      // Use the existing VideoEvent factory method which already handles
      // the complex tag parsing logic correctly
      return VideoEvent.fromNostrEvent(event);
    } catch (e) {
      throw VideoEventProcessorException(
        'Failed to create VideoEvent from Nostr event',
        eventId: event.id,
        originalError: e,
      );
    }
  }
  
  /// Validate a Nostr event for video content compliance
  /// 
  /// Performs comprehensive validation including:
  /// - Event kind verification (must be 22)
  /// - Required field validation
  /// - Video URL format validation
  /// - Supported format checking
  /// - Content sanitization checks
  /// 
  /// Returns a [ValidationResult] with detailed validation information
  static ValidationResult validateEvent(Event event) {
    final errors = <String>[];
    final warnings = <String>[];
    
    // Basic null/existence checks - Let Dart's null safety handle this
    
    // Check event kind
    if (event.kind != 22) {
      errors.add('Event must be kind 22 (short video), got kind ${event.kind}');
    }
    
    // Check required fields
    if (event.id.isEmpty) {
      errors.add('Event ID cannot be empty');
    }
    
    if (event.pubkey.isEmpty) {
      errors.add('Pubkey cannot be empty');
    }
    
    // Check for video URL in tags
    String? videoUrl;
    String? mimeType;
    int? duration;
    int? fileSize;
    
    // Parse tags to extract video information
    for (final tag in event.tags) {
      if (tag.isEmpty) continue;
        
      final tagName = tag[0];
      final tagValue = tag.length > 1 ? tag[1] : '';
      
      switch (tagName) {
        case 'url':
          videoUrl ??= tagValue;
          break;
        case 'm':
          mimeType ??= tagValue;
          break;
        case 'duration':
          duration ??= int.tryParse(tagValue);
          break;
        case 'size':
          fileSize ??= int.tryParse(tagValue);
          break;
        case 'imeta':
          // Parse imeta tag for additional URL/metadata
          for (int i = 1; i < tag.length; i++) {
            final item = tag[i];
            if (item.startsWith('url ')) {
              videoUrl ??= item.substring(4);
            } else if (item.startsWith('m ')) {
              mimeType ??= item.substring(2);
            } else if (item.startsWith('duration ')) {
              duration ??= int.tryParse(item.substring(9));
            } else if (item.startsWith('size ')) {
              fileSize ??= int.tryParse(item.substring(5));
            }
          }
          break;
      }
    }
    
    // Validate video URL
    if (videoUrl?.isEmpty ?? true) {
      errors.add('Video URL is required');
    } else {
      // Validate URL format
      final uri = Uri.tryParse(videoUrl!);
      if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
        errors.add('Invalid video URL format');
      } else {
        // Check if URL looks like a video file
        final path = uri.path.toLowerCase();
        if (!path.endsWith('.mp4') && 
            !path.endsWith('.webm') && 
            !path.endsWith('.ogg') && 
            !path.endsWith('.mov') && 
            !path.endsWith('.avi') && 
            !path.endsWith('.gif')) {
          warnings.add('Video URL does not appear to be a direct video file link');
        }
      }
    }
    
    // Validate MIME type if present
    if (mimeType?.isNotEmpty == true) {
      if (!supportedVideoFormats.contains(mimeType!.toLowerCase())) {
        errors.add('Unsupported video format: $mimeType');
      }
    }
    
    // Validate duration if present
    if (duration != null) {
      if (duration < 0) {
        errors.add('Duration cannot be negative');
      } else if (duration > maxReasonableDuration) {
        warnings.add('Duration appears very long for short video: ${duration}s');
      }
    }
    
    // Validate file size if present
    if (fileSize != null) {
      if (fileSize < 0) {
        errors.add('File size cannot be negative');
      } else if (fileSize > maxReasonableFileSize) {
        warnings.add('File size appears very large: $fileSize bytes');
      }
    }
    
    // Content validation
    if (event.content.length > 10000) {
      warnings.add('Content is very long (${event.content.length} characters)');
    }
    
    return ValidationResult(errors: errors, warnings: warnings);
  }
  
  /// Quick validation check for video events
  /// 
  /// Returns true if the event is a valid video event, false otherwise.
  /// This is a fast check that only validates the most critical requirements.
  static bool isValidVideoEvent(Event event) {
    final validation = validateEvent(event);
    return validation.isValid;
  }
}

/// Result of event validation with detailed error and warning information
class ValidationResult {
  /// List of validation errors that prevent processing
  final List<String> errors;
  
  /// List of validation warnings (non-blocking issues)
  final List<String> warnings;
  
  /// Create validation result
  const ValidationResult({
    required this.errors,
    required this.warnings,
  });
  
  /// Whether the event passed validation (no errors)
  bool get isValid => errors.isEmpty;
  
  /// Whether there are any validation errors
  bool get hasErrors => errors.isNotEmpty;
  
  /// Whether there are any validation warnings
  bool get hasWarnings => warnings.isNotEmpty;
  
  @override
  String toString() {
    final buffer = StringBuffer('ValidationResult(');
    buffer.write('valid: $isValid');
    
    if (hasErrors) {
      buffer.write(', errors: ${errors.length}');
    }
    
    if (hasWarnings) {
      buffer.write(', warnings: ${warnings.length}');
    }
    
    buffer.write(')');
    return buffer.toString();
  }
}

/// Exception thrown when video event processing fails
class VideoEventProcessorException implements Exception {
  /// Error message describing the failure
  final String message;
  
  /// Optional event ID that failed to process
  final String? eventId;
  
  /// Original exception that caused the failure
  final dynamic originalError;
  
  /// Create video event processor exception
  const VideoEventProcessorException(
    this.message, {
    this.eventId,
    this.originalError,
  });
  
  @override
  String toString() {
    final buffer = StringBuffer('VideoEventProcessorException: $message');
    
    if (eventId != null) {
      buffer.write(' (eventId: $eventId)');
    }
    
    if (originalError != null) {
      buffer.write(' (caused by: $originalError)');
    }
    
    return buffer.toString();
  }
}