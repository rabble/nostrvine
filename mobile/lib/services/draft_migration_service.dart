// ABOUTME: One-time migration service to convert VineDrafts to SavedClips
// ABOUTME: Preserves video files, creates clips with migrated session IDs

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MigrationResult {
  const MigrationResult({
    required this.migratedCount,
    required this.skippedCount,
    required this.alreadyMigrated,
  });

  final int migratedCount;
  final int skippedCount;
  final bool alreadyMigrated;
}

class DraftMigrationService {
  DraftMigrationService({
    required this.draftService,
    required this.clipService,
    required this.prefs,
  });

  final DraftStorageService draftService;
  final ClipLibraryService clipService;
  final SharedPreferences prefs;

  static const String _migrationKey = 'drafts_migrated_to_clips';

  /// Check if migration has already been performed
  bool get hasMigrated => prefs.getBool(_migrationKey) ?? false;

  /// Migrate all drafts to clips. Only runs once.
  Future<MigrationResult> migrate() async {
    if (hasMigrated) {
      Log.info(
        '📦 Draft migration already completed, skipping',
        name: 'DraftMigrationService',
      );
      return const MigrationResult(
        migratedCount: 0,
        skippedCount: 0,
        alreadyMigrated: true,
      );
    }

    final drafts = await draftService.getAllDrafts();
    var migratedCount = 0;
    var skippedCount = 0;

    for (final draft in drafts) {
      for (RecordingClip draftClip in draft.clips) {
        final videoPath = await draftClip.video.safeFilePath();

        if (!File(videoPath).existsSync()) {
          Log.warning(
            '📦 Skipping draft ${draft.id} - video ${draftClip.id} file missing',
            name: 'DraftMigrationService',
          );
          skippedCount++;
          continue;
        }

        // Extract thumbnail if missing from legacy draft
        String? thumbnailPath = draftClip.thumbnailPath;
        if (thumbnailPath == null || thumbnailPath.isEmpty) {
          try {
            thumbnailPath = await VideoThumbnailService.extractThumbnail(
              videoPath: videoPath,
            );
          } catch (e) {
            Log.warning(
              '📦 Failed to generate thumbnail for draft ${draft.id}: $e',
              name: 'DraftMigrationService',
            );
          }
        }
        // Extract duration from video metadata if not set
        Duration? clipDuration = draftClip.duration;
        if (clipDuration == .zero) {
          try {
            final meta = await ProVideoEditor.instance.getMetadata(
              draftClip.video,
            );
            clipDuration = meta.duration;
          } catch (e) {
            Log.warning(
              '📦 Failed to read video-duration for draft ${draft.id}: $e',
              name: 'DraftMigrationService',
            );
          }
        }

        final clip = SavedClip(
          id: 'clip_migrated_${draft.id}',
          filePath: videoPath,
          thumbnailPath: thumbnailPath,
          duration: clipDuration ?? VideoEditorConstants.maxDuration,
          createdAt: draft.createdAt,
          aspectRatio: draftClip.aspectRatio.name,
          sessionId: 'migrated_${draft.id}',
        );

        await clipService.saveClip(clip);
        migratedCount++;

        Log.info(
          '📦 Migrated draft ${draft.id} to clip ${clip.id}',
          name: 'DraftMigrationService',
        );
      }
    }

    // Clear all drafts after successful migration
    await draftService.clearAllDrafts();

    // Mark migration as complete
    await prefs.setBool(_migrationKey, true);

    Log.info(
      '📦 Migration complete: $migratedCount migrated, $skippedCount skipped',
      name: 'DraftMigrationService',
    );

    return MigrationResult(
      migratedCount: migratedCount,
      skippedCount: skippedCount,
      alreadyMigrated: false,
    );
  }
}
