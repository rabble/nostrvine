// ABOUTME: Service for persisting vine drafts using Drift database
// ABOUTME: Handles save, load, delete, clear, and migration from SharedPreferences

import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

class DraftStorageService {
  DraftStorageService({
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
    this.ownerPubkey,
  }) : _draftsDao = draftsDao,
       _clipsDao = clipsDao;

  final DraftsDao _draftsDao;
  final ClipsDao _clipsDao;

  /// Hex pubkey of the current account. When set, new drafts are tagged
  /// with this owner and queries filter by it (plus legacy NULL rows).
  final String? ownerPubkey;

  static const String _storageKey = 'vine_drafts';

  /// Migrate drafts from SharedPreferences to Drift database.
  ///
  /// TODO(hm21): Remove migration in the future.
  /// That migration was created at 03.03.2026.
  Future<void> migrateOldDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return;

    final documentsPath = await getDocumentsPath();
    final jsonList = json.decode(jsonString) as List<dynamic>;

    final failedDrafts = <dynamic>[];
    var successCount = 0;

    for (final rawJson in jsonList) {
      try {
        final draftMap = rawJson as Map<String, dynamic>;
        final draft = DivineVideoDraft.fromJson(draftMap, documentsPath);

        // Upsert draft row (clips stripped from JSON blob)
        final draftJson = draft.toJson();
        draftJson.remove('clips');
        await _draftsDao.upsertDraft(
          id: draft.id,
          title: draft.title,
          description: draft.description,
          publishStatus: draft.publishStatus.name,
          createdAt: draft.createdAt,
          lastModified: draft.lastModified,
          publishAttempts: draft.publishAttempts,
          publishError: draft.publishError,
          data: json.encode(draftJson),
          renderedFilePath: draft.finalRenderedClip?.video.file?.path != null
              ? p.basename(
                  draft.finalRenderedClip!.video.file!.path,
                )
              : null,
          renderedThumbnailPath: draft.finalRenderedClip?.thumbnailPath != null
              ? p.basename(
                  draft.finalRenderedClip!.thumbnailPath!,
                )
              : null,
        );

        // Insert clips with composite IDs so draft clips
        // don't collide with library clips sharing the same
        // clip.id primary key.
        for (var i = 0; i < draft.clips.length; i++) {
          final clip = draft.clips[i];
          await _clipsDao.upsertClip(
            id: '${draft.id}:${clip.id}',
            draftId: draft.id,
            orderIndex: i,
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
        }
        successCount++;
      } catch (e) {
        Log.error(
          'Failed to migrate draft: $e',
          name: 'DraftStorageService',
          category: LogCategory.video,
        );
        failedDrafts.add(rawJson);
      }
    }

    if (failedDrafts.isEmpty) {
      // All drafts migrated successfully - remove the legacy key
      await prefs.remove(_storageKey);
      Log.info(
        '📂 Migrated $successCount drafts from SharedPreferences to Drift',
        name: 'DraftStorageService',
      );
    } else {
      // Keep only failed drafts for retry on next app launch
      await prefs.setString(_storageKey, json.encode(failedDrafts));
      Log.warning(
        '⚠️ Migrated $successCount drafts, ${failedDrafts.length} failed and '
        'will be retried on next launch',
        name: 'DraftStorageService',
        category: LogCategory.video,
      );
    }
  }

