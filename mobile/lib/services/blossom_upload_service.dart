// ABOUTME: Service for uploading videos to user-configured Blossom media servers
// ABOUTME: Supports Blossom BUD-01 authentication and returns media URLs from any Blossom server

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:image_metadata_stripper/image_metadata_stripper.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/blossom_resumable_upload_session.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/utils/hash_util.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result type for Blossom upload operations
class BlossomUploadResult {
  final bool success;
  final String? videoId; // SHA-256 hash
  final String? url; // Primary HLS URL from server
  final String? fallbackUrl; // R2 MP4 URL (always available immediately)
  final String? streamingMp4Url; // BunnyStream MP4 URL (may be processing)
  final String? streamingHlsUrl; // BunnyStream HLS URL (same as url)
  final String? thumbnailUrl; // Auto-generated thumbnail
  final String? streamingStatus; // "processing" or "ready"
  final String? gifUrl; // Deprecated - keeping for backwards compatibility
  final String? blurhash; // Deprecated - keeping for backwards compatibility
  final String? errorMessage;

  // Convenience getter for backwards compatibility
  String? get cdnUrl => fallbackUrl ?? url;

  const BlossomUploadResult({
    required this.success,
    this.videoId,
    this.url,
    this.fallbackUrl,
    this.streamingMp4Url,
    this.streamingHlsUrl,
    this.thumbnailUrl,
    this.streamingStatus,
    this.gifUrl,
    this.blurhash,
    this.errorMessage,
  });
}

/// Result type for Blossom server health checks
class BlossomHealthCheckResult {
  final bool isReachable;
  final int? latencyMs;
  final int? statusCode;
  final String? serverUrl;
  final String? errorMessage;

  const BlossomHealthCheckResult({
    required this.isReachable,
    this.latencyMs,
    this.statusCode,
    this.serverUrl,
    this.errorMessage,
  });

  @override
  String toString() {
    if (isReachable) {
      return 'OK (${latencyMs}ms)';
    } else {
      return 'FAILED: ${errorMessage ?? "Unknown error"}';
    }
  }
}

class BlossomResumableUploadException implements Exception {
  const BlossomResumableUploadException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class _DivineUploadCapability {
  const _DivineUploadCapability({
    required this.supportsResumable,
    this.controlHost,
    this.dataHost,
  });

  final bool supportsResumable;
  final String? controlHost;
  final String? dataHost;
}

class BlossomUploadService {
  static const String _blossomServerKey = 'blossom_server_url';
  static const String _useBlossomKey = 'use_blossom_upload';
  static const String defaultBlossomServer = 'https://media.divine.video';

  final AuthService authService;
  final Dio dio;
  final String _defaultServerUrl;

  BlossomUploadService({
    required this.authService,
    Dio? dio,
    String? defaultServerUrl,
  }) : dio = dio ?? Dio(),
       _defaultServerUrl = defaultServerUrl ?? defaultBlossomServer;

  /// Determine which Blossom server to use for upload
  ///
  /// Priority order:
  /// 1. Custom configured server (if enabled in settings)
  /// 2. Default Divine media server
  Future<List<String>> _getServerUrlsForUpload() async {
    final servers = <String>[];

    // 1. Check for custom configured server
    final isCustomServerEnabled = await isBlossomEnabled();
    if (isCustomServerEnabled) {
      final customServerUrl = await getBlossomServer();
      if (customServerUrl != null && customServerUrl.isNotEmpty) {
        servers.add(customServerUrl);
        Log.info(
          '🔧 Using custom configured server: $customServerUrl',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
      }
    }

    // 2. Always add default Divine server as fallback
    if (!servers.contains(_defaultServerUrl)) {
      servers.add(_defaultServerUrl);
    }

    return servers;
  }

  /// Get the configured Blossom server URL
  Future<String?> getBlossomServer() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_blossomServerKey);
    // If nothing is stored or empty string, return default.
    if (stored == null || stored.isEmpty) return defaultBlossomServer;
    return stored;
  }

  /// Set the Blossom server URL
  Future<void> setBlossomServer(String? serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (serverUrl != null && serverUrl.isNotEmpty) {
      await prefs.setString(_blossomServerKey, serverUrl);
    } else {
      // Store empty string to indicate "no server configured"
      await prefs.setString(_blossomServerKey, '');
    }
  }

