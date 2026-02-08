// ABOUTME: Service for saving videos to the device's camera roll/gallery
// ABOUTME: Uses the gal package for cross-platform gallery access

import 'dart:io';

import 'package:gal/gal.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Result of a gallery save operation.
sealed class GallerySaveResult {
  const GallerySaveResult();
}

/// Video was successfully saved to the gallery.
class GallerySaveSuccess extends GallerySaveResult {
  const GallerySaveSuccess();
}

/// Video save failed due to an error.
class GallerySaveFailure extends GallerySaveResult {
  const GallerySaveFailure(this.reason);
  final String reason;
}

/// Service for saving videos to the device's camera roll/gallery.
///
/// This service provides a simple interface for saving videos as a backup
/// when publishing. It handles permission requests internally via the gal
/// package and never throws exceptions - instead returning a result object.
class GallerySaveService {
  /// Creates a [GallerySaveService] with the given [permissionsService].
  const GallerySaveService({required PermissionsService permissionsService})
    : _permissionsService = permissionsService;

  final PermissionsService _permissionsService;

  /// Saves a video file to the device's camera roll/gallery.
  ///
  /// This method:
  /// - Crops the video to [aspectRatio] if provided and resolution differs
  /// - Handles permission requests automatically
  /// - Never throws exceptions
  /// - Returns a [GallerySaveResult] indicating success or failure
  ///
  /// The [video] is the video to save.
  /// The optional [aspectRatio] crops the video before saving if needed.
  /// The optional [albumName] specifies the album to save to.
  Future<GallerySaveResult> saveVideoToGallery(
    EditorVideo video, {
    model.AspectRatio? aspectRatio,
    String albumName = 'diVine',
    VideoMetadata? metadata,
  }) async {
    try {
      String filePath;

      // Crop to aspect ratio if specified
      if (aspectRatio != null) {
        filePath = await VideoEditorRenderService.cropToAspectRatio(
          video: video,
          aspectRatio: aspectRatio,
          metadata: metadata,
        );
      } else {
        filePath = await video.safeFilePath();
      }

      // Verify the file exists
      final file = File(filePath);
      if (!file.existsSync()) {
        Log.warning(
          'Cannot save to gallery: file does not exist at $filePath',
          name: 'GallerySaveService',
          category: LogCategory.video,
        );
        return const GallerySaveFailure('File does not exist');
      }

      // Check gallery permission (should already be granted from camera flow)
      final status = await _permissionsService.checkGalleryStatus();
      if (status != PermissionStatus.granted) {
        Log.warning(
          'Gallery save skipped: permission not granted (status: $status)',
          name: 'GallerySaveService',
          category: LogCategory.video,
        );
        return const GallerySaveFailure('Permission denied');
      }

      // Save the video to the gallery
      await Gal.putVideo(filePath, album: albumName);

      Log.info(
        'Video saved to camera roll successfully',
        name: 'GallerySaveService',
        category: LogCategory.video,
      );

      return const GallerySaveSuccess();
    } on GalException catch (e) {
      Log.warning(
        'Failed to save video to gallery: ${e.type.name}',
        name: 'GallerySaveService',
        category: LogCategory.video,
      );
      return GallerySaveFailure('Gallery error: ${e.type.name}');
    } catch (e) {
      Log.warning(
        'Unexpected error saving video to gallery: $e',
        name: 'GallerySaveService',
        category: LogCategory.video,
      );
      return GallerySaveFailure('Unexpected error: $e');
    }
  }
}
