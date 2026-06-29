// ABOUTME: Central service for safe file deletion with reference checking
// ABOUTME: Only deletes files when not referenced by drafts OR clip library
// ABOUTME: Uses indexed file_path columns for efficient lookups

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:path/path.dart' as p;
import 'package:unified_logger/unified_logger.dart';

/// Service for safely deleting clip files while respecting references.
///
/// Files may be shared between drafts and the clip library. This service
/// checks both storage locations before deleting to prevent data loss.
///
/// Uses indexed `file_path` / `thumbnail_path` columns on the clips table
/// and draft-owned file reference columns on the drafts table for efficient
/// lookups without loading all rows.
class FileCleanupService {
  /// Checks if a file is referenced by any clip or draft.
  ///
  /// Extracts the basename from [filePath] and queries the indexed
  /// columns in both the clips and drafts tables.
  static Future<bool> _isFileReferenced(
    String filePath, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    final filename = p.basename(filePath);
    if (await clipsDao.isFileReferenced(filename)) return true;
    if (await draftsDao.isDraftFileReferenced(filename)) return true;
    return false;
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
    if (!File(filePath).existsSync()) return;

    if (await _isFileReferenced(
      filePath,
      draftsDao: draftsDao,
      clipsDao: clipsDao,
    )) {
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
    final validPaths = filePaths
        .where((path) => path != null && path.isNotEmpty)
        .cast<String>()
        .toList();

    for (final path in validPaths) {
      await deleteFileIfUnreferenced(
        path,
        draftsDao: draftsDao,
        clipsDao: clipsDao,
      );
    }
  }

  /// Deletes draft-local audio files in [audioFilePaths], skipping any still
  /// referenced elsewhere.
  ///
  /// Imported audio and voice-over recordings live in a draft's editor
  /// metadata rather than an indexed file column, so a surviving draft that
  /// shares the same file (e.g. a draft and its publish copy) cannot be
  /// detected by the indexed-column check. The caller therefore supplies
  /// [referencedAudioFilenames] — the basenames of local audio still
  /// referenced by other drafts — and a file is kept when its basename is in
  /// that set. The indexed clip/draft reference check still runs as a
  /// defensive backstop.
  ///
  /// Throws:
  ///
  /// * No exceptions – errors are logged and silently handled.
  static Future<void> deleteDraftAudioFiles(
    Iterable<String> audioFilePaths, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
    Set<String> referencedAudioFilenames = const {},
  }) async {
    for (final path in audioFilePaths) {
      if (path.isEmpty) continue;
      if (referencedAudioFilenames.contains(p.basename(path))) {
        Log.info(
          '🔗 Audio still referenced by another draft, skipping delete: $path',
          name: 'FileCleanupService',
          category: LogCategory.video,
        );
        continue;
      }
      await deleteFileIfUnreferenced(
        path,
        draftsDao: draftsDao,
        clipsDao: clipsDao,
      );
    }
  }

  /// Deletes files for a RecordingClip if not referenced
  static Future<void> deleteRecordingClipFiles(
    DivineVideoClip clip, {
    required DraftsDao draftsDao,
    required ClipsDao clipsDao,
  }) async {
    await deleteFilesIfUnreferenced(
      [clip.video.file?.path, clip.thumbnailPath, clip.ghostFramePath],
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
        .expand(
          (clip) => [
            clip.video.file?.path,
            clip.thumbnailPath,
            clip.ghostFramePath,
          ],
        )
        .toList();

    await deleteFilesIfUnreferenced(
      paths,
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
        clip.ghostFramePath,
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
