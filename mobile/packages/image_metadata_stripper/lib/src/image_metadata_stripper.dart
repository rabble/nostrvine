import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';

/// Strips EXIF metadata (GPS, device info, timestamps) from image files
/// using native platform APIs.
///
/// On iOS, uses UIImage decode → re-encode which discards all EXIF data.
/// On Android, uses BitmapFactory decode → compress cycle which discards
/// all EXIF data from the output.
class ImageMetadataStripper {
  static const _channel = MethodChannel('image_metadata_stripper');

  /// Strips all EXIF metadata from the image at [inputPath] and writes
  /// the cleaned image to [outputPath].
  ///
  /// Throws [PlatformException] if the native call fails.
  static Future<void> stripMetadata({
    required String inputPath,
    required String outputPath,
  }) async {
    await _channel.invokeMethod<void>('stripImageMetadata', {
      'inputPath': inputPath,
      'outputPath': outputPath,
    });
  }

  /// Convenience: strips metadata in-place by writing to a temp file
  /// and replacing the original.
  ///
  /// Returns the original [imageFile] on success.
  /// On failure, logs the error and returns the unmodified [imageFile]
  /// so the upload can proceed with metadata intact rather than crashing.
  static Future<File> stripMetadataInPlace(File imageFile) async {
    final tempPath = '${imageFile.path}.stripped';
    try {
      await stripMetadata(
        inputPath: imageFile.path,
        outputPath: tempPath,
      );
      final tempFile = File(tempPath);
      await tempFile.rename(imageFile.path);
    } on Exception catch (e, stackTrace) {
      developer.log(
        'Failed to strip image metadata',
        name: 'ImageMetadataStripper',
        error: e,
        stackTrace: stackTrace,
      );
      // Clean up temp file if it was partially written
      try {
        final tempFile = File(tempPath);
        if (tempFile.existsSync()) await tempFile.delete();
      } on Exception catch (_) {}
    }
    return imageFile;
  }
}
