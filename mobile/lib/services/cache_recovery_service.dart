// ABOUTME: In-app service to clear corrupted cache and recover from database issues
// ABOUTME: Works on all platforms including iOS devices where shell scripts don't work

import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service to recover from corrupted app data and caches
class CacheRecoveryService {
  static const String _logName = 'CacheRecoveryService';

  /// Clear all app caches and databases to recover from corruption
  /// This works on iOS devices, Android, and desktop platforms
  static Future<bool> clearAllCaches() async {
    try {
      Log.info(
        '🧹 Starting cache recovery process',
        name: _logName,
        category: LogCategory.system,
      );

      int clearedItems = 0;

      // 1. Clear all Hive boxes
      clearedItems += await _clearHiveBoxes();

      // 2. Clear app support directory (sandboxed, safe)
      clearedItems += await _clearAppSupportDirectory();

      // 3. Clear temporary files
      clearedItems += await _clearTempDirectory();

      // 4. Clear specific cache directories
      clearedItems += await _clearCacheDirectory();

      Log.info(
        '✅ Cache recovery completed - cleared $clearedItems items',
        name: _logName,
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        '❌ Cache recovery failed: $e',
        name: _logName,
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Clear all Hive database boxes
  static Future<int> _clearHiveBoxes() async {
    int cleared = 0;

    try {
      // Get all open boxes and clear them
      // Note: We iterate over known box names instead of trying to access all open boxes
      final knownBoxNames = [
        'notifications',
        'user_profiles',
        'personal_events',
        'personal_events_metadata',
        'bookmarks',
        'pending_uploads',
        'video_cache',
        'secure_keys',
      ];

      for (final boxName in knownBoxNames) {
        try {
          if (Hive.isBoxOpen(boxName)) {
            final box = Hive.box(boxName);
            await box.clear();
            cleared++;
            Log.debug(
              'Cleared Hive box: $boxName',
              name: _logName,
              category: LogCategory.system,
            );
          }
        } catch (e) {
          Log.warning(
            'Failed to clear Hive box $boxName: $e',
            name: _logName,
            category: LogCategory.system,
          );
        }
      }

      // Also try to delete known box files from disk
      for (final boxName in knownBoxNames) {
        try {
          await Hive.deleteBoxFromDisk(boxName);
          cleared++;
        } catch (e) {
          // Box might not exist, which is fine
          Log.debug(
            'Box $boxName not found or already deleted',
            name: _logName,
            category: LogCategory.system,
          );
        }
      }
    } catch (e) {
      Log.warning(
        'Error clearing Hive boxes: $e',
        name: _logName,
        category: LogCategory.system,
      );
    }

    return cleared;
  }

  /// Durable database directory under Application Support that must NEVER be
  /// deleted by cache clearing. It holds the live SQLite database
  /// ({appSupport}/openvine/database/divine_db.db) — local-only user data
  /// (drafts, DMs, pending uploads/actions, reactions, reposts) that cannot be
  /// re-fetched. Segments mirror db_client's `buildSharedDatabasePath`.
  ///
  /// Deleting this directory while the Drift connection is open unlinks the
  /// file's inode, so every later write returns SqliteException(1032 DBMOVED)
  /// and is silently swallowed until the app restarts (#4968), on top of
  /// destroying the durable data.
  static const List<String> _durableDatabaseDirSegments = [
    'openvine',
    'database',
  ];

  /// Clear app support directory (NOT Documents - that's sandboxed on macOS),
  /// preserving the durable database directory (see [_durableDatabaseDirSegments]).
  static Future<int> _clearAppSupportDirectory() async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      if (!appSupportDir.existsSync()) return 0;
      final protectedPath = p.joinAll([
        appSupportDir.path,
        ..._durableDatabaseDirSegments,
      ]);
      return await deleteDirectoryContentsExcept(
        appSupportDir,
        protectedPath: protectedPath,
      );
    } catch (e) {
      Log.warning(
        'Error clearing app support directory: $e',
        name: _logName,
        category: LogCategory.system,
      );
      return 0;
    }
  }

  /// Recursively deletes the contents of [dir], preserving [protectedPath] and
  /// its subtree wherever it sits beneath [dir]. Directories that are ancestors
  /// of [protectedPath] are recursed into (so their other children are still
  /// cleared) rather than deleted wholesale; everything else is removed.
  ///
  /// This is how cache clearing avoids unlinking the open database file (#4968):
  /// the live `openvine/database` directory is skipped while the rest of
  /// Application Support — including the disposable cache_sync database under
  /// `openvine/cache` — is cleared.
  @visibleForTesting
  static Future<int> deleteDirectoryContentsExcept(
    Directory dir, {
    required String protectedPath,
  }) async {
    // Only apply protection when the path actually exists; otherwise there is
    // nothing to preserve and ancestors should be cleared like anything else.
    final protect = Directory(protectedPath).existsSync();
    if (protect && p.equals(dir.path, protectedPath)) {
      return 0;
    }
    var cleared = 0;
    for (final entity in dir.listSync()) {
      final path = entity.path;
      if (protect && p.equals(path, protectedPath)) {
        continue;
      }
      if (protect && entity is Directory && p.isWithin(path, protectedPath)) {
        cleared += await deleteDirectoryContentsExcept(
          entity,
          protectedPath: protectedPath,
        );
        continue;
      }
      try {
        await entity.delete(recursive: true);
        cleared++;
      } catch (e) {
        Log.debug(
          'Could not delete $path: $e',
          name: _logName,
          category: LogCategory.system,
        );
      }
    }
    return cleared;
  }

  /// Clear temporary files directory
  static Future<int> _clearTempDirectory() async {
    int cleared = 0;

    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final files = tempDir.listSync();
        for (final file in files) {
          try {
            await file.delete(recursive: true);
            cleared++;
          } catch (e) {
            Log.debug(
              'Could not delete temp file ${file.path}: $e',
              name: _logName,
              category: LogCategory.system,
            );
          }
        }
      }
    } catch (e) {
      Log.warning(
        'Error clearing temp directory: $e',
        name: _logName,
        category: LogCategory.system,
      );
    }

    return cleared;
  }

  /// Clear application cache directory
  static Future<int> _clearCacheDirectory() async {
    int cleared = 0;

    try {
      final cacheDir = await getApplicationCacheDirectory();
      if (cacheDir.existsSync()) {
        final files = cacheDir.listSync();
        for (final file in files) {
          try {
            await file.delete(recursive: true);
            cleared++;
          } catch (e) {
            Log.debug(
              'Could not delete cache file ${file.path}: $e',
              name: _logName,
              category: LogCategory.system,
            );
          }
        }
      }
    } catch (e) {
      Log.warning(
        'Error clearing cache directory: $e',
        name: _logName,
        category: LogCategory.system,
      );
    }

    return cleared;
  }

  /// Get total cache size for display purposes
  static Future<String> getCacheSizeInfo() async {
    try {
      int totalSize = 0;

      final dirs = [
        await getApplicationSupportDirectory(),
        await getTemporaryDirectory(),
        await getApplicationCacheDirectory(),
      ];

      for (final dir in dirs) {
        if (dir.existsSync()) {
          totalSize += await _getDirectorySize(dir);
        }
      }

      return _formatBytes(totalSize);
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Calculate directory size recursively
  static Future<int> _getDirectorySize(Directory directory) async {
    int size = 0;
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
    } catch (e) {
      // Ignore permission errors
    }
    return size;
  }

  /// Format bytes into human readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