  /// Save a draft to storage. If a draft with the same ID exists, it will be
  /// updated. When updating, orphaned clip files (video/thumbnail) from the
  /// old draft are deleted.
  Future<void> saveDraft(DivineVideoDraft draft) async {
    Log.debug(
      '💾 Saving draft: ${draft.id}',
      name: 'DraftStorageService',
      category: LogCategory.video,
    );

    // Check for orphaned files before overwriting
    final existingDraft = await getDraftById(draft.id);
    if (existingDraft != null) {
      final newFilePaths = <String?>{
        for (final clip in draft.clips) ...[
          clip.video.file?.path,
          clip.thumbnailPath,
        ],
        draft.finalRenderedClip?.video.file?.path,
        draft.finalRenderedClip?.thumbnailPath,
      };

      final orphanedFiles = <String?>[
        for (final clip in existingDraft.clips) ...[
          if (!newFilePaths.contains(clip.video.file?.path))
            clip.video.file?.path,
          if (!newFilePaths.contains(clip.thumbnailPath)) clip.thumbnailPath,
        ],
        if (existingDraft.finalRenderedClip != null) ...[
          if (!newFilePaths.contains(
            existingDraft.finalRenderedClip?.video.file?.path,
          ))
            existingDraft.finalRenderedClip?.video.file?.path,
          if (!newFilePaths.contains(
            existingDraft.finalRenderedClip?.thumbnailPath,
          ))
            existingDraft.finalRenderedClip?.thumbnailPath,
        ],
      ];

      // Delete orphaned files (only if not referenced by clip library)
      await FileCleanupService.deleteFilesIfUnreferenced(
        orphanedFiles,
        draftsDao: _draftsDao,
        clipsDao: _clipsDao,
      );
    }

    // Upsert draft and clips atomically in a single transaction
    final draftJson = draft.toJson();
    // Remove clips from JSON blob – they live in their own table
    draftJson.remove('clips');

    final clipDataList = <DraftClipData>[];
    for (var i = 0; i < draft.clips.length; i++) {
      final clip = draft.clips[i];
      clipDataList.add(
        DraftClipData(
          id: clip.id,
          orderIndex: i,
          durationMs: clip.duration.inMilliseconds,
          recordedAt: clip.recordedAt,
          data: json.encode(clip.toJson()),
          filePath: clip.video.file?.path != null
              ? p.basename(clip.video.file!.path)
              : null,
          thumbnailPath: clip.thumbnailPath != null
              ? p.basename(clip.thumbnailPath!)
              : null,
        ),
      );
    }

    await _draftsDao.saveDraftWithClips(
      id: draft.id,
      title: draft.title,
      description: draft.description,
      publishStatus: draft.publishStatus.name,
      createdAt: draft.createdAt,
      lastModified: draft.lastModified,
      publishAttempts: draft.publishAttempts,
      publishError: draft.publishError,
      data: json.encode(draftJson),
      renderedFilePath: draft.finalRenderedClip?.video.file?.path != null
          ? p.basename(draft.finalRenderedClip!.video.file!.path)
          : null,
      renderedThumbnailPath: draft.finalRenderedClip?.thumbnailPath != null
          ? p.basename(draft.finalRenderedClip!.thumbnailPath!)
          : null,
      clipDataList: clipDataList,
      ownerPubkey: ownerPubkey,
    );
  }

  /// Get total count of drafts without loading their data.
  Future<int> getDraftCount() => _draftsDao.getCount(ownerPubkey: ownerPubkey);

  /// Returns drafts matching any of the given [statuses].
  ///
  /// Queries the database directly by `publish_status` column instead of
  /// loading all drafts into memory. Corrupted rows (0 clips) are cleaned
  /// up automatically.
  Future<List<DivineVideoDraft>> getDraftsByPublishStatuses(
    Set<PublishStatus> statuses,
  ) async {
    final documentsPath = await getDocumentsPath();
    final drafts = <DivineVideoDraft>[];
    final corruptedDraftIds = <String>[];

    for (final status in statuses) {
      final rows = await _draftsDao.getDraftsByStatus(
        status.name,
        ownerPubkey: ownerPubkey,
      );

      for (final row in rows) {
        final clipRows = await _clipsDao.getClipsByDraftId(row.id);

        if (clipRows.isEmpty) {
          corruptedDraftIds.add(row.id);
          continue;
        }

        drafts.add(
          DivineVideoDraft.fromDriftRow(
            row: row,
            clipRows: clipRows,
            documentsPath: documentsPath,
          ),
        );
      }
    }

    if (corruptedDraftIds.isNotEmpty) {
      Log.warning(
        '🧹 Removing ${corruptedDraftIds.length} corrupted '
        'draft(s) with 0 clips: $corruptedDraftIds',
        name: 'DraftStorageService',
        category: LogCategory.video,
      );
      for (final id in corruptedDraftIds) {
        await _draftsDao.deleteDraft(id);
      }
    }

    return drafts;
  }

  /// Updates the publish status of a draft directly in the database.
  ///
  /// More efficient than loading the full draft, mutating, and saving.
  Future<void> updatePublishStatus({
    required String draftId,
    required PublishStatus status,
    String? publishError,
    int? publishAttempts,
  }) async {
    await _draftsDao.updatePublishStatus(
      id: draftId,
      publishStatus: status.name,
      publishError: publishError,
      publishAttempts: publishAttempts,
    );
  }

  Future<DivineVideoDraft?> getDraftById(String id) async {
    final row = await _draftsDao.getDraftById(id);
    if (row == null) {
      Log.error('📝 Draft not found: $id', category: LogCategory.video);
      return null;
    }

    final clipRows = await _clipsDao.getClipsByDraftId(id);
    final documentsPath = await getDocumentsPath();
    return DivineVideoDraft.fromDriftRow(
      row: row,
      clipRows: clipRows,
      documentsPath: documentsPath,
    );
  }