  /// Check if custom Blossom server is enabled
  /// When false (default), uploads go to Divine's Blossom server
  /// When true, uploads go to the user's custom configured server
  Future<bool> isBlossomEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useBlossomKey) ??
        true; // Default to true for new installs (allow custom/non-Divine media servers)
  }

  /// Enable or disable Blossom upload
  Future<void> setBlossomEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useBlossomKey, enabled);
  }

  /// Create a Blossom authentication event for upload
  Future<Event?> _createBlossomAuthEvent({
    required String url,
    required String method,
    required String fileHash,
    required int fileSize,
    String contentDescription = 'Upload video to Blossom server',
  }) async {
    try {
      // Blossom requires these tags (BUD-01):
      // - t: "upload" to indicate upload request
      // - expiration: Unix timestamp when auth expires
      // - x: SHA-256 hash of the file (optional but recommended)

      final now = DateTime.now();
      final expiration = now.add(
        const Duration(minutes: 5),
      ); // 5 minute expiration
      final expirationTimestamp = expiration.millisecondsSinceEpoch ~/ 1000;

      // Build tags for Blossom auth event (kind 24242)
      final tags = [
        ['t', 'upload'],
        ['expiration', expirationTimestamp.toString()],
        ['size', fileSize.toString()], // File size for server validation
        ['x', fileHash], // SHA-256 hash of the file
      ];

      // Use AuthService to create and sign the event (established pattern)
      final signedEvent = await authService.createAndSignEvent(
        kind: 24242, // Blossom auth event kind
        content: contentDescription,
        tags: tags,
      );

      if (signedEvent == null) {
        Log.error(
          'Failed to create/sign Blossom auth event via AuthService',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        'Created Blossom auth event: ${signedEvent.id}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event kind: ${signedEvent.kind}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event pubkey: ${signedEvent.pubkey}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event created_at: ${signedEvent.createdAt}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event tags: ${signedEvent.tags}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return signedEvent;
    } catch (e) {
      Log.error(
        'Error creating Blossom auth event: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  String _buildAuthHeader(Event authEvent) {
    final authEventJson = jsonEncode(authEvent.toJson());
    return 'Nostr ${base64.encode(utf8.encode(authEventJson))}';
  }

  Future<String?> _createBlossomAuthHeader({
    required String url,
    required String method,
    required String fileHash,
    required int fileSize,
    required String contentDescription,
  }) async {
    final authEvent = await _createBlossomAuthEvent(
      url: url,
      method: method,
      fileHash: fileHash,
      fileSize: fileSize,
      contentDescription: contentDescription,
    );
    if (authEvent == null) {
      return null;
    }

    return _buildAuthHeader(authEvent);
  }

  bool _validateHttpStatus(int? statusCode) =>
      statusCode != null && statusCode < 500;

  Map<String, String>? _parseRequiredHeaders(dynamic headersData) {
    if (headersData is! Map) {
      return null;
    }

    return headersData.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  DateTime? _parseDateTimeValue(dynamic rawValue) {
    final value = rawValue?.toString();
    if (value == null || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  int? _parseUploadOffset(Headers headers) {
    final rawOffset =
        headers.value('Upload-Offset') ?? headers.value('upload-offset');
    return rawOffset == null ? null : int.tryParse(rawOffset);
  }

  DateTime? _parseUploadExpiresAt(Headers headers) => _parseDateTimeValue(
    headers.value('Upload-Expires-At') ?? headers.value('upload-expires-at'),
  );

  Future<_DivineUploadCapability> _fetchDivineUploadCapability(
    String serverUrl,
  ) async {
    try {
      final response = await dio.head(
        '$serverUrl/upload',
        options: Options(
          validateStatus: _validateHttpStatus,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final extensionsHeader =
          response.headers.value('X-Divine-Upload-Extensions') ??
          response.headers.value('x-divine-upload-extensions');
      final supportsResumable =
          extensionsHeader
              ?.split(',')
              .map((value) => value.trim().toLowerCase())
              .contains('resumable-sessions') ??
          false;

      return _DivineUploadCapability(
        supportsResumable: supportsResumable,
        controlHost:
            response.headers.value('X-Divine-Upload-Control-Host') ??
            response.headers.value('x-divine-upload-control-host'),
        dataHost:
            response.headers.value('X-Divine-Upload-Data-Host') ??
            response.headers.value('x-divine-upload-data-host'),
      );
    } on DioException catch (error) {
      Log.warning(
        'Capability discovery failed for $serverUrl: ${error.message}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return const _DivineUploadCapability(supportsResumable: false);
    }
  }

  Future<BlossomResumableUploadSession> _initResumableUpload({
    required String serverUrl,
    required String fileHash,
    required int fileSize,
    required String contentType,
    required String fileName,
  }) async {
    final authHeader = await _createBlossomAuthHeader(
      url: '$serverUrl/upload/init',
      method: 'POST',
      fileHash: fileHash,
      fileSize: fileSize,
      contentDescription: 'Initialize resumable Blossom upload',
    );
    if (authHeader == null) {
      throw const BlossomResumableUploadException(
        'Failed to create Blossom authentication for resumable upload init',
      );
    }

    final response = await dio.post(
      '$serverUrl/upload/init',
      data: {
        'sha256': fileHash,
        'size': fileSize,
        'contentType': contentType,
        'fileName': fileName,
      },
      options: Options(
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        validateStatus: _validateHttpStatus,
      ),
    );

    final responseData = response.data;
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        responseData is! Map) {
      throw BlossomResumableUploadException(
        'Failed to initialize resumable upload: ${response.statusCode} ${response.data}',
        statusCode: response.statusCode,
      );
    }

    final uploadId = responseData['uploadId']?.toString();
    final uploadUrl = responseData['uploadUrl']?.toString();
    final chunkSize = (responseData['chunkSize'] as num?)?.toInt();
    final nextOffset = (responseData['nextOffset'] as num?)?.toInt() ?? 0;

    if (uploadId == null ||
        uploadId.isEmpty ||
        uploadUrl == null ||
        uploadUrl.isEmpty ||
        chunkSize == null ||
        chunkSize <= 0) {
      throw const BlossomResumableUploadException(
        'Resumable upload init response is missing required fields',
      );
    }

    return BlossomResumableUploadSession(
      uploadId: uploadId,
      uploadUrl: uploadUrl,
      chunkSize: chunkSize,
      nextOffset: nextOffset,
      expiresAt: _parseDateTimeValue(responseData['expiresAt']),
      requiredHeaders: _parseRequiredHeaders(responseData['requiredHeaders']),
    );
  }

  Future<BlossomResumableUploadSession> _queryResumableUploadSession(
    BlossomResumableUploadSession session,
  ) async {
    final response = await dio.head(
      session.uploadUrl,
      options: Options(
        headers: session.requiredHeaders,
        validateStatus: _validateHttpStatus,
      ),
    );

    if (response.statusCode == 404 || response.statusCode == 410) {
      throw BlossomResumableUploadException(
        'Resumable upload session is no longer available',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw BlossomResumableUploadException(
        'Failed to query resumable upload session: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    return session.copyWith(
      nextOffset: _parseUploadOffset(response.headers) ?? session.nextOffset,
      expiresAt: _parseUploadExpiresAt(response.headers) ?? session.expiresAt,
    );
  }

  Future<BlossomResumableUploadSession> _uploadChunks({
    required BlossomResumableUploadSession session,
    required File file,
    required int fileSize,
    void Function(double)? onProgress,
    void Function(BlossomResumableUploadSession)? onResumableSessionUpdated,
  }) async {
    var currentSession = session;
    final fileReader = await file.open();

    try {
      while (currentSession.nextOffset < fileSize) {
        final start = currentSession.nextOffset;
        final endExclusive = math.min(
          start + currentSession.chunkSize,
          fileSize,
        );
        final chunkLength = endExclusive - start;

        await fileReader.setPosition(start);
        final chunkBytes = await fileReader.read(chunkLength);

        final response = await dio.put(
          currentSession.uploadUrl,
          data: chunkBytes,
          options: Options(
            headers: {
              'Content-Type': 'application/octet-stream',
              'Content-Length': chunkLength.toString(),
              'Content-Range': 'bytes $start-${endExclusive - 1}/$fileSize',
              ...?currentSession.requiredHeaders,
            },
            validateStatus: _validateHttpStatus,
          ),
          onSendProgress: (sent, total) {
            if (fileSize <= 0) {
              return;
            }
            final progress = 0.2 + ((start + sent) / fileSize) * 0.7;
            onProgress?.call(progress.clamp(0.2, 0.9));
          },
        );

        if (response.statusCode == 404 || response.statusCode == 410) {
          throw BlossomResumableUploadException(
            'Resumable upload session expired during chunk upload',
            statusCode: response.statusCode,
          );
        }
        if (response.statusCode != 200 &&
            response.statusCode != 201 &&
            response.statusCode != 204) {
          final xReason =
              response.headers.value('X-Reason') ??
              response.headers.value('x-reason');
          throw BlossomResumableUploadException(
            'Chunk upload failed: ${response.statusCode} ${xReason ?? response.data}',
            statusCode: response.statusCode,
          );
        }

        currentSession = currentSession.copyWith(
          nextOffset: _parseUploadOffset(response.headers) ?? endExclusive,
          expiresAt:
              _parseUploadExpiresAt(response.headers) ??
              currentSession.expiresAt,
        );
        onResumableSessionUpdated?.call(currentSession);
      }

      return currentSession;
    } finally {
      await fileReader.close();
    }
  }

  Future<BlossomUploadResult> _completeResumableUpload({
    required String serverUrl,
    required BlossomResumableUploadSession session,
    required String fileHash,
    required int fileSize,
    void Function(double)? onProgress,
  }) async {
    final authHeader = await _createBlossomAuthHeader(
      url: '$serverUrl/upload/${session.uploadId}/complete',
      method: 'POST',
      fileHash: fileHash,
      fileSize: fileSize,
      contentDescription: 'Complete resumable Blossom upload',
    );
    if (authHeader == null) {
      throw const BlossomResumableUploadException(
        'Failed to create Blossom authentication for resumable upload completion',
      );
    }

    final response = await dio.post(
      '$serverUrl/upload/${session.uploadId}/complete',
      data: const {},
      options: Options(
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        validateStatus: _validateHttpStatus,
      ),
    );

    return _parseUploadResponse(
      response,
      fileHash: fileHash,
      onProgress: onProgress,
    );
  }

  Future<BlossomUploadResult> _uploadToServerResumable({
    required String serverUrl,
    required File file,
    required String fileHash,
    required int fileSize,
    required String contentType,
    BlossomResumableUploadSession? resumableSession,
    void Function(double)? onProgress,
    void Function(BlossomResumableUploadSession)? onResumableSessionUpdated,
  }) async {
    final initialSession = resumableSession == null
        ? await _initResumableUpload(
            serverUrl: serverUrl,
            fileHash: fileHash,
            fileSize: fileSize,
            contentType: contentType,
            fileName: file.uri.pathSegments.isEmpty
                ? 'upload.bin'
                : file.uri.pathSegments.last,
          )
        : await _queryResumableUploadSession(resumableSession);
    onResumableSessionUpdated?.call(initialSession);

    final uploadedSession = await _uploadChunks(
      session: initialSession,
      file: file,
      fileSize: fileSize,
      onProgress: onProgress,
      onResumableSessionUpdated: onResumableSessionUpdated,
    );

    return _completeResumableUpload(
      serverUrl: serverUrl,
      session: uploadedSession,
      fileHash: fileHash,
      fileSize: fileSize,
      onProgress: onProgress,
    );
  }

  BlossomUploadResult _parseUploadResponse(
    Response<dynamic> response, {
    required String fileHash,
    void Function(double)? onProgress,
  }) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = response.data;

      Log.debug(
        'Server response data type: ${responseData.runtimeType}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.debug(
        'Server response data: $responseData',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      if (responseData is Map) {
        final url = responseData['url']?.toString();
        final fallbackUrl = responseData['fallbackUrl']?.toString();

        Log.debug(
          'Parsed response: url=$url, fallbackUrl=$fallbackUrl',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        String? thumbnailUrl =
            responseData['thumbnail']?.toString() ?? fallbackUrl;

        String? streamingMp4Url;
        String? streamingHlsUrl;
        String? streamingStatus;

        final streamingData = responseData['streaming'];
        if (streamingData is Map) {
          streamingMp4Url = streamingData['mp4Url']?.toString();
          streamingHlsUrl = streamingData['hlsUrl']?.toString();
          thumbnailUrl =
              streamingData['thumbnailUrl']?.toString() ??
              streamingData['thumbnail']?.toString() ??
              thumbnailUrl;
          streamingStatus = streamingData['status']?.toString();
        }

        if (url != null && url.isNotEmpty) {
          onProgress?.call(1.0);

          return BlossomUploadResult(
            success: true,
            url: url,
            fallbackUrl: fallbackUrl,
            streamingMp4Url: streamingMp4Url,
            streamingHlsUrl: streamingHlsUrl,
            thumbnailUrl: thumbnailUrl,
            streamingStatus: streamingStatus,
            videoId: fileHash,
          );
        }
      }

      return const BlossomUploadResult(
        success: false,
        errorMessage: 'Upload response missing URL field',
      );
    }

    if (response.statusCode == 409) {
      final existingUrl = '$_defaultServerUrl/$fileHash';
      onProgress?.call(1.0);

      return BlossomUploadResult(
        success: true,
        fallbackUrl: existingUrl,
        videoId: fileHash,
      );
    }

    final xReason =
        response.headers.value('X-Reason') ??
        response.headers.value('x-reason');

    return BlossomUploadResult(
      success: false,
      errorMessage:
          'Upload failed: ${response.statusCode} - ${xReason ?? response.data}',
    );
  }

  /// Core upload logic to a single Blossom server
  ///
  /// This method encapsulates the common upload flow used by all upload methods.
  /// It handles file streaming, auth events, progress callbacks, and response parsing.
  Future<BlossomUploadResult> _uploadToServer({
    required String serverUrl,
    required File file,
    required String fileHash,
    required int fileSize,
    required String contentType,
    String? proofManifestJson,
    void Function(double)? onProgress,
  }) async {
    try {
      // Validate server URL
      final uri = Uri.tryParse(serverUrl);
      if (uri == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Invalid Blossom server URL: $serverUrl',
        );
      }

      final authHeader = await _createBlossomAuthHeader(
        url: '$serverUrl/upload',
        method: 'PUT',
        fileHash: fileHash,
        fileSize: fileSize,
        contentDescription: 'Upload video to Blossom server',
      );
      if (authHeader == null) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Failed to create Blossom authentication',
        );
      }

      // Add ProofMode headers if manifest is provided
      final headers = <String, dynamic>{
        'Authorization': authHeader,
        'Content-Type': contentType,
        'Content-Length': fileSize.toString(),
      };

      if (proofManifestJson != null && proofManifestJson.isNotEmpty) {
        _addProofModeHeaders(headers, proofManifestJson);
      }

      Log.debug(
        'Sending PUT request to $serverUrl/upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.debug(
        '  File size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // PUT request with file stream (Blossom BUD-01 spec)
      // Using stream instead of bytes to avoid loading entire file into memory
      final fileStream = file.openRead();
      final response = await dio.put(
        '$serverUrl/upload',
        data: fileStream,
        options: Options(
          headers: headers,
          validateStatus: (status) => status != null && status < 500,
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            // Progress from 20% to 90% during upload
            final progress = 0.2 + (sent / total) * 0.7;
            onProgress(progress);
          }
        },
      );

      Log.debug(
        'Server response: ${response.statusCode}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return _parseUploadResponse(
        response,
        fileHash: fileHash,
        onProgress: onProgress,
      );
    } on DioException catch (e) {
      // Build detailed error message
      String errorDetail = e.message ?? 'Unknown error';
      if (e.error != null) {
        errorDetail = '$errorDetail (${e.error})';
      }

      if (e.type == DioExceptionType.connectionTimeout) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Connection timeout - check server URL',
        );
      } else if (e.type == DioExceptionType.sendTimeout) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Send timeout - upload too slow or connection dropped',
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Receive timeout - server not responding',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Cannot connect to Blossom server: $errorDetail',
        );
      } else if (e.type == DioExceptionType.cancel) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Upload cancelled',
        );
      } else {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Network error: $errorDetail',
        );
      }
    } catch (e) {
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Upload error: $e',
      );
    }
  }

  /// Upload a video file to the configured Blossom server
  ///
  /// Tries multiple Blossom servers in priority order with fallback.
  /// Returns success if any server succeeds, failure only if all servers fail.
  ///
  /// [proofManifestJson] - Optional ProofMode manifest JSON string for cryptographic proof
  Future<BlossomUploadResult> uploadVideo({
    required File videoFile,
    required String nostrPubkey,
    required String title,
    required String? proofManifestJson,
    required String? description,
    required List<String>? hashtags,
    BlossomResumableUploadSession? resumableSession,
    void Function(BlossomResumableUploadSession)? onResumableSessionUpdated,
    void Function(double)? onProgress,
  }) async {
    // Start performance trace for video upload
    await PerformanceMonitoringService.instance.startTrace('video_upload');

    try {
      // Check authentication before attempting any uploads
      if (!authService.isAuthenticated) {
        Log.error(
          '❌ User not authenticated - cannot sign Blossom requests',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'User not authenticated - please sign in to upload',
        );
      }

      Log.info(
        '✅ User is authenticated, can create signed events',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // Report initial progress
      onProgress?.call(0.1);

      // Use streaming hash computation to avoid loading entire file into memory
      // This is critical for iOS where large files (40MB+) can cause memory issues
      final hashResult = await HashUtil.sha256File(videoFile);
      final fileSize = hashResult.size;
      final fileHash = hashResult.hash;

      // Add file size metric to performance trace
      PerformanceMonitoringService.instance.setMetric(
        'video_upload',
        'file_size_bytes',
        fileSize,
      );

      Log.info(
        'File hash: $fileHash, size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      onProgress?.call(0.2);

      // Get ordered list of servers to try
      final serverUrls = await _getServerUrlsForUpload();

      Log.info(
        'Trying ${serverUrls.length} Blossom servers in priority order',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      BlossomUploadResult? lastError;

      // Try each server in order until one succeeds
      for (final serverUrl in serverUrls) {
        try {
          Log.info(
            'Attempting video upload to: $serverUrl',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          final capability = await _fetchDivineUploadCapability(serverUrl);
          final hasProofModeData =
              proofManifestJson != null && proofManifestJson.isNotEmpty;
          final useResumable =
              capability.supportsResumable && !hasProofModeData;

          if (capability.supportsResumable && hasProofModeData) {
            Log.info(
              'Skipping Divine resumable upload flow for $serverUrl because ProofMode headers require the legacy upload path',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
          } else if (useResumable) {
            Log.info(
              'Using Divine resumable upload flow for $serverUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
          }

          final result = useResumable
              ? await _uploadToServerResumable(
                  serverUrl: serverUrl,
                  file: videoFile,
                  fileHash: fileHash,
                  fileSize: fileSize,
                  contentType: 'video/mp4',
                  resumableSession: resumableSession,
                  onProgress: onProgress,
                  onResumableSessionUpdated: onResumableSessionUpdated,
                )
              : await _uploadToServer(
                  serverUrl: serverUrl,
                  file: videoFile,
                  fileHash: fileHash,
                  fileSize: fileSize,
                  contentType: 'video/mp4',
                  proofManifestJson: proofManifestJson,
                  onProgress: onProgress,
                );

          if (result.success) {
            // Construct the canonical Blossom URL from server + hash
            // Per Blossom spec (BUD-01), blobs are always at {server}/{sha256}
            // This is deterministic and doesn't depend on server response
            final canonicalUrl = '$_defaultServerUrl/$fileHash';

            Log.info(
              '✅ Video uploaded to: $serverUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Canonical URL: $canonicalUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Server response URL: ${result.url}',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Thumbnail: ${result.thumbnailUrl}',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Video ID (hash): $fileHash',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );

            // Return with canonical URL to ensure we never publish
            // a non-HTTP URL (e.g. local file path)
            return BlossomUploadResult(
              success: true,
              url: canonicalUrl,
              fallbackUrl: canonicalUrl,
              videoId: fileHash,
              thumbnailUrl: result.thumbnailUrl,
              streamingMp4Url: result.streamingMp4Url,
              streamingHlsUrl: result.streamingHlsUrl,
              streamingStatus: result.streamingStatus,
            );
          }

          lastError = result;
          Log.warning(
            'Upload to $serverUrl failed: ${result.errorMessage}, trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
        } catch (e) {
          Log.warning(
            'Upload to $serverUrl failed: $e, trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          continue;
        }
      }

      // All servers failed
      Log.error(
        '❌ All ${serverUrls.length} servers failed for video upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return lastError ??
          const BlossomUploadResult(
            success: false,
            errorMessage: 'All servers failed',
          );
    } catch (e) {
      Log.error(
        'Blossom upload error: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return BlossomUploadResult(
        success: false,
        errorMessage: 'Blossom upload failed: $e',
      );
    } finally {
      // Stop performance trace
      await PerformanceMonitoringService.instance.stopTrace('video_upload');
    }
  }

  Future<BlossomResumableUploadSession> resumeUploadSession({
    required BlossomResumableUploadSession session,
  }) => _queryResumableUploadSession(session);

  /// Upload an image file (e.g. thumbnail) to the configured Blossom server
  ///
  /// Tries multiple Blossom servers in priority order with fallback.
  /// Returns success if any server succeeds, failure only if all servers fail.
  ///
  /// This uses the same Blossom BUD-01 protocol as video uploads but with image MIME type
  Future<BlossomUploadResult> uploadImage({
    required File imageFile,
    required String nostrPubkey,
    String mimeType = 'image/jpeg',
    void Function(double)? onProgress,
  }) async {
    try {
      // Check authentication
      if (!authService.isAuthenticated) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
        );
      }

      // Report initial progress
      onProgress?.call(0.1);

      // Strip EXIF metadata (GPS, device info) before uploading.
      // The stripper may rename the file (e.g. .avif → .jpg) so use the
      // returned reference for all subsequent operations.
      final strippedFile = await ImageMetadataStripper.stripMetadataInPlace(
        imageFile,
      );

      // Calculate file hash for Blossom
      // Note: For images, we need to load into memory for the hash (small files)
      final fileBytes = await strippedFile.readAsBytes();
      final fileHash = HashUtil.sha256Hash(fileBytes);
      final fileSize = fileBytes.length;

      Log.info(
        'Image file hash: $fileHash, size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      onProgress?.call(0.2);

      // Get ordered list of servers to try
      final serverUrls = await _getServerUrlsForUpload();

      Log.info(
        'Trying ${serverUrls.length} Blossom servers for image upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      BlossomUploadResult? lastError;

      // Try each server in order until one succeeds
      for (final serverUrl in serverUrls) {
        try {
          Log.info(
            'Attempting image upload to: $serverUrl',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );

          final result = await _uploadToServer(
            serverUrl: serverUrl,
            file: strippedFile,
            fileHash: fileHash,
            fileSize: fileSize,
            contentType: mimeType,
            onProgress: onProgress,
          );

          if (result.success) {
            // Construct canonical Blossom URL from server + hash
            final canonicalUrl = '$_defaultServerUrl/$fileHash';

            Log.info(
              '✅ Image uploaded to: $serverUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Canonical URL: $canonicalUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );

            return BlossomUploadResult(
              success: true,
              url: canonicalUrl,
              fallbackUrl: canonicalUrl,
              videoId: fileHash,
            );
          }

          lastError = result;
          Log.warning(
            'Upload to $serverUrl failed: ${result.errorMessage}, trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
        } catch (e) {
          Log.warning(
            'Upload to $serverUrl failed: $e, trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          continue;
        }
      }

      // All servers failed
      Log.error(
        '❌ All ${serverUrls.length} servers failed for image upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return lastError ??
          const BlossomUploadResult(
            success: false,
            errorMessage: 'All servers failed',
          );
    } catch (e) {
      Log.error(
        'Image upload exception: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Image upload failed: $e',
      );
    }
  }

  /// Upload a bug report file (text/plain) to the configured Blossom server
  ///
  /// Tries multiple Blossom servers in priority order with fallback.
  /// Returns the URL if any server succeeds, null only if all servers fail.
  Future<String?> uploadBugReport({
    required File bugReportFile,
    void Function(double)? onProgress,
  }) async {
    try {
      // Check authentication
      if (!authService.isAuthenticated) {
        Log.error(
          'Not authenticated - cannot upload bug report',
          name: 'BlossomUploadService',
          category: LogCategory.system,
        );
        return null;
      }

      // Report initial progress
      onProgress?.call(0.1);

      // Calculate file hash and size
      final fileBytes = await bugReportFile.readAsBytes();
      final fileHash = HashUtil.sha256Hash(fileBytes);
      final fileSize = fileBytes.length;

      Log.info(
        'Bug report file hash: $fileHash, size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );

      onProgress?.call(0.2);

      // Get ordered list of servers to try
      final serverUrls = await _getServerUrlsForUpload();

      Log.info(
        'Trying ${serverUrls.length} Blossom servers for bug report upload',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );

      // Try each server in order until one succeeds
      for (final serverUrl in serverUrls) {
        try {
          Log.info(
            'Attempting bug report upload to: $serverUrl',
            name: 'BlossomUploadService',
            category: LogCategory.system,
          );

          final result = await _uploadToServer(
            serverUrl: serverUrl,
            file: bugReportFile,
            fileHash: fileHash,
            fileSize: fileSize,
            contentType: 'text/plain',
            onProgress: onProgress,
          );

          if (result.success) {
            // Extract URL from result (fallbackUrl or url)
            final uploadedUrl = result.fallbackUrl ?? result.url;

            if (uploadedUrl != null) {
              Log.info(
                '✅ Bug report uploaded to: $serverUrl',
                name: 'BlossomUploadService',
                category: LogCategory.system,
              );
              Log.info(
                '  URL: $uploadedUrl',
                name: 'BlossomUploadService',
                category: LogCategory.system,
              );
              return uploadedUrl;
            }
          }

          Log.warning(
            'Upload to $serverUrl failed: ${result.errorMessage}, trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.system,
          );
        } catch (e) {
          Log.warning(
            'Upload to $serverUrl failed: $e, trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.system,
          );
          continue;
        }
      }

      // All servers failed
      Log.error(
        '❌ All ${serverUrls.length} servers failed for bug report upload',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );

      return null;
    } catch (e) {
      Log.error(
        'Bug report upload error: $e',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Add ProofMode headers to upload request
  ///
  /// Generates X-ProofMode-Manifest, X-ProofMode-Signature, and X-ProofMode-Attestation
  /// headers from the provided ProofManifest JSON.
  void _addProofModeHeaders(
    Map<String, dynamic> headers,
    String proofManifestJson,
  ) {
    try {
      final manifestMap = jsonDecode(proofManifestJson) as Map<String, dynamic>;

      // Base64 encode the full manifest
      headers['X-ProofMode-Manifest'] = base64.encode(
        utf8.encode(proofManifestJson),
      );

      // Extract and encode signature if present
      if (manifestMap['pgpSignature'] != null) {
        headers['X-ProofMode-Signature'] = _encodeHeaderValue(
          manifestMap['pgpSignature'],
        );
      }

      // Extract and encode attestation if present
      if (manifestMap['deviceAttestation'] != null) {
        headers['X-ProofMode-Attestation'] = _encodeHeaderValue(
          manifestMap['deviceAttestation'],
        );
      }

      final c2paManifestId =
          manifestMap['c2paManifestId'] ?? manifestMap['c2pa_manifest_id'];
      if (c2paManifestId != null) {
        headers['X-ProofMode-C2PA'] = _encodeHeaderValue(c2paManifestId);
      }

      Log.info(
        'Added ProofMode headers to upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        'Failed to add ProofMode headers: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      // Don't fail the upload if ProofMode headers can't be added
    }
  }

  /// Base64-encodes a manifest field value for use as an HTTP header.
  ///
  /// Handles both [String] and [Map] values. Maps are JSON-encoded first.
  String _encodeHeaderValue(dynamic value) {
    final stringValue = value is String ? value : jsonEncode(value);
    return base64.encode(utf8.encode(stringValue));
  }

  /// Upload an audio file to the configured Blossom server
  ///
  /// Tries multiple Blossom servers in priority order with fallback.
  /// Returns success if any server succeeds, failure only if all servers fail.
  ///
  /// This uses the same Blossom BUD-01 protocol as video/image uploads but with
  /// audio MIME type. Used by the audio reuse feature when publishing videos
  /// with allowAudioReuse enabled.
  ///
  /// Returns a [BlossomUploadResult] with the audio file URL on success.
  Future<BlossomUploadResult> uploadAudio({
    required File audioFile,
    String mimeType = 'audio/aac',
    void Function(double)? onProgress,
  }) async {
    try {
      // Check authentication
      if (!authService.isAuthenticated) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
        );
      }

      // Report initial progress
      onProgress?.call(0.1);

      // Use streaming hash computation for memory efficiency
      final hashResult = await HashUtil.sha256File(audioFile);
      final fileHash = hashResult.hash;
      final fileSize = hashResult.size;

      Log.info(
        'Audio file hash: $fileHash, size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      onProgress?.call(0.2);

      // Get ordered list of servers to try
      final serverUrls = await _getServerUrlsForUpload();

      Log.info(
        'Trying ${serverUrls.length} Blossom servers for audio upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      BlossomUploadResult? lastError;

      // Try each server in order until one succeeds
      for (final serverUrl in serverUrls) {
        try {
          Log.info(
            'Attempting audio upload to: $serverUrl',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );

          final result = await _uploadToServer(
            serverUrl: serverUrl,
            file: audioFile,
            fileHash: fileHash,
            fileSize: fileSize,
            contentType: mimeType,
            onProgress: onProgress,
          );

          if (result.success) {
            // Construct canonical Blossom URL from server + hash
            final canonicalUrl = '$_defaultServerUrl/$fileHash';

            Log.info(
              '✅ Audio uploaded to: $serverUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Canonical URL: $canonicalUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );

            return BlossomUploadResult(
              success: true,
              url: canonicalUrl,
              fallbackUrl: canonicalUrl,
              videoId: fileHash,
            );
          }

          lastError = result;
          Log.warning(
            'Upload to $serverUrl failed: ${result.errorMessage}, trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
        } catch (e) {
          Log.warning(
            'Upload to $serverUrl failed: $e, trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          continue;
        }
      }

      // All servers failed
      Log.error(
        '❌ All ${serverUrls.length} servers failed for audio upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return lastError ??
          const BlossomUploadResult(
            success: false,
            errorMessage: 'All servers failed',
          );
    } catch (e) {
      Log.error(
        'Audio upload error: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Audio upload failed: $e',
      );
    }
  }

  /// Test connection to a Blossom server
  ///
  /// Returns a [BlossomHealthCheckResult] with status, latency, and any errors.
  /// This does a simple HEAD request to check if the server is reachable.
  Future<BlossomHealthCheckResult> testServerConnection([
    String? serverUrl,
  ]) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Use provided URL or get configured server
      final targetUrl = serverUrl ?? await getBlossomServer();
      if (targetUrl == null || targetUrl.isEmpty) {
        return const BlossomHealthCheckResult(
          isReachable: false,
          errorMessage: 'No Blossom server configured',
        );
      }

      Log.info(
        'Testing Blossom server connectivity: $targetUrl',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );

      // Try HEAD request first (lightweight), fall back to GET if HEAD fails
      try {
        final response = await dio.head(
          targetUrl,
          options: Options(
            validateStatus: (status) => status != null && status < 500,
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        stopwatch.stop();

        final isReachable =
            response.statusCode != null && response.statusCode! < 500;
        return BlossomHealthCheckResult(
          isReachable: isReachable,
          latencyMs: stopwatch.elapsedMilliseconds,
          statusCode: response.statusCode,
          serverUrl: targetUrl,
        );
      } on DioException catch (e) {
        // If HEAD is not supported, try GET
        if (e.response?.statusCode == 405) {
          final response = await dio.get(
            targetUrl,
            options: Options(
              validateStatus: (status) => status != null && status < 500,
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );
          stopwatch.stop();

          final isReachable =
              response.statusCode != null && response.statusCode! < 500;
          return BlossomHealthCheckResult(
            isReachable: isReachable,
            latencyMs: stopwatch.elapsedMilliseconds,
            statusCode: response.statusCode,
            serverUrl: targetUrl,
          );
        }
        rethrow;
      }
    } on DioException catch (e) {
      stopwatch.stop();

      String errorMessage;
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Cannot connect: ${e.message}';
      } else {
        errorMessage = e.message ?? 'Unknown error';
      }

      return BlossomHealthCheckResult(
        isReachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: errorMessage,
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      stopwatch.stop();
      return BlossomHealthCheckResult(
        isReachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }
}
