// ABOUTME: Service for persisting video clips to the clip library
// ABOUTME: Handles save, load, delete operations with JSON serialization

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
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

  /// How long a soft-deleted clip stays in the trash bin before the
  /// startup purge sweep permanently removes it. Shared between
  /// [purgeExpiredTrash] and the trash UI countdown so the user-facing
  /// "Auto-deletes in N days" copy stays in sync with the actual cutoff.
  static const Duration trashRetention = Duration(days: 30);

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

  /// Get all clips from the library, sorted by creation date (newest first).
  ///
  /// A single corrupt row (e.g. a clip persisted without a file path) is
  /// skipped and logged rather than discarding the entire library — one bad
  /// row must never hide every other clip.
  Future<List<DivineVideoClip>> getAllClips() async {
    try {
      final rows = await _clipsDao.getLibraryClips(ownerPubkey: ownerPubkey);
      final documentsPath = await getDocumentsPath();
      return rows
          .map((row) => _tryParseClipRow(row, documentsPath, label: 'clip'))
          .whereType<DivineVideoClip>()
          .toList();
    } catch (e) {
      Log.error(
        '❌ Failed to load clips: $e',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Deserialize a single clip [row], returning `null` (and logging) when the
  /// row is corrupt so one bad clip can't abort the whole list load.
  DivineVideoClip? _tryParseClipRow(
    ClipRow row,
    String documentsPath, {
    required String label,
  }) {
    try {
      final clipJson = json.decode(row.data) as Map<String, dynamic>;
      return DivineVideoClip.fromJson(clipJson, documentsPath);
    } catch (e) {
      Log.error(
        '❌ Skipping corrupt $label ${row.id}: $e',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Get a single clip by ID.
  ///
  /// Returns `null` when the row is missing or corrupt, matching the
  /// list loaders' skip-and-log behaviour so a single bad row can't throw
  /// out of a lookup. Callers already treat `null` as "no clip".
  Future<DivineVideoClip?> getClipById(String id) async {
    final row = await _clipsDao.getClipById(id);
    if (row == null) return null;

    final documentsPath = await getDocumentsPath();
    return _tryParseClipRow(row, documentsPath, label: 'clip');
  }

  /// Move a clip to the trash. The clip is hidden from active queries
  /// but its files remain on disk until [purgeExpiredTrash] sweeps them
  /// (default 30-day retention) or [hardDelete] is called explicitly.
  ///
  /// When [clearDraftId] is true the clip's `draft_id` is also nulled,
  /// decoupling it from any session it was recorded into so a restored
  /// clip lands in the library rather than a stale draft. The recorder
  /// path uses `clearDraftId: true`; the library tab leaves it false
  /// since those clips already have no draft.
  ///
  /// Returns true if the clip was found and trashed.
  Future<bool> softDelete(String id, {bool clearDraftId = false}) async {
    final ok = await _clipsDao.softDeleteClip(
      id: id,
      deletedAt: DateTime.now(),
      clearDraftId: clearDraftId,
    );
    if (ok) {
      Log.debug(
        '🗑️ Soft-deleted clip: $id',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
    }
    return ok;
  }

  /// Restore a trashed clip. The clip becomes visible to active queries
  /// again with its previous `draft_id` (library if `draft_id` is NULL).
  ///
  /// Returns true if a trashed clip with [id] was restored.
  Future<bool> restore(String id) async {
    final ok = await _clipsDao.restoreClip(id);
    if (ok) {
      Log.debug(
        '♻️ Restored clip: $id',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
    }
    return ok;
  }

  /// Permanently delete a clip and its files. Skips the trash; use
  /// [softDelete] for the standard delete flow.
  Future<void> hardDelete(String id) async {
    Log.debug(
      '🗑️ Hard-deleting clip: $id',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );

    final clip = await getClipById(id);
    if (clip == null) {
      Log.info(
        '🗑️ Clip already deleted, skipping: $id',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
      return;
    }

    await _clipsDao.deleteClip(id);

    await FileCleanupService.deleteRecordingClipFiles(
      clip,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
    );
  }

  /// Get all trashed library clips, newest-deleted-first.
  Future<List<DivineVideoClip>> getTrashedClips() async {
    try {
      final rows = await _clipsDao.getTrashedLibraryClips(
        ownerPubkey: ownerPubkey,
      );
      final documentsPath = await getDocumentsPath();
      final clips = <DivineVideoClip>[];
      for (final row in rows) {
        final clip = _tryParseClipRow(
          row,
          documentsPath,
          label: 'trashed clip',
        );
        if (clip != null) {
          clips.add(clip.copyWith(deletedAt: row.deletedAt));
        }
      }
      return clips;
    } catch (e) {
      Log.error(
        '❌ Failed to load trashed clips: $e',
        name: 'ClipLibraryService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Hard-delete every trashed clip older than [retention] (default 30
  /// days). Idempotent and safe to run repeatedly on app startup.
  ///
  /// Returns the number of clips purged.
  Future<int> purgeExpiredTrash({Duration retention = trashRetention}) async {
    final cutoff = DateTime.now().subtract(retention);
    final expired = await _clipsDao.getTrashedClipsOlderThan(
      cutoff,
      ownerPubkey: ownerPubkey,
    );
    if (expired.isEmpty) return 0;

    final documentsPath = await getDocumentsPath();
    var purged = 0;
    for (final row in expired) {
      try {
        final clipJson = json.decode(row.data) as Map<String, dynamic>;
        final clip = DivineVideoClip.fromJson(clipJson, documentsPath);
        await _clipsDao.deleteClip(row.id);
        await FileCleanupService.deleteRecordingClipFiles(
          clip,
          draftsDao: _draftsDao,
          clipsDao: _clipsDao,
        );
        purged++;
      } catch (e, s) {
        Log.error(
          '⚠️ Failed to purge trashed clip ${row.id}: $e',
          name: 'ClipLibraryService',
          category: LogCategory.video,
          error: e,
          stackTrace: s,
        );
      }
    }

    Log.info(
      '🧹 Purged $purged trashed clip(s) older than ${retention.inDays}d',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );
    return purged;
  }

  /// Clear all clips from the library and delete associated files
  Future<void> clearAllClips() async {
    Log.info(
      '🧹 Clearing all clips from library',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );
    final activeClips = await getAllClips();
    final trashedClips = await getTrashedClips();
    final clips = [...activeClips, ...trashedClips];

    // Clear active + trashed library rows first, then delete files.
    await _clipsDao.clearLibraryClips();

    // Delete files only if not referenced by drafts
    await FileCleanupService.deleteSavedClipsFiles(
      clips,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
    );
  }

  /// Recovers missing thumbnails and ghost frames for clips that were
  /// persisted before their assets had been generated.
  ///
  /// Returns the updated list if any clips were recovered, or the original
  /// list unchanged.
  Future<List<DivineVideoClip>> recoverMissingAssets(
    List<DivineVideoClip> clips,
  ) async {
    final incomplete = clips
        .where((c) => c.thumbnailPath == null || c.ghostFramePath == null)
        .toList();

    if (incomplete.isEmpty) return clips;

    Log.info(
      '📚 Recovering assets for ${incomplete.length} clip(s)',
      name: 'ClipLibraryService',
      category: LogCategory.video,
    );

    var updated = false;

    for (final clip in incomplete) {
      try {
        final videoPath = await clip.video.safeFilePath();
        var updatedClip = clip;

        if (clip.thumbnailPath == null) {
          final result = await VideoThumbnailService.extractThumbnail(
            videoPath: videoPath,
          );
          if (result != null) {
            updatedClip = updatedClip.copyWith(
              thumbnailPath: result.path,
              thumbnailTimestamp: result.timestamp,
            );
          }
        }

        if (clip.ghostFramePath == null) {
          final ghostPath = await VideoThumbnailService.extractLastFrame(
            videoPath: videoPath,
            videoDuration: clip.duration,
          );
          if (ghostPath != null) {
            updatedClip = updatedClip.copyWith(ghostFramePath: ghostPath);
          }
        }

        if (updatedClip != clip) {
          await saveClip(updatedClip);
          updated = true;
          Log.debug(
            '📚 Recovered assets for clip ${clip.id}',
            name: 'ClipLibraryService',
            category: LogCategory.video,
          );
        }
      } catch (e, s) {
        Log.error(
          '📚 Failed to recover assets for clip ${clip.id}: $e',
          name: 'ClipLibraryService',
          category: LogCategory.video,
          error: e,
          stackTrace: s,
        );
      }
    }

    if (updated) {
      return getAllClips();
    }
    return clips;
  }
}
