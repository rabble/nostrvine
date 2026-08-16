// ABOUTME: Manual storage maintenance for the settings "Storage" screen.
// ABOUTME: Clears re-downloadable/regenerable caches and audits the clip
// ABOUTME: library for broken entries — never touches user clip files.

import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/storage_footprint.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/temp_render_janitor.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Usage and optional budget for one cache category.
class CacheUsageCategory extends Equatable {
  /// Creates cache category usage.
  const CacheUsageCategory({required this.usedBytes, this.limitBytes});

  /// Bytes currently held by this category.
  final int usedBytes;

  /// Category budget in bytes, or null when the category is unbudgeted.
  final int? limitBytes;

  @override
  List<Object?> get props => [usedBytes, limitBytes];
}

/// Clearable cache usage split by the categories that own their budgets.
class CacheUsage extends Equatable {
  /// Creates a cache usage breakdown.
  const CacheUsage({
    required this.video,
    required this.images,
    required this.transitionSeams,
    required this.tempRenders,
  });

  /// Empty cache usage for initial UI state.
  static const empty = CacheUsage(
    video: CacheUsageCategory(
      usedBytes: 0,
      limitBytes: kCacheLimitDefaultBytes,
    ),
    images: CacheUsageCategory(usedBytes: 0),
    transitionSeams: CacheUsageCategory(
      usedBytes: 0,
      limitBytes: kSeamCacheLimitBytes,
    ),
    tempRenders: CacheUsageCategory(usedBytes: 0),
  );

  /// Feed video download cache.
  final CacheUsageCategory video;

  /// Image and thumbnail cache.
  final CacheUsageCategory images;

  /// Persisted transition-seam previews.
  final CacheUsageCategory transitionSeams;

  /// Regenerable temp renders; intentionally unbudgeted.
  final CacheUsageCategory tempRenders;

  /// Total bytes currently held by all clearable categories.
  int get totalBytes =>
      video.usedBytes +
      images.usedBytes +
      transitionSeams.usedBytes +
      tempRenders.usedBytes;

  @override
  List<Object?> get props => [video, images, transitionSeams, tempRenders];
}

/// Clears re-downloadable / regenerable media caches and audits the clip
/// library for broken entries.
///
/// What it clears: the feed video download cache, the image/thumbnail cache,
/// leftover temp render files, and the regenerable transition-seam previews.
/// What it never touches: the user's clip-library files (recorded/imported
/// videos), drafts, keys, or preferences — those live outside the cleared
/// directories.
class StorageManagementService {
  /// Creates a service.
  ///
  /// [videoCache] and [imageCache] are the app's download caches;
  /// [clipLibrary] is scoped to the current account. The directory providers
  /// are injectable for tests and otherwise resolve the OS temp and documents
  /// directories. [protectedTempRenderPaths] supplies upload inputs that still
  /// need to survive a cache clear.
  StorageManagementService({
    required MediaCacheManager videoCache,
    required MediaCacheManager imageCache,
    required ClipLibraryService clipLibrary,
    required SharedPreferences prefs,
    @visibleForTesting Future<Directory> Function()? temporaryDirectoryProvider,
    @visibleForTesting Future<Directory> Function()? documentsDirectoryProvider,
    @visibleForTesting
    Future<Directory> Function()? applicationSupportDirectoryProvider,
    @visibleForTesting
    Future<Directory> Function()? applicationCacheDirectoryProvider,
    Set<String> Function()? protectedTempRenderPaths,
  }) : _videoCache = videoCache,
       _imageCache = imageCache,
       _clipLibrary = clipLibrary,
       _prefs = prefs,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _applicationSupportDirectoryProvider =
           applicationSupportDirectoryProvider ??
           getApplicationSupportDirectory,
       _applicationCacheDirectoryProvider =
           applicationCacheDirectoryProvider ?? getApplicationCacheDirectory,
       _protectedTempRenderPaths =
           protectedTempRenderPaths ?? _noProtectedPaths;

  final MediaCacheManager _videoCache;
  final MediaCacheManager _imageCache;
  final ClipLibraryService _clipLibrary;
  final SharedPreferences _prefs;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<Directory> Function() _applicationSupportDirectoryProvider;
  final Future<Directory> Function() _applicationCacheDirectoryProvider;
  final Set<String> Function() _protectedTempRenderPaths;

  static const String _logName = 'StorageManagementService';
  static const String _videoCacheDir = 'openvine_video_cache';
  static const String _imageCacheDir = 'openvine_image_cache';
  static const String _seamDir = 'transition_seams';

  static Set<String> _noProtectedPaths() => const {};

  /// Total bytes currently held by the clearable caches. Best-effort; a
  /// directory that cannot be read contributes zero rather than throwing.
  Future<int> cacheSizeBytes() async => (await cacheUsage()).totalBytes;

