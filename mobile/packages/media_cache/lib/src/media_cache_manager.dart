import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:media_cache/src/cancellable_cache_operation.dart';
import 'package:media_cache/src/cancellable_downloader.dart';
import 'package:media_cache/src/safe_cache_info_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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

/// {@macro media_cache_manager}
class MediaCacheManager extends CacheManager {
  /// {@macro media_cache_manager}
  MediaCacheManager({
    required MediaCacheConfig config,
    @visibleForTesting DirectoryProvider? tempDirectoryProvider,
    @visibleForTesting CacheInfoRepository? repoOverride,
    @visibleForTesting CancellableDownloader? downloaderOverride,
  }) : _config = config,
       _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory,
       _repoOverride = repoOverride,
       _downloader = downloaderOverride ?? _createDefaultDownloader(config),
       super(
         kIsWeb
             // coverage:ignore-start
             ? Config(
                 config.cacheKey,
                 stalePeriod: config.stalePeriod,
                 maxNrOfCacheObjects: config.maxNrOfCacheObjects,
               )
             // coverage:ignore-end
             : Config(
                 config.cacheKey,
                 stalePeriod: config.stalePeriod,
                 maxNrOfCacheObjects: config.maxNrOfCacheObjects,
                 repo: SafeCacheInfoRepository(databaseName: config.cacheKey),
                 fileService: _createHttpFileService(config),
               ),
       );

  static CancellableDownloader _createDefaultDownloader(
    MediaCacheConfig config,
  ) {
    if (kIsWeb) {
      // coverage:ignore-start
      return HttpCancellableDownloader(http.Client());
      // coverage:ignore-end
    }
    // coverage:ignore-start
    // Prefer the platform-native HTTP stack:
    //   * Apple (iOS, macOS): NSURLSession via cupertino_http — gives us
    //     HTTP/2 + HTTP/3 (QUIC), shared OS-level connection pool, warm
    //     TLS sessions, and 0-RTT resumption. Materially faster on lossy
    //     links than dart:io's HTTP/1.1-only stack with a per-isolate
    //     pool, and on iOS/macOS shares the pool with AVPlayer.
    //   * Android: Cronet (Chromium net stack) via cronet_http — same
    //     story (HTTP/2 + HTTP/3, native pool). Falls back to dart:io
    //     when Cronet cannot be initialised (e.g. AOSP build without
    //     Google Play Services and no embedded Cronet asset bundled).
    // macOS in debug stays on the dart:io path so the bad-cert hook for
    // self-signed local relays keeps working; release/profile macOS
    // builds use NSURLSession.
    // Windows and Linux keep the dart:io / IOClient path.
    final useCupertino = Platform.isIOS || (Platform.isMacOS && !kDebugMode);
    if (useCupertino) {
      try {
        final cfg = URLSessionConfiguration.defaultSessionConfiguration()
          ..timeoutIntervalForRequest = config.connectionTimeout
          ..httpMaximumConnectionsPerHost = config.maxConnectionsPerHost;
        return HttpCancellableDownloader(
          CupertinoClient.fromSessionConfiguration(cfg),
        );
      } on Object catch (e, st) {
        debugPrint(
          'MediaCache: cupertino_http init failed, '
          'falling back to dart:io HttpClient: $e\n$st',
        );
      }
    } else if (Platform.isAndroid) {
      try {
        return HttpCancellableDownloader(CronetClient.defaultCronetEngine());
      } on Object catch (e, st) {
        debugPrint(
          'MediaCache: cronet_http init failed, '
          'falling back to dart:io HttpClient: $e\n$st',
        );
      }
    }
    // coverage:ignore-end
    final httpClient = HttpClient()
      ..connectionTimeout = config.connectionTimeout
      ..idleTimeout = config.idleTimeout
      ..maxConnectionsPerHost = config.maxConnectionsPerHost;
    if (config.allowBadCertificatesInDebug &&
        kDebugMode &&
        !kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      httpClient.badCertificateCallback = (cert, host, port) => true;
    }
    return HttpCancellableDownloader(IOClient(httpClient));
  }

  final MediaCacheConfig _config;
  final DirectoryProvider _tempDirectoryProvider;
  final CacheInfoRepository? _repoOverride;
  final CancellableDownloader _downloader;

  /// Resolved `<tempDir>/<cacheKey>` path. Populated by [initialize] and
  /// reused by [cacheFileCancellable] to compute target file paths
  /// synchronously.
  String? _baseCacheDir;

  /// Monotonic counter to disambiguate filenames written within the same
  /// millisecond when the same key is downloaded repeatedly.
  int _downloadSeq = 0;

