import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/io_client.dart';
import 'package:media_cache/src/safe_cache_info_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Callback for logging debug messages.
typedef LogDebugCallback = void Function(String message);

/// Callback for logging info messages.
typedef LogInfoCallback = void Function(String message);

/// Callback for logging warning messages.
typedef LogWarningCallback = void Function(String message);

/// Callback for logging error messages.
typedef LogErrorCallback = void Function(String message);

/// {@template media_cache_config}
/// Configuration for [MediaCacheManager].
///
/// Provides sensible defaults that can be overridden for specific use cases.
/// {@endtemplate}
class MediaCacheConfig {
  /// {@macro media_cache_config}
  const MediaCacheConfig({
    required this.cacheKey,
    this.stalePeriod = const Duration(days: 14),
    this.maxNrOfCacheObjects = 200,
    this.connectionTimeout = const Duration(seconds: 15),
    this.idleTimeout = const Duration(seconds: 30),
    this.maxConnectionsPerHost = 6,
    this.enableSyncManifest = false,
    this.allowBadCertificatesInDebug = true,
    this.onDebug,
    this.onInfo,
    this.onWarning,
    this.onError,
  });

  /// Creates a configuration optimized for video caching.
  ///
  /// - Longer stale period (30 days)
  /// - More cache objects (1000)
  /// - Longer timeouts for large downloads
  /// - Sync manifest enabled for instant playback
  const MediaCacheConfig.video({
    required String cacheKey,
    LogDebugCallback? onDebug,
    LogInfoCallback? onInfo,
    LogWarningCallback? onWarning,
    LogErrorCallback? onError,
  }) : this(
         cacheKey: cacheKey,
         stalePeriod: const Duration(days: 30),
         maxNrOfCacheObjects: 1000,
         connectionTimeout: const Duration(seconds: 30),
         idleTimeout: const Duration(minutes: 2),
         maxConnectionsPerHost: 4,
         enableSyncManifest: true,
         onDebug: onDebug,
         onInfo: onInfo,
         onWarning: onWarning,
         onError: onError,
       );

  /// Creates a configuration optimized for image caching.
  ///
  /// - Shorter stale period (7 days)
  /// - Fewer cache objects (200)
  /// - Shorter timeouts for smaller downloads
  /// - No sync manifest needed
  const MediaCacheConfig.image({
    required String cacheKey,
    LogDebugCallback? onDebug,
    LogInfoCallback? onInfo,
    LogWarningCallback? onWarning,
    LogErrorCallback? onError,
  }) : this(
         cacheKey: cacheKey,
         stalePeriod: const Duration(days: 7),
         maxNrOfCacheObjects: 200,
         connectionTimeout: const Duration(seconds: 10),
         idleTimeout: const Duration(seconds: 30),
         maxConnectionsPerHost: 6,
         enableSyncManifest: false,
         onDebug: onDebug,
         onInfo: onInfo,
         onWarning: onWarning,
         onError: onError,
       );

  /// Unique key for this cache. Used as the cache directory name.
  final String cacheKey;

  /// Duration before cached files are considered stale.
  final Duration stalePeriod;

  /// Maximum number of objects to keep in cache.
  final int maxNrOfCacheObjects;

  /// Timeout for establishing HTTP connections.
  final Duration connectionTimeout;

  /// Timeout for idle HTTP connections.
  final Duration idleTimeout;

  /// Maximum concurrent connections per host.
  final int maxConnectionsPerHost;

  /// Whether to maintain an in-memory manifest for synchronous lookups.
  ///
  /// When enabled, [MediaCacheManager.getCachedFileSync] can return cached
  /// files instantly without async overhead. Useful for video players that
  /// need immediate file access.
  final bool enableSyncManifest;

  /// Whether to allow bad certificates in debug mode on desktop platforms.
  ///
  /// Useful for local development with self-signed certificates.
  final bool allowBadCertificatesInDebug;

  /// Optional callback for debug messages.
  final LogDebugCallback? onDebug;

  /// Optional callback for info messages.
  final LogInfoCallback? onInfo;

