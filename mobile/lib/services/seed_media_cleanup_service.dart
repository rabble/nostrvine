// ABOUTME: One-time removal of stranded seed media from the video cache dir
// ABOUTME: Deletes files the retired preloader wrote that no code could read

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Removes the stranded seed media the retired `SeedMediaPreloadService`
/// wrote into the video cache directory on first launch.
///
/// The preloader copied bundled videos as raw `<eventId>` filenames and
/// stills as `thumbnail_<eventId>.jpg`, expecting the cache manager to
/// discover them from the directory — a flow no shipped cache manager ever
/// implemented, so the files were never readable. Their names are also
/// deliberately invisible to `MediaCacheManager`'s reclamation and byte
/// eviction, so they only ever inflated the reported cache usage (#8242).
///
/// The `.seed_media_loaded` marker gates the sweep: it exists exactly on
/// installs the preloader wrote to, so everyone else pays one `existsSync`.
/// The marker is deleted last, and only when every targeted file was
/// removed, so a partial cleanup retries on the next launch.
class SeedMediaCleanupService {
  /// Creates the cleanup service. [tempDirectoryProvider] is injectable for
  /// tests and otherwise resolves the platform temporary directory the video
  /// cache lives under.
  SeedMediaCleanupService({
    @visibleForTesting Future<Directory> Function()? tempDirectoryProvider,
  }) : _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory;

  final Future<Directory> Function() _tempDirectoryProvider;

  static const String _markerName = '.seed_media_loaded';

  /// Event ids are lowercase hex; the preloader used them verbatim as
  /// filenames, with no extension. Nothing else writes this shape — managed
  /// downloads carry a `_<micros>_<seq>.<ext>` suffix and the inherited
  /// flutter_cache_manager path writes uuid-named files.
  static final RegExp _seedVideoPattern = RegExp(r'^[0-9a-f]{64}$');

  static final RegExp _seedThumbnailPattern = RegExp(
    r'^thumbnail_[0-9a-f]{64}\.jpg$',
  );

  /// Deletes stranded seed files, then the marker. Never throws.
  Future<void> cleanUpStrandedSeedMediaIfNeeded() async {
    try {
      final tempDir = await _tempDirectoryProvider();
      final cacheDir = Directory(
        path.join(tempDir.path, kVideoCacheDirectoryName),
      );
      final marker = File(path.join(cacheDir.path, _markerName));
      if (!marker.existsSync()) return;

      var deletedCount = 0;
      var deletedBytes = 0;
      var failedCount = 0;
      await for (final entity in cacheDir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = path.basename(entity.path);
        if (!_seedVideoPattern.hasMatch(name) &&
            !_seedThumbnailPattern.hasMatch(name)) {
          continue;
        }
        try {
          final size = entity.statSync().size;
          await entity.delete();
          deletedCount++;
          deletedBytes += size;
        } on Object {
          // Leave the marker in place below so the next launch retries.
          failedCount++;
        }
      }

      if (failedCount == 0) {
        await marker.delete();
      }
      Log.info(
        'SeedMediaCleanup: removed $deletedCount stranded seed files '
        '($deletedBytes bytes, $failedCount failed)',
        name: 'SeedMediaCleanup',
        category: LogCategory.system,
      );
    } on Object catch (error) {
      // Best-effort: the marker survives, so the next launch retries.
      Log.warning(
        'SeedMediaCleanup: cleanup failed: $error',
        name: 'SeedMediaCleanup',
        category: LogCategory.system,
      );
    }
  }
}