  /// In-memory manifest for synchronous lookups.
  /// Maps cache key to file path.
  final Map<String, String> _cacheManifest = {};

  /// Persistent alias → actual cache key mapping.
  ///
  /// Survives app restarts so that successful fallback downloads
  /// (cached under e.g. `<videoId>__fb1`) remain reachable via the
  /// stable `aliasKey` (e.g. `<videoId>`) on the next launch instead
  /// of forcing the prefetcher to retry the failing first-attempt URL.
  final Map<String, String> _aliasMap = {};

  /// Serialises writes to the on-disk alias map.
  Future<void> _aliasWriteQueue = Future<void>.value();

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

  static HttpFileService _createHttpFileService(MediaCacheConfig config) {
    final httpClient = HttpClient()
      ..connectionTimeout = config.connectionTimeout
      ..idleTimeout = config.idleTimeout
      ..maxConnectionsPerHost = config.maxConnectionsPerHost;

    // In debug mode on desktop, allow self-signed certificates
    if (config.allowBadCertificatesInDebug &&
        kDebugMode &&
        !kIsWeb &&
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
    // coverage:ignore-start
    if (kIsWeb) {
      _manifestInitialized = true;
      return;
    }
    // coverage:ignore-end

    if (!_config.enableSyncManifest || _manifestInitialized) {
      _manifestInitialized = true;
      return;
    }

    try {
      // Read cache metadata via the Config's CacheInfoRepository
      // (JsonCacheInfoRepository wrapped by SafeCacheInfoRepository).
      // In tests a repo override may be injected to pre-populate the manifest
      // without needing a real JSON file on disk.
      final repo = _repoOverride ?? config.repo;
      if (!await repo.open()) {
        _manifestInitialized = true;
        return;
      }

      final objects = await repo.getAllObjects();
      final tempDir = await _tempDirectoryProvider();
      final baseCacheDir = path.join(tempDir.path, _config.cacheKey);
      _baseCacheDir = baseCacheDir;

      for (final obj in objects) {
        final fullPath = path.join(baseCacheDir, obj.relativePath);
        final file = File(fullPath);

        if (file.existsSync()) {
          _cacheManifest[obj.key] = fullPath;
        }
      }

      // Restore persisted alias → actualKey mappings so successful
      // fallback downloads from previous sessions remain reachable
      // via the stable alias on this launch.
      final aliasFile = File(path.join(baseCacheDir, 'aliases.json'));
      if (aliasFile.existsSync()) {
        try {
          final decoded = jsonDecode(await aliasFile.readAsString());
          if (decoded is Map<String, dynamic>) {
            for (final entry in decoded.entries) {
              final actualKey = entry.value;
              if (actualKey is! String) continue;
              final actualPath = _cacheManifest[actualKey];
              if (actualPath != null) {
                _aliasMap[entry.key] = actualKey;
                _cacheManifest[entry.key] = actualPath;
              }
            }
          }
        } on Exception catch (_) {
          // Corrupt alias file → ignore, will be overwritten on next write.
        }
      }

      _manifestInitialized = true;
    } on Exception catch (_) {
      // Don't throw - degraded functionality is better than crash
      _manifestInitialized = true;
    }
  }

  /// Persists the current [_aliasMap] to disk. Calls are serialised so
  /// concurrent fallback successes never interleave writes.
  Future<void> _persistAliasMap() {
    // coverage:ignore-start
    if (kIsWeb) return Future<void>.value();
    // coverage:ignore-end
    final snapshot = Map<String, String>.from(_aliasMap);
    final next = _aliasWriteQueue.then((_) async {
      try {
        final tempDir = await _tempDirectoryProvider();
        final baseCacheDir = Directory(
          path.join(tempDir.path, _config.cacheKey),
        );
        if (!baseCacheDir.existsSync()) {
          baseCacheDir.createSync(recursive: true);
        }
        final aliasFile = File(path.join(baseCacheDir.path, 'aliases.json'));
        await aliasFile.writeAsString(jsonEncode(snapshot), flush: true);
      } on Exception catch (_) {
        // Best-effort; in-memory alias map still works for this session.
      }
    });
    _aliasWriteQueue = next;
    return next;
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

  /// Downloads and caches a file with the ability to cancel mid-download.
  ///
  /// Unlike [cacheFile], this returns a [CancellableCacheOperation] whose
  /// underlying HTTP stream can be torn down immediately via
  /// `CancellableCacheOperation.cancel()`, freeing bandwidth for
  /// higher-priority downloads.
  ///
  /// Returns a completed operation instantly if the file is already cached.
  ///
  /// When [aliasKey] is provided, the manifest also records the resulting
  /// file path under [aliasKey] on success, and the fast-path lookup
  /// considers both keys. This lets callers retry the same logical asset
  /// under multiple cache keys (e.g. one per fallback URL) without
  /// inheriting partially-cached or otherwise broken data from a previous
  /// attempt, while still letting consumers look the file up by the
  /// stable [aliasKey].
  CancellableCacheOperation cacheFileCancellable(
    String url, {
    required String key,
    String? aliasKey,
    Map<String, String>? authHeaders,
  }) {
    // Fast path: already cached on disk.
    if (_config.enableSyncManifest) {
      final cached =
          getCachedFileSync(key) ??
          (aliasKey != null ? getCachedFileSync(aliasKey) : null);
      if (cached != null) return CancellableCacheOperation.completed(cached);
    }

    _prefetchedKeys.add(key);
    metrics.prefetchedTotal++;

    final relativePath = _relativePathFor(key, url);
    final completer = Completer<File?>();
    CancellableDownload? activeDownload;
    var cancelledBeforeStart = false;

    Future<void> startDownload() async {
      try {
        final baseDir = await _resolveBaseCacheDir();
        if (cancelledBeforeStart) {
          if (!completer.isCompleted) completer.complete();
          return;
        }
        final targetFile = File(path.join(baseDir, relativePath));
        final download = _downloader.download(
          url: url,
          targetFile: targetFile,
          headers: authHeaders,
        );
        activeDownload = download;
        final file = await download.file;
        if (file != null && !download.isCancelled) {
          // Register in flutter_cache_manager's store so the file survives
          // app restart and shows up in [getAllObjects] on next launch.
          try {
            await store.putFile(
              CacheObject(
                url,
                key: key,
                relativePath: relativePath,
                validTill: DateTime.now().add(_config.stalePeriod),
              ),
            );
          } on Object catch (_) {
            // Best-effort persistence; in-memory manifest still works.
          }
          if (_config.enableSyncManifest) {
            _cacheManifest[key] = file.path;
            if (aliasKey != null) {
              _cacheManifest[aliasKey] = file.path;
              if (_aliasMap[aliasKey] != key) {
                _aliasMap[aliasKey] = key;
                unawaited(_persistAliasMap());
              }
            }
          }
        }
        if (!completer.isCompleted) completer.complete(file);
      } on Object {
        if (!completer.isCompleted) completer.complete();
      }
    }

    unawaited(startDownload());

    return CancellableCacheOperation.fromDownload(
      _DeferredDownload(
        future: completer.future,
        cancel: () {
          cancelledBeforeStart = true;
          activeDownload?.cancel();
        },
        isCancelledGetter: () =>
            activeDownload?.isCancelled ?? cancelledBeforeStart,
      ),
      cacheKey: key,
    );
  }

  /// Returns the base cache directory, resolving and caching it on first use.
  Future<String> _resolveBaseCacheDir() async {
    final cached = _baseCacheDir;
    if (cached != null) return cached;
    final tempDir = await _tempDirectoryProvider();
    final base = path.join(tempDir.path, _config.cacheKey);
    final dir = Directory(base);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _baseCacheDir = base;
    return base;
  }

  /// Generates a unique relative filename for [key]. The filename embeds the
  /// cache key plus a monotonic counter and timestamp so concurrent
  /// downloads of the same key cannot collide on disk.
  String _relativePathFor(String key, String url) {
    final ext = _extensionFor(url);
    final seq = ++_downloadSeq;
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${key}_${ts}_$seq$ext';
  }

  String _extensionFor(String url) {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      final dot = last.lastIndexOf('.');
      if (dot > 0 && dot < last.length - 1 && dot >= last.length - 6) {
        return last.substring(dot);
      }
    } on Object catch (_) {
      // Fall through to default.
    }
    return '.bin';
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

/// Bridges a deferred [Future] (which performs async setup before the real
/// [CancellableDownload] starts) into the [CancellableDownload] interface
/// expected by [CancellableCacheOperation.fromDownload].
class _DeferredDownload implements CancellableDownload {
  _DeferredDownload({
    required Future<File?> future,
    required void Function() cancel,
    required bool Function() isCancelledGetter,
  }) : _future = future,
       _cancel = cancel,
       _isCancelledGetter = isCancelledGetter;

  final Future<File?> _future;
  final void Function() _cancel;
  final bool Function() _isCancelledGetter;

  @override
  Future<File?> get file => _future;

  @override
  bool get isCancelled => _isCancelledGetter();

  @override
  void cancel() => _cancel();
}
