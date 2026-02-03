// ABOUTME: Central service for safe file deletion with reference checking
// ABOUTME: Only deletes files when not referenced by drafts OR clip library
// ABOUTME: Uses static methods - no Riverpod dependency

import 'dart:convert';

import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for safely deleting clip files while respecting references.
///
/// Files may be shared between drafts and the clip library. This service
/// checks both storage locations before deleting to prevent data loss.
class FileCleanupService {
  static const String _draftsKey = 'vine_drafts';
  static const String _clipLibraryKey = 'clip_library';

  /// Gets all file paths currently referenced by drafts and clip library
  static Future<Set<String>> _getAllReferencedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final documentsPath = await getDocumentsPath();
    final paths = <String>{};

    // Collect paths from drafts
    final draftsJson = prefs.getString(_draftsKey);
    if (draftsJson != null && draftsJson.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(draftsJson) as List<dynamic>;
        for (final draftJson in jsonList) {
          final draft = VineDraft.fromJson(
            draftJson as Map<String, dynamic>,
            documentsPath,
          );
          for (final clip in draft.clips) {
            if (clip.video.file?.path != null) {
              paths.add(clip.video.file!.path);
            }
            if (clip.thumbnailPath != null) {
              paths.add(clip.thumbnailPath!);
            }
          }
        }
      } catch (e) {
        Log.warning(
          '⚠️ Failed to parse drafts for reference check: $e',
          name: 'FileCleanupService',
          category: LogCategory.video,
        );
      }
    }

    // Collect paths from clip library
    final clipsJson = prefs.getString(_clipLibraryKey);
    if (clipsJson != null && clipsJson.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(clipsJson) as List<dynamic>;
        for (final clipJson in jsonList) {
          final clip = SavedClip.fromJson(
            clipJson as Map<String, dynamic>,
            documentsPath,
          );
          paths.add(clip.filePath);
          if (clip.thumbnailPath != null) {
            paths.add(clip.thumbnailPath!);
          }
        }
      } catch (e) {
        Log.warning(
          '⚠️ Failed to parse clip library for reference check: $e',
          name: 'FileCleanupService',
          category: LogCategory.video,
        );
      }
    }

    return paths;
  }

  /// Deletes a file only if it's not referenced elsewhere
  static Future<void> deleteFileIfUnreferenced(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;

    final referencedPaths = await _getAllReferencedPaths();

    if (referencedPaths.contains(filePath)) {
      Log.info(
        '🔗 File still referenced, skipping delete: $filePath',
        name: 'FileCleanupService',
        category: LogCategory.video,
      );
      return;
    }

    await _deleteFile(filePath);
  }

  /// Deletes multiple files, only those not referenced elsewhere
  static Future<void> deleteFilesIfUnreferenced(List<String?> filePaths) async {
    final referencedPaths = await _getAllReferencedPaths();

    final filesToDelete = filePaths
        .where((path) => path != null && path.isNotEmpty)
        .where((path) => !referencedPaths.contains(path))
        .cast<String>()
        .toList();

    await Future.wait(filesToDelete.map(_deleteFile));
  }

  /// Deletes files for a RecordingClip if not referenced
  static Future<void> deleteRecordingClipFiles(RecordingClip clip) async {
    await deleteFilesIfUnreferenced([
      clip.video.file?.path,
      clip.thumbnailPath,
    ]);
  }

  /// Deletes files for multiple RecordingClips if not referenced
  static Future<void> deleteRecordingClipsFiles(
    List<RecordingClip> clips,
  ) async {
    final paths = clips
        .expand((clip) => [clip.video.file?.path, clip.thumbnailPath])
        .toList();

    await deleteFilesIfUnreferenced(paths);
  }

  /// Deletes files for a SavedClip if not referenced
  static Future<void> deleteSavedClipFiles(SavedClip clip) async {
    await deleteFilesIfUnreferenced([clip.filePath, clip.thumbnailPath]);
  }

  /// Deletes files for multiple SavedClips if not referenced
  static Future<void> deleteSavedClipsFiles(List<SavedClip> clips) async {
    final paths = clips
        .expand((clip) => [clip.filePath, clip.thumbnailPath])
        .toList();

    await deleteFilesIfUnreferenced(paths);
  }

  /// Internal helper to delete a single file
  static Future<void> _deleteFile(String filePath) async {
    try {
      await File(filePath).delete();
      Log.info(
        '🗑️ Deleted file: $filePath',
        name: 'FileCleanupService',
        category: LogCategory.video,
      );
    } on PathNotFoundException {
      Log.info(
        '🗑️ File already deleted: $filePath',
        name: 'FileCleanupService',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        '⚠️ Failed to delete file: $filePath - $e',
        name: 'FileCleanupService',
        category: LogCategory.video,
      );
    }
  }
}
