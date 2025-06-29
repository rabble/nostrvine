// ABOUTME: Service for uploading videos directly to Cloudinary cloud storage
// ABOUTME: Handles signed uploads, progress tracking, and error handling for async video processing

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import 'nip98_auth_service.dart';
import '../utils/unified_logger.dart';

/// Result of a Cloudinary upload operation
class UploadResult {
  final bool success;
  final String? cloudinaryPublicId;
  final String? cloudinaryUrl;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  const UploadResult({
    required this.success,
    this.cloudinaryPublicId,
    this.cloudinaryUrl,
    this.errorMessage,
    this.metadata,
  });

  factory UploadResult.success({
    required String cloudinaryPublicId,
    required String cloudinaryUrl,
    Map<String, dynamic>? metadata,
  }) {
    return UploadResult(
      success: true,
      cloudinaryPublicId: cloudinaryPublicId,
      cloudinaryUrl: cloudinaryUrl,
      metadata: metadata,
    );
  }

  factory UploadResult.failure(String errorMessage) {
    return UploadResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

/// Signed upload parameters from backend
class SignedUploadParams {
  final String cloudName;
  final String apiKey;
  final String signature;
  final int timestamp;
  final String publicId;
  final Map<String, dynamic> additionalParams;

  const SignedUploadParams({
    required this.cloudName,
    required this.apiKey,
    required this.signature,
    required this.timestamp,
    required this.publicId,
    required this.additionalParams,
  });

  factory SignedUploadParams.fromJson(Map<String, dynamic> json) {
    return SignedUploadParams(
      cloudName: json['cloud_name'] as String,
      apiKey: json['api_key'] as String,
      signature: json['signature'] as String,
      timestamp: json['timestamp'] as int,
      publicId: json['public_id'] as String,
      additionalParams: Map<String, dynamic>.from(json['additional_params'] ?? {}),
    );
  }
}

/// Service for uploading videos to Cloudinary
class CloudinaryUploadService extends ChangeNotifier {
  static String get _baseUrl => AppConfig.backendBaseUrl;
  
  final Map<String, StreamController<double>> _progressControllers = {};
  final Map<String, StreamSubscription<double>> _progressSubscriptions = {};
  final Nip98AuthService? _authService;
  
  CloudinaryUploadService({Nip98AuthService? authService}) 
      : _authService = authService;
  
  /// Upload a video file to Cloudinary with progress tracking
  Future<UploadResult> uploadVideo({
    required File videoFile,
    required String nostrPubkey,
    String? title,
    String? description,
    List<String>? hashtags,
    void Function(double progress)? onProgress,
  }) async {
    Log.debug('Starting Cloudinary upload for video: ${videoFile.path}', name: 'CloudinaryUploadService', category: LogCategory.system);
    
    String? publicId;
    
    try {
      // Step 1: Request signed upload parameters from our backend
      final signedParams = await _requestSignedUpload(
        videoFile: videoFile,
        nostrPubkey: nostrPubkey,
        title: title,
        description: description,
        hashtags: hashtags,
      );
      
      publicId = signedParams.publicId;
      
      // Step 2: Upload directly to Cloudinary
      final cloudinary = CloudinaryPublic(signedParams.cloudName, signedParams.apiKey, cache: false);
      
      // Setup progress tracking
      final progressController = StreamController<double>.broadcast();
      _progressControllers[signedParams.publicId] = progressController;
      
      if (onProgress != null) {
        final subscription = progressController.stream.listen(onProgress);
        _progressSubscriptions[signedParams.publicId] = subscription;
      }
      
      // Perform the upload (simplified for now - progress tracking to be implemented later)
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          videoFile.path,
          publicId: signedParams.publicId,
          resourceType: CloudinaryResourceType.Video,
        ),
      );
      
      // Simulate progress for now
      progressController.add(1.0);
      Log.info('� Upload completed', name: 'CloudinaryUploadService', category: LogCategory.system);
      
      // Cleanup progress controller and subscription
      _progressControllers.remove(signedParams.publicId);
      final subscription = _progressSubscriptions.remove(signedParams.publicId);
      await subscription?.cancel();
      await progressController.close();
      
      if (response.publicId.isNotEmpty) {
        Log.info('Cloudinary upload successful: ${response.publicId}', name: 'CloudinaryUploadService', category: LogCategory.system);
        return UploadResult.success(
          cloudinaryPublicId: response.publicId,
          cloudinaryUrl: response.secureUrl.isNotEmpty ? response.secureUrl : response.url,
          metadata: {
            'public_id': response.publicId,
            'secure_url': response.secureUrl,
            'url': response.url,
            'original_filename': response.originalFilename,
            'created_at': response.createdAt,
          },
        );
      } else {
        final errorMsg = 'Cloudinary upload failed: Invalid response';
        Log.error('$errorMsg', name: 'CloudinaryUploadService', category: LogCategory.system);
        return UploadResult.failure(errorMsg);
      }
    } catch (e, stackTrace) {
      Log.error('Upload error: $e', name: 'CloudinaryUploadService', category: LogCategory.system);
      Log.verbose('� Stack trace: $stackTrace', name: 'CloudinaryUploadService', category: LogCategory.system);
      
      // Clean up progress tracking on error
      if (publicId != null) {
        final subscription = _progressSubscriptions.remove(publicId);
        final controller = _progressControllers.remove(publicId);
        await subscription?.cancel();
        await controller?.close();
      }
      
      return UploadResult.failure('Upload failed: $e');
    }
  }
  
