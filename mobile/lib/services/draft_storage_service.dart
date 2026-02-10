// ABOUTME: Service for persisting vine drafts using shared_preferences
// ABOUTME: Handles save, load, delete, and clear operations with JSON serialization

import 'dart:convert';
import 'dart:io';

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/utils/android_path_migration.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraftStorageService {
  DraftStorageService();

  SharedPreferences? _prefs;
  static const String _storageKey = 'vine_drafts';

  Future<SharedPreferences> get _prefsAsync async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Migrate drafts from old Android /files/ path to /app_flutter/
  Future<void> migrateOldDrafts() async {
    final prefs = await _prefsAsync;
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return;

    final documentsPath = await getDocumentsPath();
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    // Parse with useOriginalPath to get the raw paths from JSON
    final draftsWithOriginalPaths = jsonList
        .map(
          (json) => VineDraft.fromJson(
            json as Map<String, dynamic>,
            documentsPath,
            useOriginalPath: true,
          ),
        )
        .toList();

    // Collect all file paths that need migration
    final pathsToMigrate = <String?>[
      for (final draft in draftsWithOriginalPaths)
        for (final clip in draft.clips) ...[
          clip.video.file?.path,
          clip.thumbnailPath,
        ],
    ];

    // Run the migration
    final migrated = await migrateAndroidPaths(
      documentsPath: documentsPath,
      filePaths: pathsToMigrate,
    );

    if (migrated) {
      Log.info(
        '📂 Migrated drafts from old Android paths',
        name: 'DraftStorageService',
      );
    }
  }

  /// Save a draft to storage. If a draft with the same ID exists, it will be updated.
  /// When updating, orphaned clip files (video/thumbnail) from the old draft are deleted.
  Future<void> saveDraft(VineDraft draft) async {
    Log.debug(
      '💾 Saving draft: ${draft.id}',
      name: 'DraftStorageService',
      category: LogCategory.video,
    );
    final drafts = await getAllDrafts();

    // Check if draft with same ID exists
    final existingIndex = drafts.indexWhere((d) => d.id == draft.id);

    if (existingIndex != -1) {
      final existingDraft = drafts[existingIndex];

      // Find orphaned files (in old draft but not in new draft)
      final newFilePaths = <String?>{
        for (final clip in draft.clips) ...[
          clip.video.file?.path,
          clip.thumbnailPath,
        ],
      };

      final orphanedFiles = <String?>[
        for (final clip in existingDraft.clips) ...[
          if (!newFilePaths.contains(clip.video.file?.path))
            clip.video.file?.path,
          if (!newFilePaths.contains(clip.thumbnailPath)) clip.thumbnailPath,
        ],
      ];

      // Delete orphaned files (only if not referenced by clip library)
      await FileCleanupService.deleteFilesIfUnreferenced(orphanedFiles);

      // Update existing draft
      drafts[existingIndex] = draft;
    } else {
      // Add new draft
      drafts.add(draft);
    }

    await _saveDrafts(drafts);
  }

  Future<VineDraft?> getDraftById(String id) async {
    final drafts = await getAllDrafts();

    final index = drafts.indexWhere((d) => d.id == id);

    if (index >= 0) return drafts[index];

    Log.error('📝 Draft not found: $id', category: LogCategory.video);
    return null;
  }

  /// Get draft by ID with validation - filters out clips with missing video files.
  ///
  /// Returns null if draft not found or all clips are invalid.
  Future<VineDraft?> getValidatedDraftById(String id) async {
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
  Future<VineDraft?> getAutosaveDraft() async {
    return getValidatedDraftById(VideoEditorConstants.autoSaveId);
  }

  /// Check if a valid autosave draft exists (with at least one valid clip).
  Future<bool> hasValidAutosave() async {
    final draft = await getAutosaveDraft();
    return draft != null && draft.clips.isNotEmpty;
  }

  /// Filter clips to only include those with existing video files.
  List<RecordingClip> _filterValidClips(List<RecordingClip> clips) {
    return clips.where((clip) {
      final videoPath = clip.video.file?.path;
      if (videoPath == null) return false;
      return File(videoPath).existsSync();
    }).toList();
  }

  /// Get all drafts from storage
  Future<List<VineDraft>> getAllDrafts() async {
    try {
      final prefs = await _prefsAsync;
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final documentsPath = await getDocumentsPath();
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

      final drafts = jsonList
          .map(
            (json) =>
                VineDraft.fromJson(json as Map<String, dynamic>, documentsPath),
          )
          .toList();

      return drafts;
    } catch (e) {
      Log.error(
        '❌ Failed to load drafts: $e',
        name: 'DraftStorageService',
        category: LogCategory.video,
      );
      // If storage is corrupted, return empty list
      return [];
    }
  }

  /// Delete a draft by ID and remove associated video/thumbnail files
  Future<void> deleteDraft(String id) async {
    Log.debug(
      '🗑️ Deleting draft: $id',
      name: 'DraftStorageService',
      category: LogCategory.video,
    );
    final drafts = await getAllDrafts();
    final draftIndex = drafts.indexWhere((draft) => draft.id == id);

    if (draftIndex != -1) {
      final draft = drafts[draftIndex];
      drafts.removeAt(draftIndex);

      // Save first, then delete files (so reference check sees updated state)
      await _saveDrafts(drafts);

      // Delete clip files only if not referenced by clip library
      await FileCleanupService.deleteRecordingClipsFiles(draft.clips);
      return;
    }

    await _saveDrafts(drafts);
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

    // Clear storage first, then delete files (so reference check sees updated state)
    final prefs = await _prefsAsync;
    await prefs.remove(_storageKey);

    // Delete clip files only if not referenced by clip library
    await FileCleanupService.deleteRecordingClipsFiles(allClips);
  }

  /// Internal helper to save drafts list to storage
  Future<void> _saveDrafts(List<VineDraft> drafts) async {
    final prefs = await _prefsAsync;
    final jsonList = drafts.map((draft) => draft.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await prefs.setString(_storageKey, jsonString);
  }
}
