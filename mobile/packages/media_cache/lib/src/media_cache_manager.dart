import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/io_client.dart';
import 'package:media_cache/src/cancellable_cache_operation.dart';
import 'package:media_cache/src/cancellable_downloader.dart';
import 'package:media_cache/src/platform_downloader_factory.dart';
import 'package:media_cache/src/safe_cache_info_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

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
    this.defaultExtension = '.bin',
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
        // AVURLAsset / ExoPlayer probe the container from the file
        // extension first. URLs that hash to a path with no extension
        // (e.g. `https://media.divine.video/<sha>` for original
        // uploads) would otherwise be cached as `.bin` and fail to
        // open with `Cannot Open`.
        defaultExtension: '.mp4',
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
        // Tuning choice (not a measured optimum): raised from 6 → 20 to
        // unblock surfaces like the profile grid that issue ~20 concurrent
        // thumbnail requests to the same CDN host. 6 was observed too low
        // under #4330; 20 leaves headroom over the typical grid column
        // count. Revisit if socket/memory pressure shows up in profiling.
        maxConnectionsPerHost: 20,
        enableSyncManifest: false,
        defaultExtension: '.jpg',
      );

  /// Unique key for this cache. Used as the cache directory name.
  final String cacheKey;

  /// Duration before cached files are considered stale.
  final Duration stalePeriod;

  /// Maximum number of objects to keep in cache.
  final int maxNrOfCacheObjects;

  /// Timeout for establishing HTTP connections.
  ///
  /// Applied on Apple (`cupertino_http`) and dart:io fallback clients.
  /// Android Cronet currently ignores this value because `cronet_http` does
  /// not expose a matching configuration API.
  final Duration connectionTimeout;

  /// Timeout for idle HTTP connections.
  ///
  /// Applied on dart:io fallback clients.
  /// Android Cronet currently ignores this value because `cronet_http` does
  /// not expose a matching configuration API.
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

  /// Extension applied to cached files when the source URL has none.
  ///
  /// Native media frameworks (`AVURLAsset`, ExoPlayer) probe the
  /// container format from the file extension first. Hash-style URLs
  /// such as `https://media.divine.video/<sha>` (used for original
  /// uploads) would otherwise be cached as `.bin`, which AVFoundation
  /// rejects with `Cannot Open`. Set to `.mp4` for video caches and
  /// `.jpg` for image caches via the named factories.
  final String defaultExtension;
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
    @visibleForTesting IOClient? fileServiceClientOverride,
  }) : this._(
         config: config,
         tempDirectoryProvider: tempDirectoryProvider ?? getTemporaryDirectory,
         repoOverride: repoOverride,
         downloader: downloaderOverride ?? _createDefaultDownloader(config),
         // Built up-front and retained on the instance so close() can
         // dispose it. Without this the legacy non-cancellable cacheFile
         // path leaks an HttpClient on every MediaCacheManager.close().
         fileServiceClient: kIsWeb
             ? null
             : (fileServiceClientOverride ?? _buildFileServiceClient(config)),
       );

  MediaCacheManager._({
    required MediaCacheConfig config,
    required DirectoryProvider tempDirectoryProvider,
    required CacheInfoRepository? repoOverride,
    required CancellableDownloader downloader,
    required IOClient? fileServiceClient,
  }) : _config = config,
       _tempDirectoryProvider = tempDirectoryProvider,
       _repoOverride = repoOverride,
       _downloader = downloader,
       _fileServiceClient = fileServiceClient,
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
                 repo:
                     repoOverride ??
                     SafeCacheInfoRepository(databaseName: config.cacheKey),
                 // Non-null on the non-web branch (kIsWeb == false here);
                 // the public ctor only nulls fileServiceClient on web.
                 // ignore: unnecessary_null_checks
                 fileService: HttpFileService(httpClient: fileServiceClient!),
               ),
       );

  static CancellableDownloader _createDefaultDownloader(
    MediaCacheConfig config,
  ) {
    return createPlatformDownloader(
      connectionTimeout: config.connectionTimeout,
      idleTimeout: config.idleTimeout,
      maxConnectionsPerHost: config.maxConnectionsPerHost,
      allowBadCertificatesInDebug: config.allowBadCertificatesInDebug,
      isDebugMode: kDebugMode,
      isWeb: kIsWeb,
    );
  }

  final MediaCacheConfig _config;
  final DirectoryProvider _tempDirectoryProvider;
  final CacheInfoRepository? _repoOverride;
  final CancellableDownloader _downloader;

  /// HTTP client backing the legacy non-cancellable
  /// [CacheManager.getFileStream] / [CacheManager.getSingleFile] path.
  /// Retained so it can be closed symmetrically in [dispose]. `null` on
  /// web (no `dart:io` HttpClient there).
  final IOClient? _fileServiceClient;

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
  final Map<String, Completer<CancellableDownloadResult>>
  _pendingCacheOperations = {};

  /// Tracks cancellable operations currently in-flight.
  final Set<CancellableCacheOperation> _activeCancellableOperations = {};

  /// Tracks keys that were downloaded via [preCacheFiles] (prefetched).
  final Set<String> _prefetchedKeys = {};

  /// Cache hit/miss metrics for observability.
  final CacheMetrics metrics = CacheMetrics();

  /// Whether the cache manifest has been initialized.
  bool _manifestInitialized = false;

  bool _isClosed = false;

  bool _isProcessingResponse(FileInfo fileInfo) =>
      fileInfo.statusCode == HttpStatus.accepted;

  /// Whether this cache manager has been initialized.
  bool get isInitialized => _manifestInitialized;

  /// The configuration used by this cache manager.
  MediaCacheConfig get mediaConfig => _config;

  static IOClient _buildFileServiceClient(MediaCacheConfig config) {
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

    return IOClient(httpClient);
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
            var hadStaleEntries = false;
            for (final entry in decoded.entries) {
              final actualKey = entry.value;
              if (actualKey is! String) continue;
              final actualPath = _cacheManifest[actualKey];
              if (actualPath != null) {
                _aliasMap[entry.key] = actualKey;
                _cacheManifest[entry.key] = actualPath;
              } else {
                // Target was evicted by flutter_cache_manager's LRU; drop
                // the stale entry rather than letting aliases.json grow
                // unbounded across sessions.
                hadStaleEntries = true;
              }
            }
            if (hadStaleEntries) {
              unawaited(_persistAliasMap());
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
        final tmpFile = File('${aliasFile.path}.tmp');
        await tmpFile.writeAsString(jsonEncode(snapshot), flush: true);
        await tmpFile.rename(aliasFile.path);
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
      // Remove stale entry from manifest and any aliases pointing at it.
      _cacheManifest.remove(key);
      final orphanedAliases = _aliasMap.entries
          .where((e) => e.value == key)
          .map((e) => e.key)
          .toList(growable: false);
      if (orphanedAliases.isNotEmpty) {
        for (final alias in orphanedAliases) {
          _aliasMap.remove(alias);
          _cacheManifest.remove(alias);
        }
        unawaited(_persistAliasMap());
      }
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
    if (_isClosed) return null;

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
      return _pendingCacheOperations[key]!.future.then(
        (result) => result.file,
      );
    }

    // Start caching
    final completer = Completer<CancellableDownloadResult>();
    _pendingCacheOperations[key] = completer;

    unawaited(() async {
      try {
        final fileInfo = await downloadFile(
          url,
          key: key,
          authHeaders: authHeaders ?? {},
        );

        if (_isProcessingResponse(fileInfo)) {
          await removeCachedFile(key);
          try {
            if (fileInfo.file.existsSync()) {
              await fileInfo.file.delete();
            }
          } on Object {
            // Best-effort cleanup; the cache metadata has already been
            // removed so the processing response cannot be replayed.
          }
          if (!completer.isCompleted) {
            completer.complete(const CancellableDownloadResult(file: null));
          }
          return;
        }

        // Update manifest
        if (_config.enableSyncManifest && !_isClosed) {
          _cacheManifest[key] = fileInfo.file.path;
        }

        if (!completer.isCompleted) {
          completer.complete(
            CancellableDownloadResult(file: _isClosed ? null : fileInfo.file),
          );
        }
      } on Exception {
        if (!completer.isCompleted) {
          completer.complete(const CancellableDownloadResult(file: null));
        }
      } finally {
        _pendingCacheOperations.remove(key);
      }
    }());

    return completer.future.then((result) => result.file);
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
    return _cacheFileCancellable(
      url,
      key: key,
      aliasKey: aliasKey,
      authHeaders: authHeaders,
    );
  }

  CancellableCacheOperation _cacheFileCancellable(
    String url, {
    required String key,
    String? aliasKey,
    Map<String, String>? authHeaders,
    bool trackPrefetchMetrics = true,
  }) {
    if (_isClosed) {
      return CancellableCacheOperation.fromDownload(_CompletedNullDownload());
    }

    // Fast path: already cached on disk.
    if (_config.enableSyncManifest) {
      final cached =
          getCachedFileSync(key) ??
          (aliasKey != null ? getCachedFileSync(aliasKey) : null);
      if (cached != null) return CancellableCacheOperation.completed(cached);
    }

    // Join an in-flight download for the same key (started by either
    // cacheFile or a prior cacheFileCancellable call) instead of launching
    // a second concurrent download that would orphan the first file on disk.
    if (_pendingCacheOperations.containsKey(key)) {
      final sharedFuture = _pendingCacheOperations[key]!.future;
      var localCancelled = false;
      final localCompleter = Completer<CancellableDownloadResult>();
      unawaited(
        sharedFuture.then((result) {
          if (!localCompleter.isCompleted) {
            localCompleter.complete(
              localCancelled
                  ? const CancellableDownloadResult(file: null)
                  : result,
            );
          }
        }),
      );
      final joinOp = CancellableCacheOperation.fromDownload(
        _DeferredDownload(
          future: localCompleter.future,
          cancel: () {
            if (localCancelled) return;
            localCancelled = true;
            if (!localCompleter.isCompleted) {
              localCompleter.complete(
                const CancellableDownloadResult(file: null),
              );
            }
          },
          // coverage:ignore-start
          isCancelledGetter: () => localCancelled,
          // coverage:ignore-end
        ),
        cacheKey: key,
      );
      _activeCancellableOperations.add(joinOp);
      unawaited(
        joinOp.file.whenComplete(() {
          _activeCancellableOperations.remove(joinOp);
        }),
      );
      return joinOp;
    }

    if (trackPrefetchMetrics) {
      _prefetchedKeys.add(key);
      metrics.prefetchedTotal++;
    }

    final relativePath = _relativePathFor(key, url);
    final completer = Completer<CancellableDownloadResult>();
    // Register before the async download starts so any concurrent caller
    // (cacheFile or another cacheFileCancellable) for the same key joins
    // this operation instead of issuing a second download.
    _pendingCacheOperations[key] = completer;
    CancellableDownload? activeDownload;
    var cancelledBeforeStart = false;

    Future<void> startDownload() async {
      try {
        final baseDir = await _resolveBaseCacheDir();
        if (cancelledBeforeStart) {
          if (!completer.isCompleted) {
            completer.complete(const CancellableDownloadResult(file: null));
          }
          return;
        }
        final targetFile = File(path.join(baseDir, relativePath));
        final download = _downloader.download(
          url: url,
          targetFile: targetFile,
          headers: authHeaders,
        );
        activeDownload = download;
        final downloadResult = await download.result;
        final file = downloadResult.file;
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
        if (!completer.isCompleted) completer.complete(downloadResult);
      } on Object catch (error) {
        Log.warning(
          'MediaCacheManager: download setup failed for $url: $error',
          name: 'MediaCache',
          category: LogCategory.video,
        );
        if (!completer.isCompleted) {
          completer.complete(const CancellableDownloadResult(file: null));
        }
      } finally {
        _pendingCacheOperations.remove(key);
      }
    }

    unawaited(startDownload());

    final operation = CancellableCacheOperation.fromDownload(
      _DeferredDownload(
        future: completer.future,
        cancel: () {
          cancelledBeforeStart = true;
          activeDownload?.cancel();
        },
        // coverage:ignore-start
        isCancelledGetter: () =>
            activeDownload?.isCancelled ?? cancelledBeforeStart,
        // coverage:ignore-end
      ),
      cacheKey: key,
    );

    _activeCancellableOperations.add(operation);
    unawaited(
      operation.file.whenComplete(() {
        _activeCancellableOperations.remove(operation);
      }),
    );

    return operation;
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
  ///
  /// Non-filesystem-safe characters (slashes, colons, `?`, Unicode, etc.) in
  /// [key] are replaced with `_` so the path never creates unintended
  /// sub-directories or fails on `File.openWrite`.
  String _relativePathFor(String key, String url) {
    final safeKey = key.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    final ext = _extensionFor(url);
    final seq = ++_downloadSeq;
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${safeKey}_${ts}_$seq$ext';
  }

  String _extensionFor(String url) {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      final ext = path.extension(last);
      if (ext.isNotEmpty) return ext;
    } on Object catch (_) {
      // Fall through to default.
    }
    return _config.defaultExtension;
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

    final inFlightByKey = <String, Future<File?>>{};

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

        final existingDownload = inFlightByKey[item.key];
        if (existingDownload != null) {
          batch.add(existingDownload);
          continue;
        }

        final downloadFuture =
            _cacheFileCancellable(
              item.url,
              key: item.key,
              authHeaders: authHeadersProvider?.call(item.key),
              trackPrefetchMetrics: false,
            ).file.whenComplete(() {
              inFlightByKey.removeWhere((key, _) => key == item.key);
            });
        inFlightByKey[item.key] = downloadFuture;
        batch.add(downloadFuture);
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

    final aliasKeysToRemove = _aliasMap.entries
        .where((entry) => entry.value == key)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final aliasKey in aliasKeysToRemove) {
      _aliasMap.remove(aliasKey);
      _cacheManifest.remove(aliasKey);
    }
    if (aliasKeysToRemove.isNotEmpty) {
      await _persistAliasMap();
    }

    // Remove from manifest
    _cacheManifest.remove(key);
    unawaited(Future(() => _pendingCacheOperations.remove(key)));
  }

  /// Clears all cached files.
  Future<void> clearCache() async {
    await emptyCache();

    // Clear manifest
    _cacheManifest.clear();
    if (_aliasMap.isNotEmpty) {
      _aliasMap.clear();
      await _persistAliasMap();
    }
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
    _activeCancellableOperations.clear();
    _pendingCacheOperations.clear();
    _prefetchedKeys.clear();
    metrics.reset();
  }

  /// Waits for all pending alias-map writes to complete.
  ///
  /// Use this in tests instead of `pumpEventQueue` whenever a
  /// [getCachedFileSync] eviction or an [initialize] stale-entry prune
  /// triggers [_persistAliasMap] and you need the file on disk to reflect
  /// the updated map before making assertions.
  @visibleForTesting
  Future<void> waitForPendingAliasWrites() => _aliasWriteQueue;

  /// Closes this manager and releases owned downloader resources.
  ///
  /// Cancels active cancellable downloads and completes pending cache
  /// operations with `null` so awaiting callers do not hang.
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;

    final activeOps = _activeCancellableOperations.toList(growable: false);
    for (final operation in activeOps) {
      operation.cancel();
    }
    _activeCancellableOperations.clear();

    final pending = _pendingCacheOperations.values.toList(growable: false);
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.complete(const CancellableDownloadResult(file: null));
      }
    }
    _pendingCacheOperations.clear();

    await _downloader.close();
    _fileServiceClient?.close();
    await super.dispose();
  }
}

/// Bridges a deferred [Future] (which performs async setup before the real
/// [CancellableDownload] starts) into the [CancellableDownload] interface
/// expected by [CancellableCacheOperation.fromDownload].
class _DeferredDownload extends CancellableDownload {
  _DeferredDownload({
    required Future<CancellableDownloadResult> future,
    required void Function() cancel,
    required bool Function() isCancelledGetter,
  }) : _future = future,
       _cancel = cancel,
       _isCancelledGetter = isCancelledGetter;

  final Future<CancellableDownloadResult> _future;
  final void Function() _cancel;
  final bool Function() _isCancelledGetter;

  @override
  Future<CancellableDownloadResult> get result => _future;

  // coverage:ignore-start
  @override
  bool get isCancelled => _isCancelledGetter();
  // coverage:ignore-end

  @override
  void cancel() => _cancel();
}

class _CompletedNullDownload extends CancellableDownload {
  @override
  Future<CancellableDownloadResult> get result async =>
      const CancellableDownloadResult(file: null);

  // coverage:ignore-start
  @override
  bool get isCancelled => false;
  // coverage:ignore-end

  @override
  void cancel() {}
}
