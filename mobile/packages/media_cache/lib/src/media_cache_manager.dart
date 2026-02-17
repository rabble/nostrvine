import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/io_client.dart';
import 'package:media_cache/src/safe_cache_info_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

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
  });

  /// Creates a configuration optimized for video caching.
  ///
  /// - Longer stale period (30 days)
  /// - More cache objects (1000)
  /// - Longer timeouts for large downloads
  /// - Sync manifest enabled for instant playback
  const MediaCacheConfig.video({required String cacheKey})
    : this(
        cacheKey: cacheKey,
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 1000,
        connectionTimeout: const Duration(seconds: 30),
        idleTimeout: const Duration(minutes: 2),
        maxConnectionsPerHost: 4,
        enableSyncManifest: true,
      );

  /// Creates a configuration optimized for image caching.
  ///
  /// - Shorter stale period (7 days)
  /// - Fewer cache objects (200)
  /// - Shorter timeouts for smaller downloads
  /// - No sync manifest needed
  const MediaCacheConfig.image({required String cacheKey})
    : this(
        cacheKey: cacheKey,
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 200,
        connectionTimeout: const Duration(seconds: 10),
        idleTimeout: const Duration(seconds: 30),
        maxConnectionsPerHost: 6,
        enableSyncManifest: false,
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
}

/// Tracks cache hit/miss statistics for observability.
///
/// Records hits, misses, and prefetch effectiveness. Use [toMap] to export
/// metrics for analytics reporting.
class CacheMetrics {
  /// Number of synchronous cache lookups that found a cached file.
  int hits = 0;

  /// Number of synchronous cache lookups that did not find a cached file.
  int misses = 0;

  /// Files that were prefetched AND later accessed via getCachedFileSync.
  int prefetchedUsed = 0;

  /// Total files that were prefetched (downloaded via preCacheFiles).
  int prefetchedTotal = 0;

  /// Cache hit rate as a ratio (0.0 to 1.0).
  double get hitRate {
    final total = hits + misses;
    if (total == 0) return 0;
    return hits / total;
  }

  /// Export metrics as a map for analytics reporting.
  Map<String, dynamic> toMap() => {
    'cache_hits': hits,
    'cache_misses': misses,
    'cache_hit_rate': hitRate,
    'prefetched_used': prefetchedUsed,
    'prefetched_total': prefetchedTotal,
  };

  /// Reset all counters to zero.
  void reset() {
    hits = 0;
    misses = 0;
    prefetchedUsed = 0;
    prefetchedTotal = 0;
  }
}

/// {@template media_cache_manager}
/// A configurable media cache manager built on `flutter_cache_manager`.
///
/// Features:
/// - Configurable cache size, stale period, and timeouts
/// - Corrupt cache file recovery via `SafeCacheInfoRepository`
/// - Optional in-memory manifest for synchronous file lookups
/// - Preset configurations for videos and images
/// - Cache hit/miss metrics via `metrics`
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
///
/// // Check cache performance
/// print('Hit rate: ${videoCache.metrics.hitRate}');
/// ```
/// {@endtemplate}

/// Provides the path to the sqflite databases directory.
typedef DatabasePathProvider = Future<String> Function();

/// Opens a sqflite database at the given path.
typedef DatabaseOpener =
    Future<sqflite.Database> Function(
      String path, {
      bool readOnly,
    });

/// {@macro media_cache_manager}
class MediaCacheManager extends CacheManager {
  /// {@macro media_cache_manager}
  MediaCacheManager({
    required MediaCacheConfig config,
    @visibleForTesting DirectoryProvider? tempDirectoryProvider,
    @visibleForTesting DatabasePathProvider? databasePathProvider,
    @visibleForTesting DatabaseOpener? databaseOpener,
  }) : _config = config,
       _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory,
       _databasePathProvider = databasePathProvider ?? sqflite.getDatabasesPath,
       _databaseOpener = databaseOpener ?? _defaultDatabaseOpener,
       super(
         Config(
           config.cacheKey,
           stalePeriod: config.stalePeriod,
           maxNrOfCacheObjects: config.maxNrOfCacheObjects,
           repo: SafeCacheInfoRepository(databaseName: config.cacheKey),
           fileService: _createHttpFileService(config),
         ),
       );

  final MediaCacheConfig _config;
  final DirectoryProvider _tempDirectoryProvider;
  final DatabasePathProvider _databasePathProvider;
  final DatabaseOpener _databaseOpener;

  /// In-memory manifest for synchronous lookups.
  /// Maps cache key to file path.
  final Map<String, String> _cacheManifest = {};

  /// Tracks keys currently being cached to prevent duplicate requests.
  final Map<String, Future<File?>> _pendingCacheOperations = {};

  /// Tracks keys that were downloaded via [preCacheFiles] (prefetched).
  final Set<String> _prefetchedKeys = {};

  /// Cache hit/miss metrics for observability.
  final CacheMetrics metrics = CacheMetrics();