  /// Get draft by ID with validation - filters out clips with missing video files.
  ///
  /// Returns null if draft not found or all clips are invalid.
  Future<DivineVideoDraft?> getValidatedDraftById(String id) async {
    final draft = await getDraftById(id);
    if (draft == null) return null;

    final validClips = _filterValidClips(draft.clips);
    if (validClips.isEmpty) {
      Log.warning(
        '📝 Draft $id has no valid clips - all video files missing',
        category: LogCategory.video,
      );
      return null;
    }

    if (validClips.length < draft.clips.length) {
      Log.info(
        '📝 Draft $id: ${validClips.length} valid clips '
        '(${draft.clips.length - validClips.length} removed)',
        category: LogCategory.video,
      );
    }

    return draft.copyWith(clips: validClips);
  }

  /// Get the autosaved draft with validation.
  ///
  /// Returns null if no autosave exists or all clips are invalid.
  Future<DivineVideoDraft?> getAutosaveDraft() async {
    return getValidatedDraftById(VideoEditorConstants.autoSaveId);
  }

  /// Check if a valid autosave draft exists (with at least one valid clip).
  Future<bool> hasValidAutosave() async {
    final draft = await getAutosaveDraft();
    return draft != null && draft.clips.isNotEmpty;
  }

  /// Filter clips to only include those with existing video files.
  List<DivineVideoClip> _filterValidClips(List<DivineVideoClip> clips) {
    return clips.where((clip) {
      final videoPath = clip.video.file?.path;
      if (videoPath == null) return false;
      return File(videoPath).existsSync();
    }).toList();
  }

  /// Get all drafts from storage
  Future<List<DivineVideoDraft>> getAllDrafts() async {
    try {
      final rows = await _draftsDao.getAllDrafts(
        ownerPubkey: ownerPubkey,
      );
      final documentsPath = await getDocumentsPath();
      final drafts = <DivineVideoDraft>[];
      final corruptedDraftIds = <String>[];

      for (final row in rows) {
        final clipRows = await _clipsDao.getClipsByDraftId(row.id);

        if (clipRows.isEmpty) {
          corruptedDraftIds.add(row.id);
          continue;
        }

        final draft = DivineVideoDraft.fromDriftRow(
          row: row,
          clipRows: clipRows,
          documentsPath: documentsPath,
        );
        drafts.add(draft);
      }

      // Clean up corrupted drafts (0 clips) in the background
      if (corruptedDraftIds.isNotEmpty) {
        Log.warning(
          '🧹 Removing ${corruptedDraftIds.length} corrupted '
          'draft(s) with 0 clips: $corruptedDraftIds',
          name: 'DraftStorageService',
          category: LogCategory.video,
        );
        for (final id in corruptedDraftIds) {
          await _draftsDao.deleteDraft(id);
        }
      }

      return drafts;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to load drafts: $e',
        name: 'DraftStorageService',
        category: LogCategory.video,
      );
      await CrashReportingService.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to load drafts from database',
      );
      rethrow;
    }
  }

  /// Delete a draft by ID and remove associated video/thumbnail files
  Future<void> deleteDraft(String id) async {
    Log.debug(
      '🗑️ Deleting draft: $id',
      name: 'DraftStorageService',
      category: LogCategory.video,
    );

    // Fetch draft before deleting so we can clean up files
    final draft = await getDraftById(id);
    if (draft == null) return;

    // Delete from DB first (clips cascade via FK), then delete files
    await _draftsDao.deleteDraft(id);

    // Delete clip files only if not referenced by clip library
    await FileCleanupService.deleteRecordingClipsFiles(
      draft.clips,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
    );

    // Delete final rendered clip if present
    if (draft.finalRenderedClip != null) {
      await FileCleanupService.deleteRecordingClipFiles(
        draft.finalRenderedClip!,
        draftsDao: _draftsDao,
        clipsDao: _clipsDao,
      );
    }
  }

  /// Clear all drafts from storage and delete associated files
  Future<void> clearAllDrafts() async {
    Log.info(
      '🧹 Clearing all drafts',
      name: 'DraftStorageService',
      category: LogCategory.video,
    );
    final drafts = await getAllDrafts();
    final allClips = drafts.expand((draft) => draft.clips).toList();
    final allFinalRenderedClips = drafts
        .map((draft) => draft.finalRenderedClip)
        .whereType<DivineVideoClip>()
        .toList();

    // Clear DB first (clips cascade via FK), then delete files
    await _draftsDao.clearAll();

    // Delete clip files only if not referenced by clip library
    await FileCleanupService.deleteRecordingClipsFiles(
      allClips,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
    );
    await FileCleanupService.deleteRecordingClipsFiles(
      allFinalRenderedClips,
      draftsDao: _draftsDao,
      clipsDao: _clipsDao,
    );
  }
}
