// ABOUTME: One-time migration service to convert VineDrafts to SavedClips
// ABOUTME: Preserves video files, creates clips with migrated session IDs

import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/unified_logger.dart';
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
      if (!draft.videoFile.existsSync()) {
        Log.warning(
          '📦 Skipping draft ${draft.id} - video file missing',
          name: 'DraftMigrationService',
        );
        skippedCount++;
        continue;
      }

      // Generate thumbnail for the clip
      String? thumbnailPath;
      try {
        thumbnailPath = await VideoThumbnailService.extractThumbnail(
          videoPath: draft.videoFile.path,
          timeMs: 100,
        );
      } catch (e) {
        Log.warning(
          '📦 Failed to generate thumbnail for draft ${draft.id}: $e',
          name: 'DraftMigrationService',
        );
      }

      final clip = SavedClip(
        id: 'clip_migrated_${draft.id}',
        filePath: draft.videoFile.path,
        thumbnailPath: thumbnailPath,
        duration: const Duration(seconds: 6), // Assume max duration for legacy
        createdAt: draft.createdAt,
        aspectRatio: draft.aspectRatio.name,
        sessionId: 'migrated_${draft.id}',
      );

      await clipService.saveClip(clip);
      migratedCount++;

      Log.info(
        '📦 Migrated draft ${draft.id} to clip ${clip.id}',
        name: 'DraftMigrationService',
      );
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