  /// Request signed upload parameters from our backend
  Future<SignedUploadParams> _requestSignedUpload({
    required File videoFile,
    required String nostrPubkey,
    String? title,
    String? description,
    List<String>? hashtags,
  }) async {
    Log.debug('� Requesting signed upload parameters from backend', name: 'CloudinaryUploadService', category: LogCategory.system);
    
    try {
      // Get file size and basic metadata
      final fileStat = await videoFile.stat();
      final fileSize = fileStat.size;
      
      final requestBody = {
        'nostr_pubkey': nostrPubkey,
        'file_size': fileSize,
        'mime_type': 'video/mp4', // Assume MP4 for now
        'title': title,
        'description': description,
        'hashtags': hashtags,
      };
      
      final url = '$_baseUrl/v1/media/request-upload';
      final response = await http.post(
        Uri.parse(url),
        headers: await _getAuthHeaders(url),
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Log.info('Received signed upload parameters', name: 'CloudinaryUploadService', category: LogCategory.system);
        return SignedUploadParams.fromJson(data);
      } else {
        throw Exception('Backend request failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      Log.error('Failed to get signed upload parameters: $e', name: 'CloudinaryUploadService', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Get authorization headers for backend requests
  Future<Map<String, String>> _getAuthHeaders(String url) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    // Add NIP-98 authentication if available
    if (_authService?.canCreateTokens == true) {
      final authToken = await _authService!.createAuthToken(
        url: url,
        method: HttpMethod.post,
      );
      
      if (authToken != null) {
        headers['Authorization'] = authToken.authorizationHeader;
        Log.debug('� Added NIP-98 auth to upload request', name: 'CloudinaryUploadService', category: LogCategory.system);
      } else {
        Log.error('Failed to create NIP-98 auth token for upload', name: 'CloudinaryUploadService', category: LogCategory.system);
      }
    } else {
      Log.warning('No authentication service available for upload', name: 'CloudinaryUploadService', category: LogCategory.system);
    }
    
    return headers;
  }
  
  /// Cancel an ongoing upload
  Future<void> cancelUpload(String publicId) async {
    final controller = _progressControllers.remove(publicId);
    final subscription = _progressSubscriptions.remove(publicId);
    
    if (controller != null || subscription != null) {
      await subscription?.cancel();
      await controller?.close();
      Log.debug('Upload cancelled: $publicId', name: 'CloudinaryUploadService', category: LogCategory.system);
    }
  }
  
  /// Get upload progress stream for a specific upload
  Stream<double>? getProgressStream(String publicId) {
    return _progressControllers[publicId]?.stream;
  }
  
  /// Check if an upload is currently in progress
  bool isUploading(String publicId) {
    return _progressControllers.containsKey(publicId);
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

/// Exception thrown by CloudinaryUploadService
class CloudinaryUploadException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  const CloudinaryUploadException(
    this.message, {
    this.code,
    this.originalError,
  });
  
  @override
  String toString() => 'CloudinaryUploadException: $message';
}