// ABOUTME: Service for uploading videos to user-configured Blossom media servers
// ABOUTME: Supports Blossom BUD-01 authentication and returns media URLs from any Blossom server

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/blossom_server_discovery_service.dart';
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

class BlossomUploadService {
  static const String _blossomServerKey = 'blossom_server_url';
  static const String _useBlossomKey = 'use_blossom_upload';
  static const String defaultBlossomServer = 'https://media.divine.video';

  final AuthService authService;
  final Dio dio;

  BlossomUploadService({required this.authService, Dio? dio})
    : dio = dio ?? Dio();

  /// Determine which Blossom server to use for upload
  ///
  /// Priority order:
  /// 1. User's discovered Blossom servers (kind 10063) - try in priority order
  /// 2. Custom configured server (if enabled in settings)
  /// 3. Default diVine media server
  Future<List<String>> _getServerUrlsForUpload() async {
    final servers = <String>[];

    // 1. Check for discovered Blossom servers (kind 10063 / BUD-03)
    if (authService.hasUserBlossomServers == true) {
      final userServers = authService.userBlossomServers;
      // Sort by priority (lowest first)
      final sortedServers = List<DiscoveredBlossomServer>.from(userServers);
      sortedServers.sort((a, b) {
        final aPriority = a.priority ?? 999;
        final bPriority = b.priority ?? 999;
        return aPriority.compareTo(bPriority);
      });

      servers.addAll(sortedServers.map((s) => s.url));

      Log.info(
        '🌸 Using ${servers.length} discovered Blossom servers (kind 10063)',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
    }

    // 2. Check for custom configured server
    final isCustomServerEnabled = await isBlossomEnabled();
    if (isCustomServerEnabled) {
      final customServerUrl = await getBlossomServer();
      if (customServerUrl != null && customServerUrl.isNotEmpty) {
        // Only add if not already in the list
        if (!servers.contains(customServerUrl)) {
          servers.add(customServerUrl);
          Log.info(
            '🔧 Adding custom configured server: $customServerUrl',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
        }
      }
    }

    // 3. Always add default diVine server as fallback
    if (!servers.contains(defaultBlossomServer)) {
      servers.add(defaultBlossomServer);
      Log.debug(
        '🏠 Adding diVine fallback server: $defaultBlossomServer',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
    }

    return servers;
  }

  /// Get the configured Blossom server URL
  Future<String?> getBlossomServer() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_blossomServerKey);
    // If nothing is stored, return default. If empty string is stored, return it.
    return stored ?? defaultBlossomServer;
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
  /// When false (default), uploads go to diVine's Blossom server
  /// When true, uploads go to the user's custom configured server
  Future<bool> isBlossomEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useBlossomKey) ??
        false; // Default to false (use diVine's server)
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

      // Create Blossom auth event (kind 24242)
      final authEvent = await _createBlossomAuthEvent(
        url: '$serverUrl/upload',
        method: 'PUT',
        fileHash: fileHash,
        fileSize: fileSize,
      );

      if (authEvent == null) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Failed to create Blossom authentication',
        );
      }

      // Prepare headers following Blossom spec (BUD-01 requires standard base64 encoding)
      final authEventJson = jsonEncode(authEvent.toJson());
      final authHeader = 'Nostr ${base64.encode(utf8.encode(authEventJson))}';

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

      // Handle successful responses
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
          // Extract all URL fields from server response.
          final url = responseData['url']?.toString();
          final fallbackUrl = responseData['fallbackUrl']?.toString();

          Log.debug(
            'Parsed response: url=$url, fallbackUrl=$fallbackUrl',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          String? thumbnailUrl =
              responseData['thumbnail']?.toString() ?? fallbackUrl;

          // Extract streaming info if present
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

        // Response didn't have expected URL
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Upload response missing URL field',
        );
      }

      // Handle 409 Conflict - file already exists
      if (response.statusCode == 409) {
        final existingUrl = 'https://cdn.divine.video/$fileHash.mp4';
        onProgress?.call(1.0);

        return BlossomUploadResult(
          success: true,
          fallbackUrl: existingUrl, // Use fallbackUrl for R2 MP4
          videoId: fileHash,
        );
      }

      // Handle other error responses
      // Extract X-Reason header for detailed error info (BUD-01 spec)
      final xReason =
          response.headers.value('X-Reason') ??
          response.headers.value('x-reason');

      return BlossomUploadResult(
        success: false,
        errorMessage:
            'Upload failed: ${response.statusCode} - ${xReason ?? response.data}',
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

          final result = await _uploadToServer(
            serverUrl: serverUrl,
            file: videoFile,
            fileHash: fileHash,
            fileSize: fileSize,
            contentType: 'video/mp4',
            proofManifestJson: proofManifestJson,
            onProgress: onProgress,
          );

          if (result.success) {
            Log.info(
              '✅ Video uploaded to: $serverUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Primary URL (HLS): ${result.url}',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Fallback URL (R2 MP4): ${result.fallbackUrl}',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Streaming MP4: ${result.streamingMp4Url}',
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
            return result;
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

      // Calculate file hash for Blossom
      // Note: For images, we need to load into memory for the hash (small files)
      final fileBytes = await imageFile.readAsBytes();
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
            file: imageFile,
            fileHash: fileHash,
            fileSize: fileSize,
            contentType: mimeType,
            onProgress: onProgress,
          );

          if (result.success) {
            // Use fallbackUrl if available, otherwise use url (server may return either)
            String? correctedUrl = result.fallbackUrl ?? result.url;

            // Fix file extension if needed (server bug workaround)
            if (correctedUrl != null && correctedUrl.endsWith('.mp4')) {
              final extension = _getImageExtensionFromMimeType(mimeType);
              correctedUrl = correctedUrl.replaceAll(
                RegExp(r'\.mp4$'),
                '.$extension',
              );
              Log.debug(
                'Fixed server extension: .mp4 → .$extension for MIME type: $mimeType',
                name: 'BlossomUploadService',
                category: LogCategory.video,
              );
            }

            Log.info(
              '✅ Image uploaded to: $serverUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  URL: $correctedUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );

            return BlossomUploadResult(
              success: true,
              fallbackUrl: correctedUrl,
              videoId: result.videoId,
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
        final signature = manifestMap['pgpSignature'] as Map<String, dynamic>;
        final signatureJson = jsonEncode(signature);
        headers['X-ProofMode-Signature'] = base64.encode(
          utf8.encode(signatureJson),
        );
      }

      // Extract and encode attestation if present
      if (manifestMap['deviceAttestation'] != null) {
        final attestation =
            manifestMap['deviceAttestation'] as Map<String, dynamic>;
        final attestationJson = jsonEncode(attestation);
        headers['X-ProofMode-Attestation'] = base64.encode(
          utf8.encode(attestationJson),
        );
      }

      if (manifestMap['c2pa_manifest_id'] != null) {
        final signature = manifestMap['c2pa_manifest_id'] as String;
        final signatureJson = jsonEncode(signature);
        headers['X-ProofMode-C2PA'] = base64.encode(utf8.encode(signatureJson));
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
            // Fix file extension if needed (server bug workaround)
            String? correctedUrl = result.fallbackUrl;
            if (correctedUrl != null && correctedUrl.endsWith('.mp4')) {
              final extension = _getAudioExtensionFromMimeType(mimeType);
              correctedUrl = correctedUrl.replaceAll(
                RegExp(r'\.mp4$'),
                extension,
              );
              Log.debug(
                'Fixed server extension: .mp4 -> $extension for audio',
                name: 'BlossomUploadService',
                category: LogCategory.video,
              );
            }

            Log.info(
              '✅ Audio uploaded to: $serverUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Audio URL: $correctedUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );

            return BlossomUploadResult(
              success: true,
              fallbackUrl: correctedUrl,
              videoId: result.videoId,
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

  /// Get file extension from audio MIME type
  String _getAudioExtensionFromMimeType(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'audio/aac':
        return '.aac';
      case 'audio/mp4':
      case 'audio/m4a':
        return '.m4a';
      case 'audio/mpeg':
      case 'audio/mp3':
        return '.mp3';
      case 'audio/ogg':
        return '.ogg';
      case 'audio/wav':
        return '.wav';
      case 'audio/webm':
        return '.webm';
      default:
        return '.aac';
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

  /// Map MIME types to file extensions for image uploads
  /// WORKAROUND: Blossom server returns .mp4 for all uploads, we need to fix it client-side
  String _getImageExtensionFromMimeType(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/svg+xml':
        return 'svg';
      case 'image/bmp':
        return 'bmp';
      default:
        // Default to jpg if unknown MIME type
        Log.debug(
          'Unknown image MIME type: $mimeType, defaulting to jpg',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return 'jpg';
    }
  }
}
