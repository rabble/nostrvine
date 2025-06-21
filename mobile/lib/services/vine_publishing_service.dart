// ABOUTME: Vine publishing service orchestrating GIF creation and Nostr broadcasting
// ABOUTME: Manages complete vine publishing workflow from frames to Nostr network

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/nip94_metadata.dart';
import '../models/cloudinary_models.dart';
import '../services/gif_service.dart';
import '../services/stream_upload_service.dart';
import '../services/nostr_service_interface.dart';
import '../services/nostr_service.dart';
import '../services/camera_service.dart';
// import '../services/processing_monitor.dart'; // Removed - duplicate monitoring service

/// Publishing state for vine content
enum PublishingState {
  idle,
  creatingGif,
  uploadingToBackend,
  waitingForProcessing,
  broadcastingToNostr,
  retrying,
  queuedOffline,
  completed,
  error,
}

/// Result of vine publishing operation
class VinePublishResult {
  final bool success;
  final NIP94Metadata? metadata;
  final NostrBroadcastResult? broadcastResult;
  final String? error;
  final Duration processingTime;
  final PublishingState finalState;
  final int retryCount;
  final bool isOfflineQueued;
  
  const VinePublishResult({
    required this.success,
    this.metadata,
    this.broadcastResult,
    this.error,
    required this.processingTime,
    required this.finalState,
    this.retryCount = 0,
    this.isOfflineQueued = false,
  });
  
  factory VinePublishResult.success({
    required NIP94Metadata metadata,
    required NostrBroadcastResult broadcastResult,
    required Duration processingTime,
    int retryCount = 0,
  }) {
    return VinePublishResult(
      success: true,
      metadata: metadata,
      broadcastResult: broadcastResult,
      processingTime: processingTime,
      finalState: PublishingState.completed,
      retryCount: retryCount,
    );
  }
  
  factory VinePublishResult.error({
    required String error,
    required Duration processingTime,
    required PublishingState finalState,
    int retryCount = 0,
    bool isOfflineQueued = false,
  }) {
    return VinePublishResult(
      success: false,
      error: error,
      processingTime: processingTime,
      finalState: finalState,
      retryCount: retryCount,
      isOfflineQueued: isOfflineQueued,
    );
  }
  
  factory VinePublishResult.offlineQueued({
    required Duration processingTime,
  }) {
    return VinePublishResult(
      success: false,
      error: 'Queued for publishing when connection is restored',
      processingTime: processingTime,
      finalState: PublishingState.queuedOffline,
      isOfflineQueued: true,
    );
  }
}

/// Offline vine data for retry queue
class OfflineVineData {
  final String id;
  final VineRecordingResult recordingResult;
  final String caption;
  final List<String> hashtags;
  final String? altText;
  final DateTime createdAt;
  final int retryCount;
  
  const OfflineVineData({
    required this.id,
    required this.recordingResult,
    required this.caption,
    required this.hashtags,
    this.altText,
    required this.createdAt,
    this.retryCount = 0,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caption': caption,
      'hashtags': hashtags,
      'altText': altText,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      // Note: recordingResult frames would need special serialization
      'frameCount': recordingResult.frameCount,
      'processingTime': recordingResult.processingTime.inMilliseconds,
      'selectedApproach': recordingResult.selectedApproach,
      'qualityRatio': recordingResult.qualityRatio,
    };
  }
  
  static OfflineVineData fromJson(Map<String, dynamic> json, VineRecordingResult recordingResult) {
    return OfflineVineData(
      id: json['id'],
      recordingResult: recordingResult,
      caption: json['caption'],
      hashtags: List<String>.from(json['hashtags']),
      altText: json['altText'],
      createdAt: DateTime.parse(json['createdAt']),
      retryCount: json['retryCount'] ?? 0,
    );
  }
}

