// ABOUTME: Direct video upload service for CF Workers without external dependencies
// ABOUTME: Uploads videos directly to Cloudflare Workers → R2 storage with CDN serving

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../config/app_config.dart';
import 'nip98_auth_service.dart';
import 'video_thumbnail_service.dart';

/// Result of a direct upload operation
class DirectUploadResult {
  final bool success;
  final String? videoId;
  final String? cdnUrl;
  final String? thumbnailUrl;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  const DirectUploadResult({
    required this.success,
    this.videoId,
    this.cdnUrl,
    this.thumbnailUrl,
    this.errorMessage,
    this.metadata,
  });

  factory DirectUploadResult.success({
    required String videoId,
    required String cdnUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) {
    return DirectUploadResult(
      success: true,
      videoId: videoId,
      cdnUrl: cdnUrl,
      thumbnailUrl: thumbnailUrl,
      metadata: metadata,
    );
  }

  factory DirectUploadResult.failure(String errorMessage) {
    return DirectUploadResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

/// Service for uploading videos and images directly to CF Workers
class DirectUploadService extends ChangeNotifier {
  static String get _baseUrl => AppConfig.backendBaseUrl;
  
  final Map<String, StreamController<double>> _progressControllers = {};
  final Map<String, StreamSubscription<double>> _progressSubscriptions = {};
  final Nip98AuthService? _authService;
  
  DirectUploadService({Nip98AuthService? authService}) 
      : _authService = authService;
  
  /// Upload a video file directly to CF Workers with progress tracking
  Future<DirectUploadResult> uploadVideo({
    required File videoFile,
    required String nostrPubkey,
    String? title,
    String? description,
    List<String>? hashtags,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('🔄 Starting direct upload for video: ${videoFile.path}');
    
    String? videoId;
    
    try {
      // Generate a temporary ID for progress tracking
      videoId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Setup progress tracking
      final progressController = StreamController<double>.broadcast();
      _progressControllers[videoId] = progressController;
      
      if (onProgress != null) {
        final subscription = progressController.stream.listen(onProgress);
        _progressSubscriptions[videoId] = subscription;
      }
      
      // Generate thumbnail before upload
      progressController.add(0.05); // 5% for thumbnail generation
      debugPrint('📸 Generating video thumbnail...');
      
      Uint8List? thumbnailBytes;
      try {
        thumbnailBytes = await VideoThumbnailService.extractThumbnailBytes(
          videoPath: videoFile.path,
          timeMs: 500, // Extract at 500ms
          quality: 80,
        );
        
        if (thumbnailBytes != null) {
          debugPrint('✅ Thumbnail generated: ${(thumbnailBytes.length / 1024).toStringAsFixed(2)}KB');
        } else {
          debugPrint('⚠️ Failed to generate thumbnail, continuing without it');
        }
      } catch (e) {
        debugPrint('⚠️ Thumbnail generation error: $e, continuing without thumbnail');
      }

      // Create multipart request for direct CF Workers upload
      final url = '$_baseUrl/api/upload';
      final uri = Uri.parse(url);
      
      final request = http.MultipartRequest('POST', uri);
      
      // Add authorization headers
      final headers = await _getAuthHeaders(url);
      request.headers.addAll(headers);
      
      // Add video file with progress tracking
      final fileLength = await videoFile.length();
      final stream = videoFile.openRead();
      
      // Create a progress-tracking stream
      int bytesUploaded = 0;
      final progressStream = stream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            bytesUploaded += data.length;
            final progress = bytesUploaded / fileLength;
            progressController.add(progress * 0.9); // 0-90% for upload
            sink.add(data);
          },
        ),
      );
      
      final filename = videoFile.path.split('/').last;
      final contentType = _getContentType(filename);
      
      final multipartFile = http.MultipartFile(
        'file',
        progressStream,
        fileLength,
        filename: filename,
        contentType: contentType,
      );
      request.files.add(multipartFile);
      
      // Add thumbnail to the same request if available
      if (thumbnailBytes != null) {
        final thumbnailFile = http.MultipartFile.fromBytes(
          'thumbnail',
          thumbnailBytes,
          filename: 'thumbnail.jpg',
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(thumbnailFile);
        debugPrint('🖼️ Added thumbnail to upload request');
      }
      
      // Add optional metadata fields
      if (title != null) request.fields['title'] = title;
      if (description != null) request.fields['description'] = description;
      if (hashtags != null && hashtags.isNotEmpty) {
        request.fields['hashtags'] = hashtags.join(',');
      }
      
      // Send request
      progressController.add(0.10); // 10% - Starting main upload
      
      final streamedResponse = await request.send();
      
      progressController.add(0.95); // Upload complete, processing response
      
      final response = await http.Response.fromStream(streamedResponse);
      
      progressController.add(1.0); // Complete
      
      // Cleanup progress controller and subscription
      _progressControllers.remove(videoId);
      final subscription = _progressSubscriptions.remove(videoId);
      await subscription?.cancel();
      await progressController.close();
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Direct upload successful');
        debugPrint('📄 Response: $data');
        
        // Updated NIP-96 response structure
        if (data['status'] == 'success') {
          // Extract video ID from URL if not provided separately
          final cdnUrl = data['download_url'] ?? data['url'];
          String? videoId = data['video_id'];
          
          // Extract video ID from CDN URL if not provided
          if (videoId == null && cdnUrl != null) {
            final uri = Uri.parse(cdnUrl);
            final pathSegments = uri.pathSegments;
            if (pathSegments.isNotEmpty) {
              videoId = pathSegments.last;
            }
          }
          
          return DirectUploadResult.success(
            videoId: videoId ?? 'unknown',
            cdnUrl: cdnUrl,
            thumbnailUrl: data['thumbnail_url'] ?? data['thumb_url'], // Get thumbnail URL from response
            metadata: {
              'sha256': data['sha256'],
              'size': data['size'],
              'type': data['type'],
              'dimensions': data['dimensions'],
              'url': data['url'],
              'thumbnail_url': data['thumbnail_url'] ?? data['thumb_url'],
            },
          );
        } else {
          final errorMsg = data['message'] ?? data['error'] ?? 'Upload failed';
          debugPrint('❌ $errorMsg');
          return DirectUploadResult.failure(errorMsg);
        }
      } else {
        final errorBody = response.body;
        debugPrint('❌ Upload failed with status ${response.statusCode}: $errorBody');
        try {
          final errorData = jsonDecode(errorBody);
          final errorMsg = 'Upload failed: ${errorData['message'] ?? errorData['error'] ?? 'Unknown error'}';
          return DirectUploadResult.failure(errorMsg);
        } catch (_) {
          return DirectUploadResult.failure('Upload failed with status ${response.statusCode}');
        }
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Upload error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      
      // Clean up progress tracking on error
      if (videoId != null) {
        final subscription = _progressSubscriptions.remove(videoId);
        final controller = _progressControllers.remove(videoId);
        await subscription?.cancel();
        await controller?.close();
      }
      
      return DirectUploadResult.failure('Upload failed: $e');
    }
  }
  
  /// Get authorization headers for backend requests
  Future<Map<String, String>> _getAuthHeaders(String url) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    
    // Add NIP-98 authentication if available
    if (_authService?.canCreateTokens == true) {
      final authToken = await _authService!.createAuthToken(
        url: url,
        method: HttpMethod.post,
      );
      
      if (authToken != null) {
        headers['Authorization'] = authToken.authorizationHeader;
        debugPrint('🔐 Added NIP-98 auth to upload request');
      } else {
        debugPrint('⚠️ Failed to create NIP-98 auth token for upload');
      }
    } else {
      debugPrint('⚠️ No authentication service available for upload');
    }
    
    return headers;
  }
  
  /// Cancel an ongoing upload
  Future<void> cancelUpload(String videoId) async {
    final controller = _progressControllers.remove(videoId);
    final subscription = _progressSubscriptions.remove(videoId);
    
    if (controller != null || subscription != null) {
      await subscription?.cancel();
      await controller?.close();
      debugPrint('🚫 Upload cancelled: $videoId');
    }
  }
  
  /// Get upload progress stream for a specific upload
  Stream<double>? getProgressStream(String videoId) {
    return _progressControllers[videoId]?.stream;
  }
  
  /// Check if an upload is currently in progress
  bool isUploading(String videoId) {
    return _progressControllers.containsKey(videoId);
  }
  
  /// Upload a profile picture image directly to CF Workers
  Future<DirectUploadResult> uploadProfilePicture({
    required File imageFile,
    required String nostrPubkey,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint('🔄 Starting profile picture upload for: ${imageFile.path}');
    
    String? uploadId;
    
    try {
      // Generate a temporary ID for progress tracking
      uploadId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Setup progress tracking
      final progressController = StreamController<double>.broadcast();
      _progressControllers[uploadId] = progressController;
      
      if (onProgress != null) {
        final subscription = progressController.stream.listen(onProgress);
        _progressSubscriptions[uploadId] = subscription;
      }
      
      // Create multipart request for image upload (using same endpoint as videos)
      final url = '$_baseUrl/api/upload';
      final uri = Uri.parse(url);
      
      final request = http.MultipartRequest('POST', uri);
      
      // Add authorization headers
      final headers = await _getAuthHeaders(url);
      request.headers.addAll(headers);
      
      // Add image file with progress tracking
      final fileLength = await imageFile.length();
      final stream = imageFile.openRead();
      
      // Create a progress-tracking stream
      int bytesUploaded = 0;
      final progressStream = stream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            bytesUploaded += data.length;
            final progress = bytesUploaded / fileLength;
            progressController.add(progress * 0.9); // 0-90% for upload
            sink.add(data);
          },
        ),
      );
      
      final filename = imageFile.path.split('/').last;
      final contentType = _getImageContentType(filename);
      
      final multipartFile = http.MultipartFile(
        'file',
        progressStream,
        fileLength,
        filename: filename,
        contentType: contentType,
      );
      request.files.add(multipartFile);
      
      // Add metadata
      request.fields['type'] = 'profile_picture';
      request.fields['pubkey'] = nostrPubkey;
      
      // Send request
      progressController.add(0.10); // 10% - Starting upload
      
      final streamedResponse = await request.send();
      
      progressController.add(0.95); // Upload complete, processing response
      
      final response = await http.Response.fromStream(streamedResponse);
      
      progressController.add(1.0); // Complete
      
      // Cleanup progress controller and subscription
      _progressControllers.remove(uploadId);
      final subscription = _progressSubscriptions.remove(uploadId);
      await subscription?.cancel();
      await progressController.close();
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Profile picture upload successful');
        debugPrint('📄 Response: $data');
        
        if (data['status'] == 'success') {
          final cdnUrl = data['url'] ?? data['download_url'];
          
          return DirectUploadResult.success(
            videoId: uploadId,
            cdnUrl: cdnUrl,
            metadata: data,
          );
        } else {
          throw DirectUploadException(
            'Upload failed: ${data['message'] ?? 'Unknown error'}',
            code: 'UPLOAD_FAILED',
          );
        }
      } else {
        throw DirectUploadException(
          'HTTP ${response.statusCode}: ${response.body}',
          code: 'HTTP_ERROR_${response.statusCode}',
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Profile picture upload error: $e');
      debugPrint('Stack trace: $stack');
      
      // Cleanup on error
      if (uploadId != null) {
        _progressControllers.remove(uploadId);
        final subscription = _progressSubscriptions.remove(uploadId);
        await subscription?.cancel();
      }
      
      if (e is DirectUploadException) {
        rethrow;
      }
      
      return DirectUploadResult.failure(e.toString());
    }
  }
  
