// ABOUTME: Central service for safe file deletion with reference checking
// ABOUTME: Only deletes files when not referenced by drafts OR clip library
// ABOUTME: Uses static methods with DAO parameters for database access

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for safely deleting clip files while respecting references.
///
/// Files may be shared between drafts and the clip library. This service
/// checks both storage locations before deleting to prevent data loss.
///
/// All public methods require [DraftsDao] and [ClipsDao] parameters
/// to query referenced file paths from the Drift database.
class FileCleanupService {
  /// Gets all file paths currently referenced by drafts and clip library.
  ///
  /// Deserializes all clips and drafts from the database into their
  /// model objects and reads video/thumbnail paths directly.
  static Future<Set<String>> _getAllReferencedPaths({
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    final documentsPath = await getDocumentsPath();
    final paths = <String>{};

    // Collect paths from all clips (both draft clips and library clips)
    try {
      final clipRows = await clipsDao.getAllClips();
      for (final clipRow in clipRows) {
        try {
          final clipJson = json.decode(clipRow.data) as Map<String, dynamic>;
          final clip = DivineVideoClip.fromJson(clipJson, documentsPath);
          final filePath = clip.video.file?.path;
          if (filePath != null) paths.add(filePath);
          if (clip.thumbnailPath != null) {
            paths.add(clip.thumbnailPath!);
          }
        } catch (e) {
          Log.warning(
            '⚠️ Failed to parse clip data for reference check: $e',
            name: 'FileCleanupService',
            category: LogCategory.video,
          );
        }
      }
    } catch (e) {
      Log.warning(
        '⚠️ Failed to read clips for reference check: $e',
        name: 'FileCleanupService',
        category: LogCategory.video,
      );
    }

    // Collect paths from drafts (for finalRenderedClip)
    try {
      final draftRows = await draftsDao.getAllDrafts();
      for (final draftRow in draftRows) {
        try {
          final clipRows = await clipsDao.getClipsByDraftId(draftRow.id);
          final draft = DivineVideoDraft.fromDriftRow(
            row: draftRow,
            clipRows: clipRows,
            documentsPath: documentsPath,
          );
          final rendered = draft.finalRenderedClip;
          if (rendered != null) {
            final filePath = rendered.video.file?.path;
            if (filePath != null) paths.add(filePath);
            if (rendered.thumbnailPath != null) {
              paths.add(rendered.thumbnailPath!);
            }
          }
        } catch (e) {
          Log.warning(
            '⚠️ Failed to parse draft data for reference check: $e',
            name: 'FileCleanupService',
            category: LogCategory.video,
          );
        }
      }
    } catch (e) {
      Log.warning(
        '⚠️ Failed to read drafts for reference check: $e',
        name: 'FileCleanupService',
        category: LogCategory.video,
      );
    }

    return paths;
  }

  /// Deletes a file only if it's not referenced elsewhere.
  ///
  /// Throws:
  ///
  /// * No exceptions – errors are logged and silently handled.
  static Future<void> deleteFileIfUnreferenced(
    String? filePath, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    if (filePath == null || filePath.isEmpty) return;

    final referencedPaths = await _getAllReferencedPaths(
      draftsDao: draftsDao,
      clipsDao: clipsDao,
    );

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

  /// Deletes multiple files, only those not referenced elsewhere.
  static Future<void> deleteFilesIfUnreferenced(
    List<String?> filePaths, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    final referencedPaths = await _getAllReferencedPaths(
      draftsDao: draftsDao,
      clipsDao: clipsDao,
    );

    final filesToDelete = filePaths
        .where((path) => path != null && path.isNotEmpty)
        .where((path) => !referencedPaths.contains(path))
        .cast<String>()
        .toList();

    await Future.wait(filesToDelete.map(_deleteFile));
  }

  /// Deletes files for a RecordingClip if not referenced
  static Future<void> deleteRecordingClipFiles(
    DivineVideoClip clip, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    await deleteFilesIfUnreferenced(
      [clip.video.file?.path, clip.thumbnailPath],
      draftsDao: draftsDao,
      clipsDao: clipsDao,
    );
  }

  /// Deletes files for multiple RecordingClips if not referenced
  static Future<void> deleteRecordingClipsFiles(
    List<DivineVideoClip> clips, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    final paths = clips
        .expand((clip) => [clip.video.file?.path, clip.thumbnailPath])
        .toList();

    await deleteFilesIfUnreferenced(
      paths,
      draftsDao: draftsDao,
      clipsDao: clipsDao,
    );
  }

  /// Deletes files for a SavedClip if not referenced
  static Future<void> deleteSavedClipFiles(
    DivineVideoClip clip, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    await deleteFilesIfUnreferenced(
      [clip.video.file?.path, clip.thumbnailPath],
      draftsDao: draftsDao,
      clipsDao: clipsDao,
    );
  }

  /// Deletes files for multiple SavedClips if not referenced
  static Future<void> deleteSavedClipsFiles(
    List<DivineVideoClip> clips, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    final paths = <String?>[
      for (final clip in clips) ...[
        await clip.video.safeFilePath(),
        clip.thumbnailPath,
      ],
    ];

    await deleteFilesIfUnreferenced(
      paths,
      draftsDao: draftsDao,
      clipsDao: clipsDao,
    );
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
