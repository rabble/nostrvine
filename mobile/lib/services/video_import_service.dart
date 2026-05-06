// ABOUTME: Orchestrates importing a C2PA-verified video into the diVine library
// ABOUTME: Copies file to app storage, creates clip + draft, saves via services

import 'dart:io';

import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Orchestrates importing a C2PA-verified video into the diVine library.
///
/// 1. Copies the shared file to app storage (`imports/` directory)
/// 2. Extracts thumbnail (best-effort)
/// 3. Extracts video metadata for duration (best-effort)
/// 4. Creates a [DivineVideoClip] and saves via [ClipLibraryService]
/// 5. Creates a [DivineVideoDraft] and saves via [DraftStorageService]
/// 6. Returns the draft ID
class VideoImportService {
  VideoImportService({
    required ClipLibraryService clipLibraryService,
    required DraftStorageService draftStorageService,
  }) : _clipLibraryService = clipLibraryService,
       _draftStorageService = draftStorageService;

  final ClipLibraryService _clipLibraryService;
  final DraftStorageService _draftStorageService;

  /// Imports a C2PA-verified video file into the library.
  ///
  /// Returns the draft ID for navigation to the editor.
  ///
  /// Throws [FileSystemException] if the source file cannot be copied.
  Future<String> importVerifiedVideo({
    required String filePath,
    required C2paImportResult validationResult,
  }) async {
    final now = DateTime.now();
    final clipId = 'import_${now.millisecondsSinceEpoch}';
    final draftId = 'draft_import_${now.millisecondsSinceEpoch}';

    // 1. Copy shared file to app storage
    final importedPath = await _copyToAppStorage(filePath, clipId);

    Log.info(
      'Imported video to: $importedPath',
      name: 'VideoImportService',
      category: LogCategory.video,
    );

    // 2. Try to extract thumbnail (best-effort)
    String? thumbnailPath;
    try {
      final result = await VideoThumbnailService.extractThumbnail(
        videoPath: importedPath,
      );
      thumbnailPath = result?.path;
    } catch (e) {
      Log.warning(
        'Failed to extract thumbnail: $e',
        name: 'VideoImportService',
        category: LogCategory.video,
      );
    }

    // 3. Try to extract video metadata for duration (best-effort)
    var duration = Duration.zero;
    double? originalAspectRatio;
    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(importedPath),
      );
      duration = metadata.duration;
      if (metadata.resolution.width > 0 && metadata.resolution.height > 0) {
        originalAspectRatio =
            metadata.resolution.width / metadata.resolution.height;
      }
    } catch (e) {
      Log.warning(
        'Failed to extract video metadata: $e',
        name: 'VideoImportService',
        category: LogCategory.video,
      );
    }

    // 4. Create clip and save
    final clip = DivineVideoClip(
      id: clipId,
      video: EditorVideo.file(importedPath),
      duration: duration,
      recordedAt: now,
      thumbnailPath: thumbnailPath,
      originalAspectRatio: originalAspectRatio,
      targetAspectRatio: model.AspectRatio.vertical,
      proofManifestJson: validationResult.claimGenerator,
    );

    await _clipLibraryService.saveClip(clip);

    // 5. Create draft and save
    final title = validationResult.title ?? '';
    final draft = DivineVideoDraft.create(
      id: draftId,
      clips: [clip],
      title: title,
      description: '',
      hashtags: const {},
      selectedApproach: 'imported',
    );

    await _draftStorageService.saveDraft(draft);

    Log.info(
      'Created draft $draftId with clip $clipId from imported video',
      name: 'VideoImportService',
      category: LogCategory.video,
    );

    return draftId;
  }

  /// Copies the source file into the app's documents/imports/ directory.
  Future<String> _copyToAppStorage(String sourcePath, String clipId) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final importsDir = Directory(p.join(documentsDir.path, 'imports'));
    if (!importsDir.existsSync()) {
      await importsDir.create(recursive: true);
    }

    final extension = p.extension(sourcePath);
    final destPath = p.join(importsDir.path, '$clipId$extension');
    await File(sourcePath).copy(destPath);

    return destPath;
  }
}