  /// Optional callback for warning messages.
  final LogWarningCallback? onWarning;

  /// Optional callback for error messages.
  final LogErrorCallback? onError;
}

/// {@template media_cache_manager}
/// A configurable media cache manager built on `flutter_cache_manager`.
///
/// Features:
/// - Configurable cache size, stale period, and timeouts
/// - Corrupt cache file recovery via [SafeCacheInfoRepository]
/// - Optional in-memory manifest for synchronous file lookups
/// - Preset configurations for videos and images
///
/// Example:
/// ```dart
/// // Create a video cache with sync manifest
/// final videoCache = MediaCacheManager(
///   config: MediaCacheConfig.video(cacheKey: 'my_video_cache'),
/// );
///
/// // Initialize manifest for sync lookups (call on app startup)
/// await videoCache.initialize();
///
/// // Get cached file synchronously (instant, no async overhead)
/// final file = videoCache.getCachedFileSync('video_123');
///
/// // Or cache a new file
/// final cachedFile = await videoCache.cacheFile(
///   'https://example.com/video.mp4',
///   key: 'video_123',
/// );
/// ```
/// {@endtemplate}
class MediaCacheManager extends CacheManager {
  /// {@macro media_cache_manager}
  MediaCacheManager({
    required MediaCacheConfig config,
  }) : _config = config,
       super(
         Config(
           config.cacheKey,
           stalePeriod: config.stalePeriod,
           maxNrOfCacheObjects: config.maxNrOfCacheObjects,
           repo: SafeCacheInfoRepository(
             databaseName: config.cacheKey,
             onWarning: config.onWarning,
             onInfo: config.onInfo,
             onError: config.onError,
           ),
           fileService: _createHttpFileService(config),
         ),
       );

  final MediaCacheConfig _config;

  /// In-memory manifest for synchronous lookups.
  /// Maps cache key to file path.
  final Map<String, String> _cacheManifest = {};

  /// Tracks keys currently being cached to prevent duplicate requests.
  final Map<String, Future<File?>> _pendingCacheOperations = {};

  /// Whether the cache manifest has been initialized.
  bool _manifestInitialized = false;

  /// Whether this cache manager has been initialized.
  bool get isInitialized => _manifestInitialized;

  /// The configuration used by this cache manager.
  MediaCacheConfig get mediaConfig => _config;

  static HttpFileService _createHttpFileService(MediaCacheConfig config) {
    final httpClient = HttpClient()
      ..connectionTimeout = config.connectionTimeout
      ..idleTimeout = config.idleTimeout
      ..maxConnectionsPerHost = config.maxConnectionsPerHost;

    // In debug mode on desktop, allow self-signed certificates
    if (config.allowBadCertificatesInDebug &&
        kDebugMode &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      httpClient.badCertificateCallback = (cert, host, port) => true;
    }

    return HttpFileService(httpClient: IOClient(httpClient));
  }

  /// Initializes the cache manifest by loading all cached files from database.
  ///
  /// Should be called on app startup if [MediaCacheConfig.enableSyncManifest]
  /// is `true`. This enables [getCachedFileSync] to return files instantly.
  ///
  /// Safe to call multiple times - subsequent calls are no-ops.
  Future<void> initialize() async {
    if (!_config.enableSyncManifest) {
      _config.onDebug?.call(
        '${_config.cacheKey}: Sync manifest disabled, skipping initialization',
      );
      _manifestInitialized = true;
      return;
    }

    if (_manifestInitialized) {
      _config.onDebug?.call(
        '${_config.cacheKey}: Cache manifest already initialized, skipping',
      );
      return;
    }

    try {
      _config.onInfo?.call(
        '${_config.cacheKey}: Initializing cache manifest from database...',
      );

      final startTime = DateTime.now();

      // Get the base cache directory
      final tempDir = await getTemporaryDirectory();
      final baseCacheDir = path.join(tempDir.path, _config.cacheKey);
      final cacheDir = Directory(baseCacheDir);

      if (!cacheDir.existsSync()) {
        _config.onInfo?.call(
          '${_config.cacheKey}: No cache directory found yet, '
          'skipping initialization',
        );
        _manifestInitialized = true;
        return;
      }

      // Scan the cache directory for files
      var loadedCount = 0;
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          // flutter_cache_manager uses the key as filename (with extension)
          // We store without extension as the key
          final key = path.basenameWithoutExtension(fileName);
          _cacheManifest[key] = entity.path;
          loadedCount++;
        }
      }