  /// Whether the cache manifest has been initialized.
  bool _manifestInitialized = false;

  /// Whether this cache manager has been initialized.
  bool get isInitialized => _manifestInitialized;

  /// The configuration used by this cache manager.
  MediaCacheConfig get mediaConfig => _config;

  static Future<sqflite.Database> _defaultDatabaseOpener(
    String path, {
    bool readOnly = false,
  }) => sqflite.openDatabase(path, readOnly: readOnly);

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
    if (!_config.enableSyncManifest || _manifestInitialized) {
      _manifestInitialized = true;
      return;
    }

    try {
      // Query the cache database to get key → filepath mappings
      // flutter_cache_manager stores metadata in sqflite, NOT in filenames
      final dbPath = await _databasePathProvider();
      final cacheDbPath = path.join(dbPath, '${_config.cacheKey}.db');

      // Check if database exists
      if (!File(cacheDbPath).existsSync()) {
        _manifestInitialized = true;
        return;
      }

      final database = await _databaseOpener(cacheDbPath, readOnly: true);

      try {
        // Query all cache objects from the cacheObject table
        final List<Map<String, dynamic>> maps = await database.query(
          'cacheObject',
        );

        // Get the base cache directory for constructing full paths
        final tempDir = await _tempDirectoryProvider();
        final baseCacheDir = path.join(tempDir.path, _config.cacheKey);

        // Populate manifest with verified cache entries
        for (final map in maps) {
          final cacheKey = map['key'] as String?;
          final relativePath = map['relativePath'] as String?;

          if (cacheKey == null || relativePath == null) continue;

          // Construct full file path
          final fullPath = path.join(baseCacheDir, relativePath);
          final file = File(fullPath);

          // Only add to manifest if file actually exists
          if (file.existsSync()) {
            _cacheManifest[cacheKey] = fullPath;
          }
        }
      } finally {
        await database.close();
      }

      _manifestInitialized = true;
    } on Exception catch (_) {
      // Don't throw - degraded functionality is better than crash
      // Also handles cases where sqflite isn't initialized (e.g., in tests)
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
      metrics.misses++;
      return null;
    }

    // Verify file still exists
    final file = File(cachedPath);
    if (!file.existsSync()) {
      // Remove stale entry from manifest
      _cacheManifest.remove(key);
      metrics.misses++;
      return null;
    }

    metrics.hits++;

    // Track prefetch effectiveness
    if (_prefetchedKeys.contains(key)) {
      metrics.prefetchedUsed++;
    }

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
      return existingFile.file;
    }

    // Check if already being cached
    if (_pendingCacheOperations.containsKey(key)) {
      return _pendingCacheOperations[key];
    }

    // Start caching
    final completer = Completer<File?>();
    _pendingCacheOperations[key] = completer.future;

    try {
      final fileInfo = await downloadFile(
        url,
        key: key,
        authHeaders: authHeaders ?? {},
      );

      // Update manifest
      if (_config.enableSyncManifest) {
        _cacheManifest[key] = fileInfo.file.path;
      }

      completer.complete(fileInfo.file);
      return fileInfo.file;
    } on Exception {
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
    } on Exception {
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

    // Track all items as prefetched for metrics
    for (final item in items) {
      _prefetchedKeys.add(item.key);
    }
    metrics.prefetchedTotal += items.length;

    // Process in batches
    for (var i = 0; i < items.length; i += batchSize) {
      final batch = <Future<File?>>[];
      final end = (i + batchSize > items.length) ? items.length : i + batchSize;

      for (var j = i; j < end; j++) {
        final item = items[j];

        // Skip if already cached
        if (await isFileCached(item.key)) {
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
  }

  /// Removes a cached file by key.
  ///
  /// Useful for removing corrupted files so they can be re-downloaded.
  Future<void> removeCachedFile(String key) async {
    await removeFile(key);

    // Remove from manifest
    _cacheManifest.remove(key);
    unawaited(Future(() => _pendingCacheOperations.remove(key)));
  }

  /// Clears all cached files.
  Future<void> clearCache() async {
    await emptyCache();

    // Clear manifest
    _cacheManifest.clear();
    _pendingCacheOperations.clear();
  }

  /// Returns basic cache statistics including hit/miss metrics.
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheKey': _config.cacheKey,
      'manifestSize': _cacheManifest.length,
      'manifestInitialized': _manifestInitialized,
      'maxObjects': _config.maxNrOfCacheObjects,
      'stalePeriodDays': _config.stalePeriod.inDays,
      'syncManifestEnabled': _config.enableSyncManifest,
      ...metrics.toMap(),
    };
  }

  /// Resets internal state for testing purposes.
  @visibleForTesting
  void resetForTesting() {
    _manifestInitialized = false;
    _cacheManifest.clear();
    _pendingCacheOperations.clear();
    _prefetchedKeys.clear();
    metrics.reset();
  }
}