  /// Clearable cache usage split by category and matching budget.
  Future<CacheUsage> cacheUsage() async {
    final temp = await _temporaryDirectoryProvider();
    final docs = await _documentsDirectoryProvider();
    final protectedPaths = _normalizedProtectedTempRenderPaths();
    return CacheUsage(
      video: CacheUsageCategory(
        usedBytes: await _dirSize(Directory(p.join(temp.path, _videoCacheDir))),
        limitBytes: videoCacheLimitBytes(),
      ),
      images: CacheUsageCategory(
        usedBytes: await _dirSize(Directory(p.join(temp.path, _imageCacheDir))),
        limitBytes: _imageCache.maxCacheSizeBytes,
      ),
      transitionSeams: CacheUsageCategory(
        usedBytes: await _dirSize(Directory(p.join(docs.path, _seamDir))),
        limitBytes: kSeamCacheLimitBytes,
      ),
      tempRenders: CacheUsageCategory(
        usedBytes: await _tempRenderBytes(temp, protectedPaths),
      ),
    );
  }

  /// Clears every re-downloadable / regenerable cache. The clip library and
  /// all other user content are left untouched.
  Future<void> clearCaches() async {
    await _guard(_videoCache.clearCache);
    await _guard(_imageCache.clearCache);
    final temp = await _temporaryDirectoryProvider();
    // clearCache() only removes DB-tracked entries; orphaned/leaked files in
    // the cache directories survive (the leak from #5986). Delete the
    // directory contents so the freed size matches what cacheSizeBytes counts.
    await _deleteDirContents(Directory(p.join(temp.path, _videoCacheDir)));
    await _deleteDirContents(Directory(p.join(temp.path, _imageCacheDir)));
    final protectedPaths = _normalizedProtectedTempRenderPaths();
    await _forEachTempRender(
      temp,
      protectedPaths: protectedPaths,
      action: _deleteQuietly,
    );
    final docs = await _documentsDirectoryProvider();
    await _deleteDirContents(Directory(p.join(docs.path, _seamDir)));
  }

  /// Every directory the app writes to, each with its largest immediate
  /// children — the diagnostic for "the OS reports tens of GB but the cache
  /// readout says megabytes".
  ///
  /// [cacheUsage] deliberately covers only what [clearCaches] can reclaim, so
  /// it cannot locate a footprint that sits anywhere else. This walks all four
  /// platform roots instead, including the ones no in-app action clears: the
  /// documents directory (clip library, drafts, rendered videos) and the
  /// durable database, which even the repair wipe preserves.
  ///
  /// Roots that resolve to the same directory are reported once — on Android
  /// the temporary and cache directories are both `getCacheDir()` — so the
  /// totals never double-count. A root the platform cannot resolve is omitted
  /// rather than failing the whole measurement.
  ///
  /// Walks the full tree of every root, so it is slow on a large install and
  /// belongs behind an explicit user action.
  Future<StorageFootprint> measureFootprint({int childrenPerRoot = 12}) async {
    final providers = <String, Future<Directory> Function()>{
      'Documents': _documentsDirectoryProvider,
      'Application Support': _applicationSupportDirectoryProvider,
      'Caches': _applicationCacheDirectoryProvider,
      'Temporary': _temporaryDirectoryProvider,
    };
    final roots = <StorageFootprintRoot>[];
    final measuredPaths = <String>{};
    for (final entry in providers.entries) {
      final root = await _measureRoot(
        label: entry.key,
        provider: entry.value,
        childrenPerRoot: childrenPerRoot,
        measuredPaths: measuredPaths,
      );
      if (root != null) roots.add(root);
    }
    return StorageFootprint(roots: roots);
  }

  Future<StorageFootprintRoot?> _measureRoot({
    required String label,
    required Future<Directory> Function() provider,
    required int childrenPerRoot,
    required Set<String> measuredPaths,
  }) async {
    final Directory dir;
    try {
      dir = await provider();
    } on Object catch (error) {
      Log.warning(
        '$_logName: resolving $label failed: $error',
        name: _logName,
        category: LogCategory.system,
      );
      return null;
    }
    if (!measuredPaths.add(_normalizePath(dir.path))) return null;

    final children = <StorageFootprintEntry>[];
    var totalBytes = 0;
    if (dir.existsSync()) {
      try {
        await for (final entity in dir.list(followLinks: false)) {
          final isDirectory = entity is Directory;
          final bytes = switch (entity) {
            Directory() => await _dirSize(entity),
            File() => await _fileLength(entity),
            _ => 0,
          };
          totalBytes += bytes;
          children.add(
            StorageFootprintEntry(
              name: p.basename(entity.path),
              bytes: bytes,
              isDirectory: isDirectory,
            ),
          );
        }
      } on Object catch (error) {
        Log.warning(
          '$_logName: listing ${dir.path} failed: $error',
          name: _logName,
          category: LogCategory.system,
        );
      }
    }
    children.sort((a, b) => b.bytes.compareTo(a.bytes));
    return StorageFootprintRoot(
      label: label,
      path: dir.path,
      totalBytes: totalBytes,
      largestChildren: children.take(childrenPerRoot).toList(),
    );
  }

