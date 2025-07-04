// ABOUTME: Cloudflare Stream upload service for video hosting and transcoding
// ABOUTME: Handles video uploads to Stream CDN with NIP-98 authentication

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'nip98_auth_service.dart';
import '../utils/unified_logger.dart';

/// Result of a Stream upload operation
class StreamUploadResult {
  final bool success;
  final String? videoId;
  final String? uploadUrl;
  final String? hlsUrl;
  final String? dashUrl;
  final String? thumbnailUrl;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  const StreamUploadResult({
    required this.success,
    this.videoId,
    this.uploadUrl,
    this.hlsUrl,
    this.dashUrl,
    this.thumbnailUrl,
    this.errorMessage,
    this.metadata,
  });

  factory StreamUploadResult.success({
    required String videoId,
    required String uploadUrl,
    String? hlsUrl,
    String? dashUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) {
    return StreamUploadResult(
      success: true,
      videoId: videoId,
      uploadUrl: uploadUrl,
      hlsUrl: hlsUrl,
      dashUrl: dashUrl,
      thumbnailUrl: thumbnailUrl,
      metadata: metadata,
    );
  }

  factory StreamUploadResult.failure(String errorMessage) {
    return StreamUploadResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

/// Upload request parameters for Stream
class StreamUploadRequest {
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String? nostrPubkey;
  final String? title;
  final String? description;
  final List<String>? hashtags;

  const StreamUploadRequest({
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.nostrPubkey,
    this.title,
    this.description,
    this.hashtags,
  });

  Map<String, dynamic> toJson() {
    return {
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      if (nostrPubkey != null) 'nostr_pubkey': nostrPubkey,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (hashtags != null && hashtags!.isNotEmpty) 'hashtags': hashtags,
    };
  }
}

/// Video status from Stream backend
class StreamVideoStatus {
  final String videoId;
  final String status; // uploading, processing, ready, failed
  final String? hlsUrl;
  final String? dashUrl;
  final String? thumbnailUrl;
  final String? error;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StreamVideoStatus({
    required this.videoId,
    required this.status,
    this.hlsUrl,
    this.dashUrl,
    this.thumbnailUrl,
    this.error,
    this.createdAt,
    this.updatedAt,
  });

  factory StreamVideoStatus.fromJson(Map<String, dynamic> json) {
    return StreamVideoStatus(
      videoId: json['videoId'] as String,
      status: json['status'] as String,
      hlsUrl: json['hlsUrl'] as String?,
      dashUrl: json['dashUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      error: json['error'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  bool get isReady => status == 'ready' || status == 'published';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing' || status == 'uploading';
}

/// Service for uploading videos to Cloudflare Stream
class StreamUploadService extends ChangeNotifier {
  
  final Map<String, StreamController<double>> _progressControllers = {};
  final http.Client _client;
  final Nip98AuthService? _authService;
  
  StreamUploadService({http.Client? client, Nip98AuthService? authService}) 
    : _client = client ?? http.Client(),
      _authService = authService;
  
  /// Upload a video file to Cloudflare Stream with progress tracking
  Future<StreamUploadResult> uploadVideo({
    required File videoFile,
    required String nostrPubkey,
    String? title,
    String? description,
    List<String>? hashtags,
    void Function(double progress)? onProgress,
  }) async {
    Log.debug('Starting Stream upload for video: ${videoFile.path}', name: 'StreamUploadService', category: LogCategory.system);
    
    try {
      // Step 1: Request upload URL from our backend
      final uploadRequest = await _requestUploadUrl(
        videoFile: videoFile,
        nostrPubkey: nostrPubkey,
        title: title,
        description: description,
        hashtags: hashtags,
      );
      
      // Step 2: Upload directly to Cloudflare Stream
      final videoId = await _uploadToStream(
        videoFile: videoFile,
        uploadUrl: uploadRequest['uploadURL'] as String,
        onProgress: onProgress,
      );
      
      Log.info('Stream upload successful: $videoId', name: 'StreamUploadService', category: LogCategory.system);
      return StreamUploadResult.success(
        videoId: videoId,
        uploadUrl: uploadRequest['uploadURL'] as String,
        metadata: {
          'uid': videoId,
          'uploadURL': uploadRequest['uploadURL'],
          'scheduledDeletion': uploadRequest['scheduledDeletion'],
          'watermark': uploadRequest['watermark'],
        },
      );
      
    } catch (e, stackTrace) {
      Log.error('Stream upload error: $e', name: 'StreamUploadService', category: LogCategory.system);
      Log.verbose('� Stack trace: $stackTrace', name: 'StreamUploadService', category: LogCategory.system);
      return StreamUploadResult.failure('Upload failed: $e');
    }
  }
  
  /// Request upload URL from our backend
  Future<Map<String, dynamic>> _requestUploadUrl({
    required File videoFile,
    required String nostrPubkey,
    String? title,
    String? description,
    List<String>? hashtags,
  }) async {
    Log.debug('� Requesting Stream upload URL from backend', name: 'StreamUploadService', category: LogCategory.system);
    
    try {
      // Get file size and basic metadata
      final fileStat = await videoFile.stat();
      final fileSize = fileStat.size;
      
      final uploadRequest = StreamUploadRequest(
        fileName: 'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
        fileSize: fileSize,
        mimeType: 'video/mp4',
        nostrPubkey: nostrPubkey,
        title: title,
        description: description,
        hashtags: hashtags,
      );
      
      final response = await _client.post(
        Uri.parse(AppConfig.streamUploadRequestUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': await _getNip98Token(url: AppConfig.streamUploadRequestUrl, method: HttpMethod.post),
        },
        body: jsonEncode(uploadRequest.toJson()),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Log.info('Received Stream upload URL', name: 'StreamUploadService', category: LogCategory.system);
        return data as Map<String, dynamic>;
      } else {
        throw Exception('Backend request failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      Log.error('Failed to get Stream upload URL: $e', name: 'StreamUploadService', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Upload video file directly to Cloudflare Stream
  Future<String> _uploadToStream({
    required File videoFile,
    required String uploadUrl,
    void Function(double progress)? onProgress,
  }) async {
    Log.debug('� Uploading to Cloudflare Stream: $uploadUrl', name: 'StreamUploadService', category: LogCategory.system);
    
    try {
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      
      // Add video file
      final videoStream = http.ByteStream(videoFile.openRead());
      final videoLength = await videoFile.length();
      
      request.files.add(http.MultipartFile(
        'file',
        videoStream,
        videoLength,
        filename: 'video.mp4',
      ));
      
      // Setup progress tracking if callback provided
      if (onProgress != null) {
        final progressController = StreamController<double>.broadcast();
        
        // Listen to upload progress (simplified - actual implementation would need custom HTTP client)
        var uploadedBytes = 0;
        progressController.stream.listen((progress) {
          onProgress(progress);
        });
        
        // Simulate progress for now
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
          uploadedBytes += (videoLength * 0.1).round();
          if (uploadedBytes >= videoLength) {
            progressController.add(1.0);
            timer.cancel();
            progressController.close();
          } else {
            progressController.add(uploadedBytes / videoLength);
          }
        });
      }
      
      // Send request to Cloudflare Stream
      final response = await request.send().timeout(const Duration(minutes: 5));
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        // Extract video ID from response headers or body
        // Cloudflare Stream returns the video ID in the response
        final videoId = _extractVideoIdFromResponse(responseBody, response.headers);
        Log.info('� Stream upload completed: $videoId', name: 'StreamUploadService', category: LogCategory.system);
        return videoId;
      } else {
        throw Exception('Stream upload failed: HTTP ${response.statusCode} - $responseBody');
      }
      
    } catch (e) {
      Log.error('Stream direct upload error: $e', name: 'StreamUploadService', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Extract video ID from Cloudflare Stream response
  String _extractVideoIdFromResponse(String responseBody, Map<String, String> headers) {
    try {
      // Try to parse JSON response first
      final jsonResponse = jsonDecode(responseBody);
      if (jsonResponse is Map && jsonResponse.containsKey('result')) {
        final result = jsonResponse['result'];
        if (result is Map && result.containsKey('uid')) {
          return result['uid'] as String;
        }
      }
      
      // Fallback: extract from Location header or other headers
      final location = headers['location'];
      if (location != null) {
        final uri = Uri.parse(location);
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          return pathSegments.last;
        }
      }
      
      // Last resort: try to extract UID from response body
      final uidMatch = RegExp(r'"uid":\s*"([^"]+)"').firstMatch(responseBody);
      if (uidMatch != null) {
        return uidMatch.group(1)!;
      }
      
      throw Exception('Could not extract video ID from Stream response');
    } catch (e) {
      Log.error('Failed to extract video ID: $e', name: 'StreamUploadService', category: LogCategory.system);
      // Generate a fallback ID based on timestamp
      return 'video_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  /// Get video status from backend
  Future<StreamVideoStatus?> getVideoStatus(String videoId) async {
    Log.debug('Getting video status for: $videoId', name: 'StreamUploadService', category: LogCategory.system);
    
    try {
      final statusUrl = AppConfig.streamStatusUrl(videoId);
      final response = await _client.get(
        Uri.parse(statusUrl),
        headers: {
          'Authorization': await _getNip98Token(url: statusUrl, method: HttpMethod.get),
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return StreamVideoStatus.fromJson(data);
      } else if (response.statusCode == 404) {
        Log.warning('Video not found: $videoId', name: 'StreamUploadService', category: LogCategory.system);
        return null;
      } else {
        throw Exception('Status request failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      Log.error('Failed to get video status: $e', name: 'StreamUploadService', category: LogCategory.system);
      return null;
    }
  }
  
  /// Wait for video to be ready for streaming
  Future<StreamVideoStatus?> waitForVideoReady(
    String videoId, {
    Duration timeout = const Duration(minutes: 5),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    Log.debug('⏳ Waiting for video to be ready: $videoId', name: 'StreamUploadService', category: LogCategory.system);
    
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < timeout) {
      final status = await getVideoStatus(videoId);
      
      if (status == null) {
        throw Exception('Video not found: $videoId');
      }
      
      if (status.isReady) {
        Log.info('Video ready for streaming: $videoId', name: 'StreamUploadService', category: LogCategory.system);
        return status;
      }
      
      if (status.isFailed) {
        throw Exception('Video processing failed: ${status.error ?? 'Unknown error'}');
      }
      
      Log.debug('⏳ Video still processing (${status.status}), waiting...', name: 'StreamUploadService', category: LogCategory.system);
      await Future.delayed(pollInterval);
    }
    
    throw TimeoutException('Video processing timeout', timeout);
  }
  
  /// Generate NIP-98 authentication token for backend requests
  Future<String> _getNip98Token({String? url, HttpMethod method = HttpMethod.post}) async {
    if (_authService == null) {
      Log.warning('No authentication service available', name: 'StreamUploadService', category: LogCategory.system);
      throw Exception('Authentication service not available');
    }
    
    final targetUrl = url ?? AppConfig.streamUploadRequestUrl;
    final token = await _authService!.createAuthToken(
      url: targetUrl,
      method: method,
    );
    
    if (token == null) {
      Log.error('Failed to create NIP-98 token', name: 'StreamUploadService', category: LogCategory.system);
      throw Exception('Failed to create authentication token');
    }
    
    return token.token;
  }
  
  /// Cancel an ongoing upload
  Future<void> cancelUpload(String videoId) async {
    final controller = _progressControllers[videoId];
    if (controller != null) {
      _progressControllers.remove(videoId);
      await controller.close();
      Log.debug('Upload cancelled: $videoId', name: 'StreamUploadService', category: LogCategory.system);
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
  
  /// Test backend connectivity
  Future<bool> testConnection() async {
    try {
      Log.debug('� Testing Stream backend connection', name: 'StreamUploadService', category: LogCategory.system);
      
      final response = await _client.get(
        Uri.parse(AppConfig.healthUrl),
      ).timeout(const Duration(seconds: 10));
      
      final isHealthy = response.statusCode == 200;
      debugPrint(isHealthy ? '✅ Stream backend healthy' : '❌ Stream backend unhealthy');
      
      return isHealthy;
    } catch (e) {
      Log.error('Stream backend connection test failed: $e', name: 'StreamUploadService', category: LogCategory.system);
      return false;
    }
  }
  
  @override
  void dispose() {
    // Cancel all active uploads
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    _client.close();
    super.dispose();
  }
}

/// Exception thrown by StreamUploadService
class StreamUploadException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  const StreamUploadException(
    this.message, {
    this.code,
    this.originalError,
  });
  
  @override
  String toString() => 'StreamUploadException: $message';
}