      final duration = DateTime.now().difference(startTime);
      _manifestInitialized = true;

      _config.onInfo?.call(
        '${_config.cacheKey}: Cache manifest initialized: '
        '$loadedCount files loaded (${duration.inMilliseconds}ms)',
      );
    } on Exception catch (error) {
      _config.onError?.call(
        '${_config.cacheKey}: Failed to initialize cache manifest: $error',
      );
      // Don't throw - degraded functionality is better than crash
      _manifestInitialized = true;
    }
  }

  /// Gets a cached file synchronously using the in-memory manifest.
  ///
  /// Returns `null` if:
  /// - The file is not in the manifest
  /// - The file no longer exists on disk
  /// - [MediaCacheConfig.enableSyncManifest] is `false`
  /// - [initialize] has not been called
  ///
  /// This method has zero async overhead, making it ideal for video players
  /// that need to decide immediately whether to use a cached file or network.
  File? getCachedFileSync(String key) {
    if (!_config.enableSyncManifest) {
      return null;
    }

    final cachedPath = _cacheManifest[key];
    if (cachedPath == null) {
      return null;
    }

    // Verify file still exists
    final file = File(cachedPath);
    if (!file.existsSync()) {
      // Remove stale entry from manifest
      _cacheManifest.remove(key);
      _config.onDebug?.call(
        '${_config.cacheKey}: Removed stale cache entry for $key',
      );
      return null;
    }

    _config.onDebug?.call(
      '${_config.cacheKey}: Fast cache hit for $key (sync check)',
    );
    return file;
  }

  /// Downloads and caches a file, returning the cached [File].
  ///
  /// If the file is already being cached (duplicate request), waits for and
  /// returns the result of the existing operation.
  ///
  /// Parameters:
  /// - [url]: The URL to download from
  /// - [key]: Unique key for this cached item (used for lookups)
  /// - [authHeaders]: Optional HTTP headers (e.g., for authenticated requests)
  ///
  /// Returns the cached [File], or `null` if caching failed.
  Future<File?> cacheFile(
    String url, {
    required String key,
    Map<String, String>? authHeaders,
  }) async {
    // Check if already cached
    final existingFile = await getFileFromCache(key);
    if (existingFile != null && existingFile.file.existsSync()) {
      // Update manifest
      if (_config.enableSyncManifest) {
        _cacheManifest[key] = existingFile.file.path;
      }
      _config.onDebug?.call(
        '${_config.cacheKey}: File $key already cached, skipping download',
      );
      return existingFile.file;
    }

    // Check if already being cached
    if (_pendingCacheOperations.containsKey(key)) {
      _config.onDebug?.call(
        '${_config.cacheKey}: Waiting for ongoing cache operation for $key',
      );
      return _pendingCacheOperations[key];
    }

    // Start caching
    final completer = Completer<File?>();
    _pendingCacheOperations[key] = completer.future;

    try {
      _config.onInfo?.call(
        '${_config.cacheKey}: Caching $key from $url',
      );

      final fileInfo = await downloadFile(
        url,
        key: key,
        authHeaders: authHeaders ?? {},
      );

      // Update manifest
      if (_config.enableSyncManifest) {
        _cacheManifest[key] = fileInfo.file.path;
      }

      _config.onInfo?.call(
        '${_config.cacheKey}: Successfully cached $key '
        'at ${fileInfo.file.path}',
      );

      completer.complete(fileInfo.file);
      return fileInfo.file;
    } on Exception catch (error) {
      _config.onError?.call(
        '${_config.cacheKey}: Failed to cache $key: $error',
      );
      completer.complete(null);
      return null;
    } finally {
      unawaited(Future(() => _pendingCacheOperations.remove(key)));
    }
  }

  /// Checks if a file is cached (async version).
  ///
  /// For synchronous checks, use [getCachedFileSync] instead.
  Future<bool> isFileCached(String key) async {
    try {
      final fileInfo = await getFileFromCache(key);
      final isCached = fileInfo != null && fileInfo.file.existsSync();

      // Update manifest if cached
      if (isCached && _config.enableSyncManifest) {
        _cacheManifest[key] = fileInfo.file.path;
      }

      return isCached;
    } on Exception catch (error) {
      _config.onWarning?.call(
        '${_config.cacheKey}: Error checking cache for $key: $error',
      );
      return false;
    }
  }

  /// Pre-caches multiple files in batches.
  ///
  /// Parameters:
  /// - [items]: List of (url, key) pairs to cache
  /// - [batchSize]: Maximum concurrent downloads (default: 3)
  /// - [authHeadersProvider]: Optional function to provide auth headers per key
  Future<void> preCacheFiles(
    List<({String url, String key})> items, {
    int batchSize = 3,
    Map<String, String>? Function(String key)? authHeadersProvider,
  }) async {
    if (items.isEmpty) return;

    _config.onInfo?.call(
      '${_config.cacheKey}: Pre-caching ${items.length} files',
    );

    // Process in batches
    for (var i = 0; i < items.length; i += batchSize) {
      final batch = <Future<File?>>[];
      final end = (i + batchSize > items.length) ? items.length : i + batchSize;

      for (var j = i; j < end; j++) {
        final item = items[j];

        // Skip if already cached
        if (await isFileCached(item.key)) {
          _config.onDebug?.call(
            '${_config.cacheKey}: Skipping already cached ${item.key}',
          );
          continue;
        }

        batch.add(
          cacheFile(
            item.url,
            key: item.key,
            authHeaders: authHeadersProvider?.call(item.key),
          ),
        );
      }

      // Wait for batch to complete
      await Future.wait(batch);
    }

    _config.onInfo?.call(
      '${_config.cacheKey}: Pre-caching completed',
    );
  }

  /// Removes a cached file by key.
  ///
  /// Useful for removing corrupted files so they can be re-downloaded.
  Future<void> removeCachedFile(String key) async {
    try {
      _config.onInfo?.call(
        '${_config.cacheKey}: Removing cached file $key',
      );

      await removeFile(key);

      // Remove from manifest
      _cacheManifest.remove(key);
      unawaited(Future(() => _pendingCacheOperations.remove(key)));

      _config.onInfo?.call(
        '${_config.cacheKey}: Successfully removed $key from cache',
      );
    } on Exception catch (error) {
      _config.onError?.call(
        '${_config.cacheKey}: Error removing $key from cache: $error',
      );
    }
  }

  /// Clears all cached files.
  Future<void> clearCache() async {
    try {
      _config.onInfo?.call(
        '${_config.cacheKey}: Clearing all cached files...',
      );

      await emptyCache();

      // Clear manifest
      _cacheManifest.clear();
      _pendingCacheOperations.clear();

      _config.onInfo?.call(
        '${_config.cacheKey}: Cache cleared successfully',
      );
    } on Exception catch (error) {
      _config.onError?.call(
        '${_config.cacheKey}: Error clearing cache: $error',
      );
    }
  }

  /// Returns basic cache statistics.
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheKey': _config.cacheKey,
      'manifestSize': _cacheManifest.length,
      'manifestInitialized': _manifestInitialized,
      'maxObjects': _config.maxNrOfCacheObjects,
      'stalePeriodDays': _config.stalePeriod.inDays,
      'syncManifestEnabled': _config.enableSyncManifest,
    };
  }

  /// Resets internal state for testing purposes.
  @visibleForTesting
  void resetForTesting() {
    _manifestInitialized = false;
    _cacheManifest.clear();
    _pendingCacheOperations.clear();
    _config.onDebug?.call(
      '${_config.cacheKey}: Cache manager reset for testing',
    );
  }
}
