// ABOUTME: Service for uploading videos to user-configured
// ABOUTME: Blossom media servers. Supports Blossom BUD-01
// ABOUTME: authentication and returns media URLs from any
// ABOUTME: Blossom server.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:blossom_upload_service/src/blossom_auth_provider.dart';
import 'package:blossom_upload_service/src/blossom_performance_monitor.dart';
import 'package:blossom_upload_service/src/blossom_resumable_upload_session.dart';
import 'package:blossom_upload_service/src/hash_util.dart';
import 'package:blossom_upload_service/src/upload_constants.dart';
import 'package:dio/dio.dart';
import 'package:image_metadata_stripper/image_metadata_stripper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Result type for Blossom upload operations
class BlossomUploadResult {
  /// Creates a [BlossomUploadResult].
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
    this.statusCode,
  });

  /// Whether the upload succeeded.
  final bool success;

  /// SHA-256 hash of the uploaded file.
  final String? videoId;

  /// Primary HLS URL from server.
  final String? url;

  /// R2 MP4 URL (always available immediately).
  final String? fallbackUrl;

  /// BunnyStream MP4 URL (may be processing).
  final String? streamingMp4Url;

  /// BunnyStream HLS URL (same as url).
  final String? streamingHlsUrl;

  /// Auto-generated thumbnail.
  final String? thumbnailUrl;

  /// "processing" or "ready".
  final String? streamingStatus;

  /// Deprecated - keeping for backwards compatibility.
  final String? gifUrl;

  /// Deprecated - keeping for backwards compatibility.
  final String? blurhash;

  /// Error message on failure.
  final String? errorMessage;

  /// HTTP status code on failure.
  final int? statusCode;

  /// Convenience getter for backwards compatibility.
  String? get cdnUrl => fallbackUrl ?? url;
}

/// Result type for Blossom server health checks
class BlossomHealthCheckResult {
  /// Creates a [BlossomHealthCheckResult].
  const BlossomHealthCheckResult({
    required this.isReachable,
    this.latencyMs,
    this.statusCode,
    this.serverUrl,
    this.errorMessage,
  });

  /// Whether the server is reachable.
  final bool isReachable;

  /// Latency in milliseconds.
  final int? latencyMs;

  /// HTTP status code.
  final int? statusCode;

  /// The server URL that was tested.
  final String? serverUrl;

  /// Error message if unreachable.
  final String? errorMessage;

  @override
  String toString() {
    if (isReachable) {
      return 'OK (${latencyMs}ms)';
    } else {
      return 'FAILED: ${errorMessage ?? "Unknown error"}';
    }
  }
}

/// Exception thrown when a resumable upload operation fails.
class BlossomResumableUploadException implements Exception {
  /// Creates a [BlossomResumableUploadException].
  const BlossomResumableUploadException(this.message, {this.statusCode});

  /// The error message.
  final String message;

  /// HTTP status code, if applicable.
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

class _CachedCapability {
  _CachedCapability(this.capability, this.expiresAt);

  final _DivineUploadCapability capability;
  final DateTime expiresAt;
}

/// Blossom BUD-01 media upload service with resumable upload support.
class BlossomUploadService {
  /// Creates a [BlossomUploadService].
  BlossomUploadService({
    required this.authProvider,
    BlossomPerformanceMonitor? performanceMonitor,
    Dio? dio,
    String? defaultServerUrl,
    DateTime Function()? clock,
  }) : _performanceMonitor =
           performanceMonitor ?? const NoOpPerformanceMonitor(),
       dio = dio ?? Dio(),
       _defaultServerUrl = defaultServerUrl ?? defaultBlossomServer,
       _clock = clock ?? DateTime.now;

  static const String _blossomServerKey = 'blossom_server_url';
  static const String _useBlossomKey = 'use_blossom_upload';

  /// The default Divine Blossom media server.
  static const String defaultBlossomServer = 'https://media.divine.video';

  /// Maximum retries for a single chunk PUT before bubbling to the caller.
  static const int _maxChunkRetries = 2;
  static const Duration _chunkRetryDelay = Duration(seconds: 1);

  /// How long a cached capability discovery result stays valid.
  static const Duration _capabilityCacheTtl = Duration(minutes: 5);

