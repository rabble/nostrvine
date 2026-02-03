// ABOUTME: Service for saving videos to the device's camera roll/gallery
// ABOUTME: Uses the gal package for cross-platform gallery access

import 'dart:io';

import 'package:gal/gal.dart';
import 'package:openvine/utils/unified_logger.dart';

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
  /// Saves a video file to the device's camera roll/gallery.
  ///
  /// This method:
  /// - Handles permission requests automatically
  /// - Never throws exceptions
  /// - Returns a [GallerySaveResult] indicating success or failure
  ///
  /// The [filePath] should be an absolute path to an existing video file.
  /// The optional [albumName] specifies the album to save to (defaults to
  /// device's default album).
  Future<GallerySaveResult> saveVideoToGallery(
    String filePath, {
    String? albumName,
  }) async {
    try {
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

      // Check if we have permission (gal handles requesting if needed)
      final hasAccess = await Gal.hasAccess(toAlbum: albumName != null);
      if (!hasAccess) {
        // Request permission
        final granted = await Gal.requestAccess(toAlbum: albumName != null);
        if (!granted) {
          Log.warning(
            'Gallery save skipped: permission denied',
            name: 'GallerySaveService',
            category: LogCategory.video,
          );
          return const GallerySaveFailure('Permission denied');
        }
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