  /// Library clips whose backing media is gone — broken entries that can
  /// no longer play and should be cleaned up.
  Future<List<DivineVideoClip>> findBrokenClips() async {
    final clips = await _clipLibrary.getAllClips();
    return clips.where(_isUnrecoverable).toList();
  }

  /// Whether nothing playable remains for [clip]: a video clip whose file is
  /// gone, or a frames-only stop-motion set with no readable still left.
  ///
  /// A stop-motion set that still has at least one readable still is
  /// salvageable (see [StopMotionFrameOps.sanitizedClip], the same per-still
  /// policy the restore/editor paths use). Treating it as broken here would let
  /// [removeBrokenClips] hard-delete the row and destroy the surviving frames
  /// just because one still went missing.
  bool _isUnrecoverable(DivineVideoClip clip) {
    if (clip.isStopMotion) {
      return StopMotionFrameOps.sanitizedClip(clip) == null;
    }
    return !clip.hasResolvableVideoFile;
  }

  /// Permanently removes the given broken [clips] from the library.
  Future<void> removeBrokenClips(List<DivineVideoClip> clips) async {
    for (final clip in clips) {
      await _clipLibrary.hardDelete(clip.id);
    }
  }

  /// The user-configured video-cache byte budget, or
  /// [kCacheLimitDefaultBytes] when none is set.
  int videoCacheLimitBytes() =>
      _prefs.getInt(kCacheLimitPrefKey) ?? kCacheLimitDefaultBytes;

  /// Persists [bytes] (clamped to
  /// `[kCacheLimitMinBytes, kCacheLimitMaxBytes]`) as the video-cache budget,
  /// applies it, and trims immediately so a lowered limit shrinks the cache
  /// right away.
  Future<void> setVideoCacheLimit(int bytes) async {
    final clamped = bytes.clamp(kCacheLimitMinBytes, kCacheLimitMaxBytes);
    await _prefs.setInt(kCacheLimitPrefKey, clamped);
    _videoCache.maxCacheSizeBytes = clamped;
    await _videoCache.enforceCacheLimits(force: true);
  }

  Future<int> _dirSize(Directory dir) async {
    if (!dir.existsSync()) return 0;
    var size = 0;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) size += await entity.length();
      }
    } on Object catch (error) {
      Log.warning(
        '$_logName: sizing ${dir.path} failed: $error',
        name: _logName,
        category: LogCategory.system,
      );
    }
    return size;
  }

  /// Length of [file], or zero when it vanished mid-walk or cannot be read.
  Future<int> _fileLength(File file) async {
    try {
      return await file.length();
    } on Object {
      return 0;
    }
  }

  Future<int> _tempRenderBytes(
    Directory temp,
    Set<String> protectedPaths,
  ) async {
    var size = 0;
    await _forEachTempRender(
      temp,
      protectedPaths: protectedPaths,
      action: (file) async => size += await file.length(),
    );
    return size;
  }

  Future<void> _forEachTempRender(
    Directory temp, {
    required Set<String> protectedPaths,
    required Future<void> Function(File file) action,
  }) async {
    if (!temp.existsSync()) return;
    try {
      await for (final entity in temp.list(followLinks: false)) {
        if (entity is File &&
            TempRenderJanitor.isTempRenderName(p.basename(entity.path))) {
          if (protectedPaths.contains(_normalizePath(entity.path))) continue;
          await action(entity);
        }
      }
    } on Object catch (error) {
      Log.warning(
        '$_logName: scanning temp renders failed: $error',
        name: _logName,
        category: LogCategory.system,
      );
    }
  }

  Set<String> _normalizedProtectedTempRenderPaths() => {
    for (final filePath in _protectedTempRenderPaths())
      _normalizePath(filePath),
  };

  String _normalizePath(String filePath) => p.normalize(p.absolute(filePath));

  Future<void> _deleteDirContents(Directory dir) async {
    if (!dir.existsSync()) return;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        await _deleteQuietly(entity);
      }
    } on Object catch (error) {
      Log.warning(
        '$_logName: clearing ${dir.path} failed: $error',
        name: _logName,
        category: LogCategory.system,
      );
    }
  }

  Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
    } on Object {
      // Best-effort; a file we cannot delete is retried on the next clear.
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      Log.warning(
        '$_logName: clearCache failed: $error',
        name: _logName,
        category: LogCategory.system,
      );
    }
  }
}