  /// The authentication provider for signing Blossom events.
  final BlossomAuthProvider authProvider;
  final BlossomPerformanceMonitor _performanceMonitor;

  /// The HTTP client used for uploads.
  final Dio dio;
  final String _defaultServerUrl;
  final DateTime Function() _clock;

  /// In-memory cache of capability discovery results keyed by server URL.
  final Map<String, _CachedCapability> _capabilityCache = {};

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
          'Using custom configured server: $customServerUrl',
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

  /// Enable or disable Blossom upload.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setBlossomEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useBlossomKey, enabled);
  }

  /// Create a Blossom authentication event for upload
  Future<BlossomSignedEvent?> _createBlossomAuthEvent({
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

      // Use auth provider to create and sign the event
      final signedEvent = await authProvider.createAndSignEvent(
        kind: 24242, // Blossom auth event kind
        content: contentDescription,
        tags: tags,
      );

      if (signedEvent == null) {
        Log.error(
          'Failed to create/sign Blossom auth event via auth provider',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        'Created Blossom auth event: ${signedEvent.json['id']}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event kind: ${signedEvent.json['kind']}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event pubkey: ${signedEvent.json['pubkey']}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event created_at: ${signedEvent.json['created_at']}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event tags: ${signedEvent.json['tags']}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return signedEvent;
    } on Object catch (e) {
      Log.error(
        'Error creating Blossom auth event: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  String _buildAuthHeader(BlossomSignedEvent authEvent) {
    final authEventJson = jsonEncode(authEvent.json);
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

  /// Whether a [DioException] from a chunk PUT is safe to retry.
  /// Returns `true` for 5xx server errors and transient network issues.
  bool _isTransientChunkError(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode != null && statusCode >= 500) return true;

    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      _ => false,
    };
  }

  bool _isTransientCapabilityDiscoveryError(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusCode >= 500) return true;

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout || // coverage:ignore-line
      DioExceptionType.receiveTimeout || // coverage:ignore-line
      DioExceptionType.connectionError => true, // coverage:ignore-line
      _ => false,
    };
  }

  bool _isDivineOwnedUploadHost(String serverUrl) {
    final host = Uri.tryParse(serverUrl)?.host.toLowerCase();
    if (host == null || host.isEmpty) {
      return false;
    }

    return host == 'divine.video' || host.endsWith('.divine.video');
  }

  Future<BlossomUploadResult> _uploadToServerLegacyFallback({
    required String serverUrl,
    required File file,
    required String fileHash,
    required int fileSize,
    required String contentType,
    required String fallbackReason,
    String? proofManifestJson,
    void Function(double)? onProgress,
  }) async {
    Log.warning(
      'Falling back to legacy upload for $serverUrl '
      'after resumable failure: $fallbackReason',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );

    return _uploadToServer(
      serverUrl: serverUrl,
      file: file,
      fileHash: fileHash,
      fileSize: fileSize,
      contentType: contentType,
      proofManifestJson: proofManifestJson,
      onProgress: onProgress,
    );
  }

  /// Run the resumable upload first, then fall back to legacy PUT at most once
  /// for Divine-owned hosts when resumable upload either throws or returns a
  /// failure result.
  Future<BlossomUploadResult> _uploadWithSingleLegacyFallback({
    required String serverUrl,
    required Future<BlossomUploadResult> Function() uploadResumable,
    required Future<BlossomUploadResult> Function(String fallbackReason)
    uploadLegacyFallback,
  }) async {
    final isDivineOwnedHost = _isDivineOwnedUploadHost(serverUrl);
    Object? resumableError;
    late BlossomUploadResult result;

    try {
      result = await uploadResumable();
    } catch (error) {
      if (!isDivineOwnedHost) {
        rethrow;
      }

      resumableError = error;
      result = BlossomUploadResult(
        success: false,
        errorMessage: error.toString(),
      );
    }

    if (!isDivineOwnedHost || result.success) {
      return result;
    }

    return uploadLegacyFallback(
      resumableError?.toString() ??
          result.errorMessage ??
          'unknown resumable failure',
    );
  }

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

    final numericMatch = RegExp(r'^-?\d+$').firstMatch(value);
    if (numericMatch != null) {
      final epochValue = int.tryParse(value);
      if (epochValue == null) {
        return null;
      }

      final epochMillis = value.length <= 10 ? epochValue * 1000 : epochValue;
      return DateTime.fromMillisecondsSinceEpoch(epochMillis, isUtc: true);
    }

    return DateTime.tryParse(value);
  }

