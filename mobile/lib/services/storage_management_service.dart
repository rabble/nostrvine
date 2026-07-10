// ABOUTME: Manual storage maintenance for the settings "Storage" screen.
// ABOUTME: Clears re-downloadable/regenerable caches and audits the clip
// ABOUTME: library for broken entries — never touches user clip files.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
  /// directories.
  StorageManagementService({
    required MediaCacheManager videoCache,
    required MediaCacheManager imageCache,
    required ClipLibraryService clipLibrary,
    @visibleForTesting Future<Directory> Function()? temporaryDirectoryProvider,
    @visibleForTesting Future<Directory> Function()? documentsDirectoryProvider,
  }) : _videoCache = videoCache,
       _imageCache = imageCache,
       _clipLibrary = clipLibrary,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final MediaCacheManager _videoCache;
  final MediaCacheManager _imageCache;
  final ClipLibraryService _clipLibrary;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final Future<Directory> Function() _documentsDirectoryProvider;

  static const String _logName = 'StorageManagementService';
  static const String _videoCacheDir = 'openvine_video_cache';
  static const String _imageCacheDir = 'openvine_image_cache';
  static const String _seamDir = 'transition_seams';

  /// Total bytes currently held by the clearable caches. Best-effort; a
  /// directory that cannot be read contributes zero rather than throwing.
  Future<int> cacheSizeBytes() async {
    final temp = await _temporaryDirectoryProvider();
    final docs = await _documentsDirectoryProvider();
    return await _dirSize(Directory(p.join(temp.path, _videoCacheDir))) +
        await _dirSize(Directory(p.join(temp.path, _imageCacheDir))) +
        await _dirSize(Directory(p.join(docs.path, _seamDir))) +
        await _tempRenderBytes(temp);
  }

  /// Clears every re-downloadable / regenerable cache. The clip library and
  /// all other user content are left untouched.
  Future<void> clearCaches() async {
    await _guard(_videoCache.clearCache);
    await _guard(_imageCache.clearCache);
    final temp = await _temporaryDirectoryProvider();
    await _forEachTempRender(temp, _deleteQuietly);
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

  Future<int> _tempRenderBytes(Directory temp) async {
    var size = 0;
    await _forEachTempRender(temp, (file) async => size += await file.length());
    return size;
  }

  Future<void> _forEachTempRender(
    Directory temp,
    Future<void> Function(File file) action,
  ) async {
    if (!temp.existsSync()) return;
    try {
      await for (final entity in temp.list(followLinks: false)) {
        if (entity is File && _isTempRender(p.basename(entity.path))) {
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