  /// Get current uploads in progress
  List<String> get activeUploads => _progressControllers.keys.toList();
  
  /// Determine content type based on file extension
  MediaType _getContentType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mov':
        return MediaType('video', 'quicktime');
      case 'avi':
        return MediaType('video', 'x-msvideo');
      case 'mkv':
        return MediaType('video', 'x-matroska');
      case 'webm':
        return MediaType('video', 'webm');
      case 'm4v':
        return MediaType('video', 'x-m4v');
      default:
        // Default to mp4 for unknown video files
        debugPrint('⚠️ Unknown video file extension: $extension, defaulting to mp4');
        return MediaType('video', 'mp4');
    }
  }
  
  /// Determine image content type based on file extension
  MediaType _getImageContentType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
      case 'heif':
        return MediaType('image', 'heic');
      default:
        // Default to jpeg for unknown image files
        debugPrint('⚠️ Unknown image file extension: $extension, defaulting to jpeg');
        return MediaType('image', 'jpeg');
    }
  }
  
  @override
  void dispose() {
    // Cancel all active uploads and subscriptions
    for (final subscription in _progressSubscriptions.values) {
      subscription.cancel();
    }
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressSubscriptions.clear();
    _progressControllers.clear();
    super.dispose();
  }
}

/// Exception thrown by DirectUploadService
class DirectUploadException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  const DirectUploadException(
    this.message, {
    this.code,
    this.originalError,
  });
  
  @override
  String toString() => 'DirectUploadException: $message';
}