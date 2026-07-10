// ABOUTME: Manual storage maintenance for the settings "Storage" screen.
// ABOUTME: Clears re-downloadable/regenerable caches and audits the clip
// ABOUTME: library for broken entries — never touches user clip files.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Filename prefixes of temp-dir render leftovers that are safe to delete —
/// each is regenerated on the next save/upload (see
/// `WatermarkDownloadService` and `UploadManager`).
const List<String> _tempRenderPrefixes = ['watermarked_', 'merged_'];

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
    Set<String> Function()? protectedTempRenderPaths,
  }) : _videoCache = videoCache,
       _imageCache = imageCache,
       _clipLibrary = clipLibrary,
       _prefs = prefs,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _protectedTempRenderPaths =
           protectedTempRenderPaths ?? _noProtectedPaths;

  final MediaCacheManager _videoCache;
  final MediaCacheManager _imageCache;
  final ClipLibraryService _clipLibrary;
  final SharedPreferences _prefs;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final Set<String> Function() _protectedTempRenderPaths;

  static const String _logName = 'StorageManagementService';
  static const String _videoCacheDir = 'openvine_video_cache';
  static const String _imageCacheDir = 'openvine_image_cache';
  static const String _seamDir = 'transition_seams';

  static Set<String> _noProtectedPaths() => const {};

  /// Total bytes currently held by the clearable caches. Best-effort; a
  /// directory that cannot be read contributes zero rather than throwing.
  Future<int> cacheSizeBytes() async {
    final temp = await _temporaryDirectoryProvider();
    final docs = await _documentsDirectoryProvider();
    final protectedPaths = _normalizedProtectedTempRenderPaths();
    return await _dirSize(Directory(p.join(temp.path, _videoCacheDir))) +
        await _dirSize(Directory(p.join(temp.path, _imageCacheDir))) +
        await _dirSize(Directory(p.join(docs.path, _seamDir))) +
        await _tempRenderBytes(temp, protectedPaths);
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

  /// Library clips whose backing video file is gone — broken entries that can
  /// no longer play and should be cleaned up.
  Future<List<DivineVideoClip>> findBrokenClips() async {
    final clips = await _clipLibrary.getAllClips();
    return clips.where((clip) => !clip.hasResolvableVideoFile).toList();
  }

  /// Permanently removes the given broken [clips] from the library.
  Future<void> removeBrokenClips(List<DivineVideoClip> clips) async {
    for (final clip in clips) {
      await _clipLibrary.hardDelete(clip.id);
    }
  }

  /// The user-configured video-cache byte budget, or
  /// [kCacheLimitDefaultBytes] when none is set.
  int cacheLimitBytes() =>
      _prefs.getInt(kCacheLimitPrefKey) ?? kCacheLimitDefaultBytes;

  /// Persists [bytes] (clamped to
  /// `[kCacheLimitMinBytes, kCacheLimitMaxBytes]`) as the video-cache budget,
  /// applies it, and trims immediately so a lowered limit shrinks the cache
  /// right away.
  Future<void> setCacheLimit(int bytes) async {
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
        if (entity is File && _isTempRender(p.basename(entity.path))) {
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

  bool _isTempRender(String name) =>
      name.endsWith('.mp4') && _tempRenderPrefixes.any(name.startsWith);

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