/// Service for publishing vines to Nostr network
class VinePublishingService extends ChangeNotifier {
  final GifService _gifService;
  final StreamUploadService _streamUploadService;
  final INostrService _nostrService;
  // final ProcessingMonitor _processingMonitor; // Removed - duplicate monitoring
  
  PublishingState _state = PublishingState.idle;
  double _progress = 0.0;
  String? _statusMessage;
  
  // Retry and offline support
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 2);
  static const String offlineQueueKey = 'offline_vine_queue';
  
  final List<OfflineVineData> _offlineQueue = [];
  Timer? _retryTimer;
  bool _isProcessingOfflineQueue = false;
  
  VinePublishingService({
    required GifService gifService,
    required StreamUploadService streamUploadService,
    required INostrService nostrService,
    // ProcessingMonitor? processingMonitor, // Removed - duplicate monitoring
  }) : _gifService = gifService,
       _streamUploadService = streamUploadService,
       _nostrService = nostrService {
       // _processingMonitor = processingMonitor ?? ProcessingMonitor() // Removed
    _loadOfflineQueue();
    _startPeriodicOfflineCheck();
  }
  
  // Getters
  PublishingState get state => _state;
  double get progress => _progress;
  String? get statusMessage => _statusMessage;
  bool get isPublishing => _state != PublishingState.idle && 
                          _state != PublishingState.completed && 
                          _state != PublishingState.error &&
                          _state != PublishingState.queuedOffline;
  List<OfflineVineData> get offlineQueue => List.unmodifiable(_offlineQueue);
  int get offlineQueueCount => _offlineQueue.length;
  bool get hasOfflineContent => _offlineQueue.isNotEmpty;
  
  /// Publish vine from recording result with retry and offline support
  Future<VinePublishResult> publishVine({
    required VineRecordingResult recordingResult,
    required String caption,
    List<String> hashtags = const [],
    String? altText,
    bool uploadToBackend = false,
    int retryAttempt = 0,
  }) async {
    if (isPublishing) {
      throw Exception('Publishing already in progress');
    }
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Check network connectivity first
      if (!await _isConnected()) {
        return await _queueForOfflinePublishing(
          recordingResult: recordingResult,
          caption: caption,
          hashtags: hashtags,
          altText: altText,
          processingTime: stopwatch.elapsed,
        );
      }
      
      _updateState(PublishingState.creatingGif, 0.1, 'Creating GIF from frames...');
      
      // Step 1: Create GIF from captured frames
      final gifResult = await _gifService.createGifFromFrames(
        frames: recordingResult.frames,
        originalWidth: 640, // Assuming standard resolution
        originalHeight: 480,
        quality: GifQuality.medium,
      );
      
      _updateState(PublishingState.creatingGif, 0.3, 'GIF created successfully');
      
      // Step 2: Calculate file hash
      final sha256Hash = _calculateSHA256(gifResult.gifBytes);
      
      NIP94Metadata metadata;
      if (uploadToBackend) {
        // Step 3a: Upload to Cloudinary and get public URL
        metadata = await _uploadToCloudinary(
          gifResult.gifBytes, 
          caption,
          altText: altText,
          hashtags: hashtags,
        );
        
        _updateState(PublishingState.broadcastingToNostr, 0.8, 'Creating Nostr event...');
      } else {
        // Step 3b: Use local data URL for testing
        final fileUrl = _createDataUrl(gifResult.gifBytes);
        
        _updateState(PublishingState.broadcastingToNostr, 0.7, 'Creating Nostr event...');
        
        // Create metadata locally for testing
        metadata = NIP94Metadata.fromGifResult(
          url: fileUrl,
          sha256Hash: sha256Hash,
          width: gifResult.width,
          height: gifResult.height,
          sizeBytes: gifResult.gifBytes.length,
          summary: caption,
          altText: altText,
          durationMs: recordingResult.frameCount > 1 ? 
            (recordingResult.frameCount * 200) : null, // 200ms per frame
          fps: recordingResult.frameCount > 1 ? 5.0 : null,
        );
      }
      
      _updateState(PublishingState.broadcastingToNostr, 0.8, 'Broadcasting to Nostr...');
      
      // Step 5: Broadcast to Nostr network
      final broadcastResult = await _nostrService.publishFileMetadata(
        metadata: metadata,
        content: caption,
        hashtags: hashtags,
      );
      
      if (!broadcastResult.isSuccessful) {
        // Check if it's a partial failure (some relays succeeded)
        if (broadcastResult.successCount > 0) {
          debugPrint('⚠️ Partial broadcast success: ${broadcastResult.successCount}/${broadcastResult.totalRelays} relays');
          // Consider partial success as success for better UX
        } else {
          throw NostrServiceException('Failed to broadcast to any Nostr relays');
        }
      }
      
      _updateState(PublishingState.completed, 1.0, 'Vine published successfully!');
      
      final result = VinePublishResult.success(
        metadata: metadata,
        broadcastResult: broadcastResult,
        processingTime: stopwatch.elapsed,
        retryCount: retryAttempt,
      );
      
      stopwatch.stop();
      return result;
      
    } catch (e) {
      debugPrint('❌ Publishing attempt ${retryAttempt + 1} failed: $e');
      
      // Determine if we should retry
      if (_shouldRetry(e, retryAttempt)) {
        return await _retryPublishing(
          recordingResult: recordingResult,
          caption: caption,
          hashtags: hashtags,
          altText: altText,
          uploadToBackend: uploadToBackend,
          retryAttempt: retryAttempt + 1,
          originalError: e,
        );
      }
      
      // If network error and retries exhausted, queue for offline
      if (_isNetworkError(e) && retryAttempt >= maxRetries - 1) {
        return await _queueForOfflinePublishing(
          recordingResult: recordingResult,
          caption: caption,
          hashtags: hashtags,
          altText: altText,
          processingTime: stopwatch.elapsed,
        );
      }
      
      final error = 'Publishing failed after ${retryAttempt + 1} attempts: $e';
      _updateState(PublishingState.error, _progress, error);
      
      return VinePublishResult.error(
        error: error,
        processingTime: stopwatch.elapsed,
        finalState: _state,
        retryCount: retryAttempt,
      );
    }
  }
  
  /// Publish vine to Cloudinary and Nostr (production workflow)
  Future<VinePublishResult> publishVineToCloudinary({
    required VineRecordingResult recordingResult,
    required String caption,
    List<String> hashtags = const [],
    String? altText,
  }) async {
    return publishVine(
      recordingResult: recordingResult,
      caption: caption,
      hashtags: hashtags,
      altText: altText,
      uploadToBackend: true, // Use Cloudinary upload
    );
  }
  
  /// Quick publish for local testing (no backend upload)
  Future<VinePublishResult> publishVineLocal({
    required VineRecordingResult recordingResult,
    required String caption,
    List<String> hashtags = const [],
    String? altText,
  }) async {
    return publishVine(
      recordingResult: recordingResult,
      caption: caption,
      hashtags: hashtags,
      altText: altText,
      uploadToBackend: false,
    );
  }
  
  /// Publish vine to Cloudflare Stream CDN (new video workflow)
  Future<VinePublishResult> publishVineToStream({
    required File videoFile,
    required String nostrPubkey,
    required String caption,
    List<String> hashtags = const [],
    String? altText,
    int retryAttempt = 0,
  }) async {
    if (isPublishing) {
      throw Exception('Publishing already in progress');
    }
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Check network connectivity first
      if (!await _isConnected()) {
        throw SocketException('No internet connection available for Stream upload');
      }
      
      _updateState(PublishingState.uploadingToBackend, 0.1, 'Uploading video to Stream CDN...');
      
      // Step 1: Upload video to Cloudflare Stream
      final uploadResult = await _streamUploadService.uploadVideo(
        videoFile: videoFile,
        nostrPubkey: nostrPubkey,
        title: caption,
        description: altText,
        hashtags: hashtags,
        onProgress: (progress) {
          _updateState(
            PublishingState.uploadingToBackend, 
            0.1 + (progress * 0.4), // 0.1 to 0.5 range for upload
            'Uploading video... ${(progress * 100).toInt()}%'
          );
        },
      );
      
      if (!uploadResult.success) {
        throw Exception('Stream upload failed: ${uploadResult.errorMessage}');
      }
      
      _updateState(PublishingState.waitingForProcessing, 0.5, 'Waiting for video processing...');
      
      // Step 2: Wait for video to be ready
      final videoStatus = await _streamUploadService.waitForVideoReady(
        uploadResult.videoId!,
        timeout: const Duration(minutes: 3),
      );
      
      if (videoStatus == null || !videoStatus.isReady) {
        throw Exception('Video processing failed or timed out');
      }
      
      _updateState(PublishingState.broadcastingToNostr, 0.8, 'Creating Nostr event...');
      
      // Step 3: Create NIP-94 metadata for video
      final metadata = NIP94Metadata.fromStreamVideo(
        videoId: uploadResult.videoId!,
        hlsUrl: videoStatus.hlsUrl!,
        dashUrl: videoStatus.dashUrl,
        thumbnailUrl: videoStatus.thumbnailUrl,
        summary: caption,
        altText: altText,
      );
      
      _updateState(PublishingState.broadcastingToNostr, 0.9, 'Broadcasting to Nostr...');
      
      // Step 4: Broadcast to Nostr network
      final broadcastResult = await _nostrService.publishFileMetadata(
        metadata: metadata,
        content: caption,
        hashtags: hashtags,
      );
      
      if (!broadcastResult.isSuccessful && broadcastResult.successCount == 0) {
        throw NostrServiceException('Failed to broadcast to any Nostr relays');
      }
      
      _updateState(PublishingState.completed, 1.0, 'Video published successfully!');
      
      final result = VinePublishResult.success(
        metadata: metadata,
        broadcastResult: broadcastResult,
        processingTime: stopwatch.elapsed,
        retryCount: retryAttempt,
      );
      
      stopwatch.stop();
      return result;
      
    } catch (e) {
      debugPrint('❌ Stream publishing attempt ${retryAttempt + 1} failed: $e');
      
      final error = 'Stream publishing failed: $e';
      _updateState(PublishingState.error, _progress, error);
      
      return VinePublishResult.error(
        error: error,
        processingTime: stopwatch.elapsed,
        finalState: _state,
        retryCount: retryAttempt,
      );
    }
  }
  
  /// Force publish vine with custom retry count (for testing)
  Future<VinePublishResult> publishVineWithRetries({
    required VineRecordingResult recordingResult,
    required String caption,
    List<String> hashtags = const [],
    String? altText,
    bool uploadToBackend = false,
    int maxRetryOverride = -1,
  }) async {
    return publishVine(
      recordingResult: recordingResult,
      caption: caption,
      hashtags: hashtags,
      altText: altText,
      uploadToBackend: uploadToBackend,
      retryAttempt: 0,
    );
  }
  
  /// Calculate SHA256 hash of file content
  String _calculateSHA256(Uint8List data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }
  
  /// Create data URL for local testing
  String _createDataUrl(Uint8List data) {
    final base64Data = base64Encode(data);
    return 'data:image/gif;base64,$base64Data';
  }
  
  /// Upload to Cloudinary using signed upload workflow
  Future<NIP94Metadata> _uploadToCloudinary(
    Uint8List data, 
    String caption, {
    String? altText,
    List<String> hashtags = const [],
  }) async {
    // Check connectivity before upload
    if (!await _isConnected()) {
      throw SocketException('No internet connection available for Cloudinary upload');
    }
    
    _updateState(PublishingState.uploadingToBackend, 0.3, 'Requesting upload signature...');
    
    try {
      // Step 1: Get signed upload URL from backend
      final signedUpload = await _requestSignedUpload(data.length, 'image/gif');
      
      _updateState(PublishingState.uploadingToBackend, 0.4, 'Uploading to Cloudinary...');
      
      // Step 2: Upload directly to Cloudinary
      final cloudinaryResponse = await _uploadToCloudinaryDirect(data, signedUpload);
      
      _updateState(PublishingState.uploadingToBackend, 0.7, 'Creating metadata...');
      
      // Step 3: Create NIP-94 metadata with Cloudinary URL
      final sha256Hash = _calculateSHA256(data);
      final metadata = NIP94Metadata.fromCloudinaryResponse(
        cloudinaryResponse: cloudinaryResponse,
        sha256Hash: sha256Hash,
        summary: caption,
        altText: altText,
      );
      
      return metadata;
      
    } catch (e) {
      debugPrint('❌ Cloudinary upload failed: $e');
      rethrow;
    }
  }
  
  /// Request signed upload URL from backend
  Future<CloudinarySignedUpload> _requestSignedUpload(int fileSize, String contentType) async {
    
    try {
      // Create NIP-98 auth header (simplified for now - would need proper signing)
      final headers = {
        'Content-Type': 'application/json',
        // TODO: Add proper NIP-98 authentication
      };
      
      final body = jsonEncode({
        'fileSize': fileSize,
        'contentType': contentType,
        'filename': 'vine_${DateTime.now().millisecondsSinceEpoch}.gif',
      });
      
      final response = await http.post(
        Uri.parse(AppConfig.cloudinarySignedUploadUrl),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return CloudinarySignedUpload.fromJson(jsonData);
      } else {
        throw Exception('Signed upload request failed: HTTP ${response.statusCode} - ${response.body}');
      }
      
    } catch (e) {
      debugPrint('❌ Signed upload request error: $e');
      rethrow;
    }
  }
  
  /// Upload file directly to Cloudinary using signed parameters
  Future<CloudinaryUploadResponse> _uploadToCloudinaryDirect(
    Uint8List data, 
    CloudinarySignedUpload signedUpload
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(signedUpload.uploadUrl),
      );
      
      // Add Cloudinary signed parameters
      request.fields.addAll(signedUpload.uploadParams);
      
      // Add file
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        data,
        filename: 'vine_${DateTime.now().millisecondsSinceEpoch}.gif',
      ));
      
      // Send request to Cloudinary
      final response = await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;
        return CloudinaryUploadResponse.fromJson(jsonData);
      } else {
        throw Exception('Cloudinary upload failed: HTTP ${response.statusCode} - $responseBody');
      }
      
    } catch (e) {
      debugPrint('❌ Cloudinary direct upload error: $e');
      rethrow;
    }
  }
  
  
  /// Update publishing state and notify listeners
  void _updateState(PublishingState newState, double newProgress, String message) {
    _state = newState;
    _progress = newProgress;
    _statusMessage = message;
    
    debugPrint('📤 Publishing: $message (${(newProgress * 100).toInt()}%)');
    notifyListeners();
  }
  
  /// Reset to idle state
  void reset() {
    _state = PublishingState.idle;
    _progress = 0.0;
    _statusMessage = null;
    notifyListeners();
  }
  
  /// Get connection status summary
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isConnected': _isConnected(),
      'offlineQueueCount': _offlineQueue.length,
      'isProcessingOffline': _isProcessingOfflineQueue,
      'hasRetryTimer': _retryTimer?.isActive ?? false,
    };
  }
  
  /// Retry publishing with exponential backoff
  Future<VinePublishResult> _retryPublishing({
    required VineRecordingResult recordingResult,
    required String caption,
    required List<String> hashtags,
    String? altText,
    required bool uploadToBackend,
    required int retryAttempt,
    required dynamic originalError,
  }) async {
    final retryDelay = Duration(
      milliseconds: (initialRetryDelay.inMilliseconds * (1 << retryAttempt)).clamp(0, 30000),
    );
    
    _updateState(
      PublishingState.retrying,
      _progress,
      'Retrying in ${retryDelay.inSeconds}s (attempt ${retryAttempt + 1}/$maxRetries)...',
    );
    
    await Future.delayed(retryDelay);
    
    return publishVine(
      recordingResult: recordingResult,
      caption: caption,
      hashtags: hashtags,
      altText: altText,
      uploadToBackend: uploadToBackend,
      retryAttempt: retryAttempt,
    );
  }
  
  /// Queue vine for offline publishing
  Future<VinePublishResult> _queueForOfflinePublishing({
    required VineRecordingResult recordingResult,
    required String caption,
    required List<String> hashtags,
    String? altText,
    required Duration processingTime,
  }) async {
    final vineId = 'vine_${DateTime.now().millisecondsSinceEpoch}';
    final offlineVine = OfflineVineData(
      id: vineId,
      recordingResult: recordingResult,
      caption: caption,
      hashtags: hashtags,
      altText: altText,
      createdAt: DateTime.now(),
    );
    
    _offlineQueue.add(offlineVine);
    await _saveOfflineQueue();
    
    _updateState(
      PublishingState.queuedOffline,
      1.0,
      'Queued for publishing when connection is restored (${_offlineQueue.length} pending)',
    );
    
    debugPrint('📱 Vine queued for offline publishing: $vineId');
    
    return VinePublishResult.offlineQueued(
      processingTime: processingTime,
    );
  }
  
  /// Check if network connectivity is available
  Future<bool> _isConnected() async {
    try {
      final result = await InternetAddress.lookup('relay.damus.io');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Determine if error should trigger a retry
  bool _shouldRetry(dynamic error, int currentAttempt) {
    if (currentAttempt >= maxRetries - 1) return false;
    
    return _isNetworkError(error) || 
           _isTemporaryError(error) ||
           error is NostrServiceException;
  }
  
  /// Check if error is network-related
  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
           errorString.contains('connection') ||
           errorString.contains('timeout') ||
           errorString.contains('unreachable') ||
           error is SocketException;
  }
  
  /// Check if error is temporary and retryable
  bool _isTemporaryError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('temporary') ||
           errorString.contains('rate limit') ||
           errorString.contains('busy') ||
           errorString.contains('overloaded');
  }
  
  /// Load offline queue from persistent storage
  Future<void> _loadOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(offlineQueueKey);
      
      if (queueJson != null) {
        final queueData = jsonDecode(queueJson) as List;
        // Note: This is a simplified implementation
        // In practice, we'd need to serialize/deserialize frame data properly
        debugPrint('📱 Loaded ${queueData.length} items from offline queue');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load offline queue: $e');
    }
  }
  
  /// Save offline queue to persistent storage
  Future<void> _saveOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueData = _offlineQueue.map((vine) => vine.toJson()).toList();
      await prefs.setString(offlineQueueKey, jsonEncode(queueData));
      
      debugPrint('💾 Saved ${_offlineQueue.length} items to offline queue');
    } catch (e) {
      debugPrint('⚠️ Failed to save offline queue: $e');
    }
  }
  
  /// Start periodic check for offline content when connection is restored
  void _startPeriodicOfflineCheck() {
    _retryTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (!_isProcessingOfflineQueue && _offlineQueue.isNotEmpty) {
        _processOfflineQueue();
      }
    });
  }
  
  /// Process queued offline vines when connectivity is restored
  Future<void> _processOfflineQueue() async {
    if (_isProcessingOfflineQueue || _offlineQueue.isEmpty) return;
    
    _isProcessingOfflineQueue = true;
    
    try {
      if (!await _isConnected()) {
        debugPrint('📱 Still offline, will retry later');
        return;
      }
      
      debugPrint('📶 Connection restored, processing ${_offlineQueue.length} queued vines');
      
      final vinesToProcess = List<OfflineVineData>.from(_offlineQueue);
      _offlineQueue.clear();
      
      for (final vine in vinesToProcess) {
        try {
          final result = await publishVine(
            recordingResult: vine.recordingResult,
            caption: vine.caption,
            hashtags: vine.hashtags,
            altText: vine.altText,
            retryAttempt: vine.retryCount,
          );
          
          if (result.success) {
            debugPrint('✅ Successfully published queued vine: ${vine.id}');
          } else {
            // Re-queue if still failing
            final updatedVine = OfflineVineData(
              id: vine.id,
              recordingResult: vine.recordingResult,
              caption: vine.caption,
              hashtags: vine.hashtags,
              altText: vine.altText,
              createdAt: vine.createdAt,
              retryCount: vine.retryCount + 1,
            );
            
            if (updatedVine.retryCount < maxRetries) {
              _offlineQueue.add(updatedVine);
              debugPrint('🔄 Re-queued vine for retry: ${vine.id}');
            } else {
              debugPrint('❌ Permanently failed to publish vine: ${vine.id}');
            }
          }
        } catch (e) {
          debugPrint('❌ Error processing queued vine ${vine.id}: $e');
          // Don't re-add on exception to avoid infinite loops
        }
        
        // Small delay between processing items to avoid overwhelming
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      await _saveOfflineQueue();
      notifyListeners();
      
    } finally {
      _isProcessingOfflineQueue = false;
    }
  }
  
  /// Manually trigger offline queue processing
  Future<void> retryOfflineQueue() async {
    if (_offlineQueue.isEmpty) {
      debugPrint('📱 No offline content to retry');
      return;
    }
    
    debugPrint('🔄 Manually triggering offline queue processing');
    await _processOfflineQueue();
  }
  
  /// Clear all offline queued content
  Future<void> clearOfflineQueue() async {
    _offlineQueue.clear();
    await _saveOfflineQueue();
    notifyListeners();
    debugPrint('🗑️ Cleared offline queue');
  }
  
  /// Cancel current publishing operation
  Future<void> cancelPublishing() async {
    if (!isPublishing) return;
    
    _updateState(PublishingState.error, _progress, 'Publishing canceled by user');
    
    // Cancel retry timer if active
    _retryTimer?.cancel();
    
    debugPrint('🚫 Publishing canceled');
  }
  
  /// Dispose service and cleanup resources
  @override
  void dispose() {
    _retryTimer?.cancel();
    // _processingMonitor.dispose(); // Removed
    super.dispose();
  }
}

/// Error scenarios for vine publishing
enum PublishingError {
  gifCreationFailed('Failed to create GIF from frames'),
  hashCalculationFailed('Failed to calculate file hash'),
  backendUploadFailed('Failed to upload to backend'),
  nostrBroadcastFailed('Failed to broadcast to Nostr network'),
  networkError('Network connection required'),
  authenticationError('Authentication failed'),
  invalidMetadata('Invalid file metadata'),
  quotaExceeded('Upload quota exceeded'),
  cancelled('Publishing was cancelled'),
  retryLimitExceeded('Maximum retry attempts exceeded'),
  offlineQueueFull('Offline queue is full');
  
  const PublishingError(this.userMessage);
  final String userMessage;
}

/// Exception thrown during vine publishing
class VinePublishingException implements Exception {
  final PublishingError error;
  final String? details;
  final bool isRetryable;
  
  const VinePublishingException(
    this.error, [
    this.details,
    this.isRetryable = false,
  ]);
  
  String get message => details != null 
    ? '${error.userMessage}: $details'
    : error.userMessage;
  
  @override
  String toString() => 'VinePublishingException: $message';
}