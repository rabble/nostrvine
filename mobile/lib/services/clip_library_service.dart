// ABOUTME: Service for persisting video clips to the clip library
// ABOUTME: Handles save, load, delete operations with JSON serialization

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

class ClipLibraryService {
  ClipLibraryService({
    required ClipsDao clipsDao,
    required DraftsDao draftsDao,
    this.ownerPubkey,
  }) : _clipsDao = clipsDao,
       _draftsDao = draftsDao;

  final ClipsDao _clipsDao;
  final DraftsDao _draftsDao;

  /// Hex pubkey of the current account. When set, new clips are tagged
  /// with this owner and queries filter by it (plus legacy NULL rows).
  final String? ownerPubkey;

  static const String _storageKey = 'clip_library';

  /// Migrate clips from SharedPreferences to Drift database.
  ///
  /// TODO(hm21): Remove migration in the future.
  /// That migration was created at 03.03.2026.
  Future<void> migrateOldClips() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return;

    final documentsPath = await getDocumentsPath();
    final jsonList = json.decode(jsonString) as List<dynamic>;

    final failedClips = <dynamic>[];
    var successCount = 0;

    for (final rawJson in jsonList) {
      try {
        final clipMap = rawJson as Map<String, dynamic>;
        final clip = DivineVideoClip.fromJson(clipMap, documentsPath);

        await _clipsDao.upsertClip(
          id: clip.id,
          orderIndex: 0,
          durationMs: clip.duration.inMilliseconds,
          recordedAt: clip.recordedAt,
          data: json.encode(clip.toJson()),
          filePath: clip.video.file?.path != null
              ? p.basename(clip.video.file!.path)
              : null,
          thumbnailPath: clip.thumbnailPath != null
              ? p.basename(clip.thumbnailPath!)
              : null,
        );
        successCount++;
      } catch (e) {
        Log.error(
          'Failed to migrate clip: $e',
          name: 'ClipLibraryService',
          category: LogCategory.video,
        );
        failedClips.add(rawJson);
      }
    }

    if (failedClips.isEmpty) {
      // All clips migrated successfully - remove the legacy key
      await prefs.remove(_storageKey);
      Log.info(
        '📂 Migrated $successCount clips from SharedPreferences to Drift',
        name: 'ClipLibraryService',
      );
    } else {
      // Keep only failed clips for retry on next app launch
      await prefs.setString(_storageKey, json.encode(failedClips));
      Log.warning(
        '⚠️ Migrated $successCount clips, ${failedClips.length} failed and '
        'will be retried on next launch',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
    }
  }

  /// Save a clip to the library. Updates existing clip if ID matches.
  Future<void> saveClip(DivineVideoClip clip) async {
    Log.debug(
      '💾 Saving clip to library: ${clip.id}',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );

    await _clipsDao.upsertClip(
      id: clip.id,
      orderIndex: 0,
      durationMs: clip.duration.inMilliseconds,
      recordedAt: clip.recordedAt,
      data: json.encode(clip.toJson()),
      filePath: clip.video.file?.path != null
          ? p.basename(clip.video.file!.path)
          : null,
      thumbnailPath: clip.thumbnailPath != null
          ? p.basename(clip.thumbnailPath!)
          : null,
      ownerPubkey: ownerPubkey,
    );
  }

  /// Get all clips from the library, sorted by creation date (newest first)
  Future<List<DivineVideoClip>> getAllClips() async {
    try {
      final rows = await _clipsDao.getLibraryClips(
        ownerPubkey: ownerPubkey,
      );
      final documentsPath = await getDocumentsPath();

      return rows.map((row) {
        final clipJson = json.decode(row.data) as Map<String, dynamic>;
        return DivineVideoClip.fromJson(clipJson, documentsPath);
      }).toList();
    } catch (e) {
      Log.error(
        '❌ Failed to load clips: $e',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Get a single clip by ID
  Future<DivineVideoClip?> getClipById(String id) async {
    final row = await _clipsDao.getClipById(id);
    if (row == null) return null;

    final documentsPath = await getDocumentsPath();
    final clipJson = json.decode(row.data) as Map<String, dynamic>;
    return DivineVideoClip.fromJson(clipJson, documentsPath);
  }

  /// Delete a clip by ID and remove associated files if not referenced
  Future<void> deleteClip(String id) async {
    Log.debug(
      '🗑️ Deleting clip from library: $id',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );

    // Fetch clip before deleting so we can clean up files
    final clip = await getClipById(id);
    if (clip == null) return;

    // Delete from DB, then clean up files
    await _clipsDao.deleteClip(id);

    // Delete files only if not referenced by drafts
    await FileCleanupService.deleteRecordingClipFiles(
      clip,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
    );
  }

  /// Clear all clips from the library and delete associated files
  Future<void> clearAllClips() async {
    Log.info(
      '🧹 Clearing all clips from library',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );
    final clips = await getAllClips();

    // Clear DB first, then delete files
    await _clipsDao.clearLibraryClips();

    // Delete files only if not referenced by drafts
    await FileCleanupService.deleteSavedClipsFiles(
      clips,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
    );
  }
}
