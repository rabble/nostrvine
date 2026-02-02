// ABOUTME: Service for persisting vine drafts using shared_preferences
// ABOUTME: Handles save, load, delete, and clear operations with JSON serialization

import 'dart:convert';

import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraftStorageService {
  DraftStorageService(this._prefs);

  final SharedPreferences _prefs;
  static const String _storageKey = 'vine_drafts';

  /// Save a draft to storage. If a draft with the same ID exists, it will be updated.
  /// When updating, orphaned clip files (video/thumbnail) from the old draft are deleted.
  Future<void> saveDraft(VineDraft draft) async {
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

  /// Get all drafts from storage
  Future<List<VineDraft>> getAllDrafts() async {
    try {
      final String? jsonString = _prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => VineDraft.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If storage is corrupted, return empty list
      return [];
    }
  }

  /// Delete a draft by ID and remove associated video/thumbnail files
  Future<void> deleteDraft(String id) async {
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
    final drafts = await getAllDrafts();
    final allClips = drafts.expand((draft) => draft.clips).toList();

    // Clear storage first, then delete files (so reference check sees updated state)
    await _prefs.remove(_storageKey);

    // Delete clip files only if not referenced by clip library
    await FileCleanupService.deleteRecordingClipsFiles(allClips);
  }

  /// Internal helper to save drafts list to storage
  Future<void> _saveDrafts(List<VineDraft> drafts) async {
    final jsonList = drafts.map((draft) => draft.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await _prefs.setString(_storageKey, jsonString);
  }
}