  int? _parseUploadOffset(Headers headers) {
    final rawOffset = headers.value(DivineUploadHeaders.uploadOffset);
    return rawOffset == null ? null : int.tryParse(rawOffset);
  }

  DateTime? _parseUploadExpiresAt(Headers headers) => _parseDateTimeValue(
    headers.value(DivineUploadHeaders.uploadExpiresAt) ??
        headers.value('Upload-Expires'),
  );

  Future<_DivineUploadCapability> _fetchDivineUploadCapability(
    String serverUrl,
  ) async {
    final cached = _capabilityCache[serverUrl];
    if (cached != null && _clock().isBefore(cached.expiresAt)) {
      Log.debug(
        'Using cached capability for $serverUrl',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return cached.capability;
    }

    try {
      final response = await dio.head<dynamic>(
        '$serverUrl/upload',
        options: Options(
          validateStatus: _validateHttpStatus,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final extensionsHeader = response.headers.value(
        DivineUploadHeaders.extensions,
      );
      final supportsResumable =
          extensionsHeader
              ?.split(',')
              .map((value) => value.trim().toLowerCase())
              .contains(DivineUploadExtensions.resumableSessions) ??
          false;

      final result = _DivineUploadCapability(
        supportsResumable: supportsResumable,
        controlHost: response.headers.value(DivineUploadHeaders.controlHost),
        dataHost: response.headers.value(DivineUploadHeaders.dataHost),
      );

      _capabilityCache[serverUrl] = _CachedCapability(
        result,
        _clock().add(_capabilityCacheTtl),
      );

      return result;
    } on DioException catch (error) {
      Log.warning(
        'Capability discovery failed for $serverUrl: ${error.message}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      if (_isDivineOwnedUploadHost(serverUrl) &&
          _isTransientCapabilityDiscoveryError(error)) {
        final fallback = cached?.capability.supportsResumable == true
            ? cached!.capability
            : const _DivineUploadCapability(supportsResumable: true);

        Log.warning(
          'Assuming resumable upload support for Divine '
          'host $serverUrl after transient capability '
          'probe failure',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );

        _capabilityCache[serverUrl] = _CachedCapability(
          fallback,
          _clock().add(_capabilityCacheTtl),
        );

        return fallback;
      }

      const fallback = _DivineUploadCapability(supportsResumable: false);

      _capabilityCache[serverUrl] = _CachedCapability(
        fallback,
        _clock().add(_capabilityCacheTtl),
      );

      return fallback;
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

    Log.info(
      '📤 Resumable init: POST $serverUrl/upload/init '
      '(file: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );
    final initStopwatch = Stopwatch()..start();

    final response = await dio.post<dynamic>(
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
    initStopwatch.stop();

    Log.info(
      '📤 Resumable init response: ${response.statusCode} '
      'in ${initStopwatch.elapsedMilliseconds}ms',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );

    final responseData = response.data;
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        responseData is! Map) {
      throw BlossomResumableUploadException(
        'Failed to initialize resumable upload: '
        '${response.statusCode} ${response.data}',
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

    final totalChunks = (fileSize / chunkSize).ceil();
    Log.info(
      '📤 Resumable session created: uploadId=$uploadId, '
      'chunkSize=${(chunkSize / 1024).toStringAsFixed(0)}KB, '
      'totalChunks=$totalChunks, nextOffset=$nextOffset',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );

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
    final response = await dio.head<dynamic>(
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
    final totalChunks = (fileSize / currentSession.chunkSize).ceil();
    final startOffset = currentSession.nextOffset;
    var chunkIndex = 0;
    final uploadStopwatch = Stopwatch()..start();

    Log.info(
      '📤 Chunk upload starting: '
      '${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB '
      'in ~$totalChunks chunks '
      '(${(currentSession.chunkSize / 1024).toStringAsFixed(0)}KB each)'
      '${startOffset > 0 ? ', resuming from offset $startOffset' : ''}',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );

    try {
      while (currentSession.nextOffset < fileSize) {
        final start = currentSession.nextOffset;
        final endExclusive = math.min(
          start + currentSession.chunkSize,
          fileSize,
        );
        final chunkLength = endExclusive - start;
        chunkIndex++;

        await fileReader.setPosition(start);
        final chunkBytes = await fileReader.read(chunkLength);

        // Per-chunk retry for transient 5xx / network errors.
        // Chunk bytes are already in memory so retries are cheap.
        late Response<dynamic> response;
        var chunkAttempt = 0;
        late Stopwatch chunkStopwatch;
        while (true) {
          chunkStopwatch = Stopwatch()..start();
          try {
            response = await dio.put<dynamic>(
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
              // coverage:ignore-start
              onSendProgress: (sent, total) {
                if (fileSize <= 0) {
                  return;
                }
                final progress = 0.2 + ((start + sent) / fileSize) * 0.7;
                onProgress?.call(progress.clamp(0.2, 0.9));
              },
              // coverage:ignore-end
            );
            break;
          } on DioException catch (e) {
            chunkAttempt++;
            if (chunkAttempt > _maxChunkRetries || !_isTransientChunkError(e)) {
              rethrow;
            }
            Log.warning(
              'Chunk PUT failed at offset $start '
              '(attempt $chunkAttempt/$_maxChunkRetries): '
              '${e.response?.statusCode ?? e.type}',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            await Future<void>.delayed(_chunkRetryDelay);
          }
        }

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
              response.headers.value('x-reason'); // coverage:ignore-line
          throw BlossomResumableUploadException(
            'Chunk upload failed: ${response.statusCode} '
            '${xReason ?? response.data}', // coverage:ignore-line
            statusCode: response.statusCode,
          );
        }

        chunkStopwatch.stop();
        final chunkMs = chunkStopwatch.elapsedMilliseconds;
        // coverage:ignore-start
        final chunkSpeed = chunkMs > 0
            ? (chunkLength / 1024 / (chunkMs / 1000)).toStringAsFixed(0)
            : '?';
        // coverage:ignore-end
        Log.debug(
          '📤 Chunk $chunkIndex/$totalChunks: '
          '${(chunkLength / 1024).toStringAsFixed(0)}KB '
          'in ${chunkMs}ms (${chunkSpeed}KB/s) '
          '[${(endExclusive / fileSize * 100).toStringAsFixed(0)}%]',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );

        currentSession = currentSession.copyWith(
          nextOffset: _parseUploadOffset(response.headers) ?? endExclusive,
          expiresAt:
              _parseUploadExpiresAt(response.headers) ??
              currentSession.expiresAt,
        );
        onResumableSessionUpdated?.call(currentSession);
      }

      uploadStopwatch.stop();
      final totalMs = uploadStopwatch.elapsedMilliseconds;
      final bytesThisSession = fileSize - startOffset;
      final avgSpeed = totalMs > 0
          ? (bytesThisSession / 1024 / 1024 / (totalMs / 1000)).toStringAsFixed(
              2,
            )
          : '?';
      Log.info(
        '📤 Chunk upload complete: '
        '$chunkIndex chunks this session '
        '($totalChunks total), '
        '${(totalMs / 1000).toStringAsFixed(1)}s, '
        '${avgSpeed}MB/s avg',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

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
    String? proofManifestJson,
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
        'Failed to create Blossom authentication for '
        'resumable upload completion',
      );
    }

    final headers = <String, dynamic>{
      'Authorization': authHeader,
      'Content-Type': 'application/json',
    };

    if (proofManifestJson != null && proofManifestJson.isNotEmpty) {
      _addProofModeHeaders(headers, proofManifestJson);
    }

    Log.info(
      '📤 Completing resumable upload: '
      '${session.uploadId}',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );
    final completeStopwatch = Stopwatch()..start();

    final response = await dio.post<dynamic>(
      '$serverUrl/upload/${session.uploadId}/complete',
      data: {'sha256': fileHash},
      options: Options(
        headers: headers,
        validateStatus: _validateHttpStatus,
      ),
    );
    completeStopwatch.stop();

    Log.info(
      '📤 Complete response: ${response.statusCode} '
      'in ${completeStopwatch.elapsedMilliseconds}ms',
      name: 'BlossomUploadService',
      category: LogCategory.video,
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
    String? proofManifestJson,
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
      proofManifestJson: proofManifestJson,
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
        var thumbnailUrl = responseData['thumbnail']?.toString() ?? fallbackUrl;

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
          onProgress?.call(1);

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
      onProgress?.call(1);

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
      statusCode: response.statusCode,
      errorMessage:
          'Upload failed: ${response.statusCode} - ${xReason ?? response.data}',
    );
  }

  /// Core upload logic to a single Blossom server.
  ///
  /// This method encapsulates the common upload flow used by
  /// all upload methods. It handles file streaming, auth events,
  /// progress callbacks, and response parsing.
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
        // coverage:ignore-start
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Invalid Blossom server URL: $serverUrl',
        );
        // coverage:ignore-end
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
      final response = await dio.put<dynamic>(
        '$serverUrl/upload',
        data: fileStream,
        options: Options(
          headers: headers,
          validateStatus: // coverage:ignore-start
          (status) =>
              status != null && status < 500,
          // coverage:ignore-end
        ),
        // coverage:ignore-start
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            // Progress from 20% to 90% during upload
            final progress = 0.2 + (sent / total) * 0.7;
            onProgress(progress);
          }
        },
        // coverage:ignore-end
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
      var errorDetail = e.message ?? 'Unknown error';
      if (e.error != null) {
        errorDetail = '$errorDetail (${e.error})';
      }

      final statusCode = e.response?.statusCode;

      if (e.type == DioExceptionType.connectionTimeout) {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Connection timeout - check server URL',
        );
      } else if (e.type == DioExceptionType.sendTimeout) {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Send timeout - upload too slow or connection dropped',
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Receive timeout - server not responding',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Cannot connect to Blossom server: $errorDetail',
        );
      } else if (e.type == DioExceptionType.cancel) {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Upload cancelled',
        );
      } else if (e.type == DioExceptionType.badResponse) {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Server error ($statusCode): $errorDetail',
        );
      } else {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Network error: $errorDetail',
        );
      }
    } on Object catch (e) {
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Upload error: $e',
      );
    }
  }

  /// Upload a video file to the configured Blossom server.
  ///
  /// Tries multiple Blossom servers in priority order with
  /// fallback. Returns success if any server succeeds, failure
  /// only if all servers fail.
  ///
  /// [proofManifestJson] - Optional ProofMode manifest JSON
  /// string for cryptographic proof.
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
    await _performanceMonitor.startTrace('video_upload');

    try {
      // Check authentication before attempting any uploads
      if (!authProvider.isAuthenticated) {
        Log.error(
          'User not authenticated - cannot sign Blossom requests',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'User not authenticated - please sign in to upload',
        );
      }

      Log.info(
        'User is authenticated, can create signed events',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // Report initial progress
      onProgress?.call(0.1);

      // Use streaming hash computation to avoid loading entire
      // file into memory. This is critical for iOS where large
      // files (40MB+) can cause memory issues.
      final hashResult = await HashUtil.sha256File(videoFile);
      final fileSize = hashResult.size;
      final fileHash = hashResult.hash;

      // Add file size metric to performance trace
      _performanceMonitor.setMetric(
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
          final useResumable = capability.supportsResumable;

          if (useResumable) {
            Log.info(
              hasProofModeData
                  ? 'Using Divine resumable upload flow '
                        'for $serverUrl with ProofMode '
                        'metadata on completion'
                  : 'Using Divine resumable upload flow '
                        'for $serverUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
          }

          late BlossomUploadResult result;
          if (useResumable) {
            result = await _uploadWithSingleLegacyFallback(
              serverUrl: serverUrl,
              uploadResumable: () => _uploadToServerResumable(
                serverUrl: serverUrl,
                file: videoFile,
                fileHash: fileHash,
                fileSize: fileSize,
                contentType: 'video/mp4',
                proofManifestJson: proofManifestJson,
                resumableSession: resumableSession,
                onProgress: onProgress,
                onResumableSessionUpdated: onResumableSessionUpdated,
              ),
              uploadLegacyFallback: (fallbackReason) =>
                  _uploadToServerLegacyFallback(
                    serverUrl: serverUrl,
                    file: videoFile,
                    fileHash: fileHash,
                    fileSize: fileSize,
                    contentType: 'video/mp4',
                    proofManifestJson: proofManifestJson,
                    onProgress: onProgress,
                    fallbackReason: fallbackReason,
                  ),
            );
          } else {
            result = await _uploadToServer(
              serverUrl: serverUrl,
              file: videoFile,
              fileHash: fileHash,
              fileSize: fileSize,
              contentType: 'video/mp4',
              proofManifestJson: proofManifestJson,
              onProgress: onProgress,
            );
          }

          if (result.success) {
            // Construct the canonical Blossom URL from server + hash
            // Per Blossom spec (BUD-01), blobs are always at {server}/{sha256}
            // This is deterministic and doesn't depend on server response
            final canonicalUrl = '$_defaultServerUrl/$fileHash';

            Log.info(
              'Video uploaded to: $serverUrl',
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
            'Upload to $serverUrl failed: '
            '${result.errorMessage}, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
        } on Object catch (e) {
          final statusCode = e is DioException ? e.response?.statusCode : null;
          lastError = BlossomUploadResult(
            success: false,
            statusCode: statusCode,
            errorMessage: 'Upload to $serverUrl failed: $e',
          );
          Log.warning(
            'Upload to $serverUrl failed: $e, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          continue;
        }
      }

      // All servers failed
      Log.error(
        'All ${serverUrls.length} servers failed '
        'for video upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return lastError ??
          const BlossomUploadResult(
            success: false,
            errorMessage: 'All servers failed',
          );
    } on Object catch (e) {
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
      await _performanceMonitor.stopTrace('video_upload');
    }
  }

  /// Resume a previously interrupted resumable upload session.
  Future<BlossomResumableUploadSession> resumeUploadSession({
    required BlossomResumableUploadSession session,
  }) => _queryResumableUploadSession(session);

  /// Upload an image file (e.g. thumbnail) to the configured
  /// Blossom server.
  ///
  /// Tries multiple Blossom servers in priority order with
  /// fallback. Returns success if any server succeeds, failure
  /// only if all servers fail.
  ///
  /// This uses the same Blossom BUD-01 protocol as video
  /// uploads but with image MIME type.
  Future<BlossomUploadResult> uploadImage({
    required File imageFile,
    required String nostrPubkey,
    String mimeType = 'image/jpeg',
    void Function(double)? onProgress,
  }) async {
    try {
      // Check authentication
      if (!authProvider.isAuthenticated) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
        );
      }

      // Report initial progress
      onProgress?.call(0.1);

      // Strip EXIF metadata (GPS, device info) before uploading.
      // The stripper may rename the file (e.g. .avif -> .jpg)
      // so use the returned reference for all subsequent ops.
      final strippedFile = await ImageMetadataStripper.stripMetadataInPlace(
        imageFile,
      );

      // Calculate file hash for Blossom.
      // For images we load into memory for the hash
      // (small files).
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

          final capability = await _fetchDivineUploadCapability(serverUrl);

          late BlossomUploadResult result;
          if (capability.supportsResumable) {
            result = await _uploadWithSingleLegacyFallback(
              serverUrl: serverUrl,
              uploadResumable: () => _uploadToServerResumable(
                serverUrl: serverUrl,
                file: strippedFile,
                fileHash: fileHash,
                fileSize: fileSize,
                contentType: mimeType,
                onProgress: onProgress,
              ),
              uploadLegacyFallback: (fallbackReason) =>
                  _uploadToServerLegacyFallback(
                    serverUrl: serverUrl,
                    file: strippedFile,
                    fileHash: fileHash,
                    fileSize: fileSize,
                    contentType: mimeType,
                    fallbackReason: fallbackReason,
                    onProgress: onProgress,
                  ),
            );
          } else {
            result = await _uploadToServer(
              serverUrl: serverUrl,
              file: strippedFile,
              fileHash: fileHash,
              fileSize: fileSize,
              contentType: mimeType,
              onProgress: onProgress,
            );
          }

          if (result.success) {
            // Construct canonical Blossom URL from server + hash
            final canonicalUrl = '$_defaultServerUrl/$fileHash';

            Log.info(
              'Image uploaded to: $serverUrl',
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
            'Upload to $serverUrl failed: '
            '${result.errorMessage}, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          // coverage:ignore-start
        } on Object catch (e) {
          final statusCode = e is DioException ? e.response?.statusCode : null;
          lastError = BlossomUploadResult(
            success: false,
            statusCode: statusCode,
            errorMessage: 'Upload to $serverUrl failed: $e',
          );
          Log.warning(
            'Upload to $serverUrl failed: $e, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          continue;
          // coverage:ignore-end
        }
      }

      // All servers failed
      Log.error(
        'All ${serverUrls.length} servers failed '
        'for image upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return lastError ??
          const BlossomUploadResult(
            success: false,
            errorMessage: 'All servers failed',
          );
    } on Object catch (e) {
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

  /// Upload a bug report file (text/plain) to the configured
  /// Blossom server.
  ///
  /// Tries multiple Blossom servers in priority order with
  /// fallback. Returns the URL if any server succeeds, null
  /// only if all servers fail.
  Future<String?> uploadBugReport({
    required File bugReportFile,
    void Function(double)? onProgress,
  }) async {
    try {
      // Check authentication
      if (!authProvider.isAuthenticated) {
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
                'Bug report uploaded to: $serverUrl',
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
            'Upload to $serverUrl failed: '
            '${result.errorMessage}, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.system,
          );
          // coverage:ignore-start
        } on Object catch (e) {
          Log.warning(
            'Upload to $serverUrl failed: $e, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.system,
          );
          continue;
        }
        // coverage:ignore-end
      }

      // All servers failed
      Log.error(
        'All ${serverUrls.length} servers failed '
        'for bug report upload',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );

      return null;
    } on Object catch (e) {
      Log.error(
        'Bug report upload error: $e',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Add ProofMode headers to upload request.
  ///
  /// Generates X-ProofMode-Manifest, X-ProofMode-Signature,
  /// and X-ProofMode-Attestation headers from the provided
  /// ProofManifest JSON.
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
    } on Object catch (e) {
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

  /// Upload an audio file to the configured Blossom server.
  ///
  /// Tries multiple Blossom servers in priority order with
  /// fallback. Returns success if any server succeeds, failure
  /// only if all servers fail.
  ///
  /// This uses the same Blossom BUD-01 protocol as video/image
  /// uploads but with audio MIME type. Used by the audio reuse
  /// feature when publishing videos with allowAudioReuse
  /// enabled.
  ///
  /// Returns a [BlossomUploadResult] with the audio file URL
  /// on success.
  Future<BlossomUploadResult> uploadAudio({
    required File audioFile,
    String mimeType = 'audio/aac',
    void Function(double)? onProgress,
  }) async {
    try {
      // Check authentication
      if (!authProvider.isAuthenticated) {
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
              'Audio uploaded to: $serverUrl',
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
            'Upload to $serverUrl failed: '
            '${result.errorMessage}, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          // coverage:ignore-start
        } on Object catch (e) {
          final statusCode = e is DioException ? e.response?.statusCode : null;
          lastError = BlossomUploadResult(
            success: false,
            statusCode: statusCode,
            errorMessage: 'Upload to $serverUrl failed: $e',
          );
          Log.warning(
            'Upload to $serverUrl failed: $e, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          continue;
          // coverage:ignore-end
        }
      }

      // All servers failed
      Log.error(
        'All ${serverUrls.length} servers failed '
        'for audio upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return lastError ??
          const BlossomUploadResult(
            success: false,
            errorMessage: 'All servers failed',
          );
    } on Object catch (e) {
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
        final response = await dio.head<dynamic>(
          targetUrl,
          options: Options(
            validateStatus: // coverage:ignore-start
            (status) =>
                status != null && status < 500,
            // coverage:ignore-end
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
          final response = await dio.get<dynamic>(
            targetUrl,
            options: Options(
              validateStatus: // coverage:ignore-start
              (status) =>
                  status != null && status < 500,
              // coverage:ignore-end
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
    } on Object catch (e) {
      stopwatch.stop();
      return BlossomHealthCheckResult(
        isReachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }
}
