// ABOUTME: Direct video upload service for CF Workers without external dependencies
// ABOUTME: Uploads videos directly to Cloudflare Workers → R2 storage with CDN serving

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import 'nip98_auth_service.dart';

/// Result of a direct upload operation
class DirectUploadResult {
  final bool success;
  final String? videoId;
  final String? cdnUrl;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  const DirectUploadResult({
    required this.success,
    this.videoId,
    this.cdnUrl,
    this.errorMessage,
    this.metadata,
  });

  factory DirectUploadResult.success({
    required String videoId,
    required String cdnUrl,
    Map<String, dynamic>? metadata,
  }) {
    return DirectUploadResult(
      success: true,
      videoId: videoId,
      cdnUrl: cdnUrl,
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

/// Service for uploading videos directly to CF Workers
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

      // Create multipart request for direct CF Workers upload
      final url = '$_baseUrl/v1/media/upload';
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
      
      final multipartFile = http.MultipartFile(
        'video',
        progressStream,
        fileLength,
        filename: videoFile.path.split('/').last,
      );
      request.files.add(multipartFile);
      
      // Add optional metadata fields
      if (title != null) request.fields['title'] = title;
      if (description != null) request.fields['description'] = description;
      if (hashtags != null && hashtags.isNotEmpty) {
        request.fields['hashtags'] = hashtags.join(',');
      }
      
      // Send request
      progressController.add(0.05); // Start progress
      
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
        
        // CF Workers response structure
        if (data['success'] == true) {
          return DirectUploadResult.success(
            videoId: data['videoId'],
            cdnUrl: data['cdnUrl'],
            metadata: data['metadata'],
          );
        } else {
          final errorMsg = data['error'] ?? 'Upload failed';
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
  
  /// Get current uploads in progress
  List<String> get activeUploads => _progressControllers.keys.toList();
  
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