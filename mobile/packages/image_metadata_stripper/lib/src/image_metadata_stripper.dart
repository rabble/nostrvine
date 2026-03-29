import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// Strips EXIF metadata (GPS, device info, timestamps) from image files.
///
/// On native platforms (iOS, Android, macOS), uses platform channels to
/// decode and re-encode the image, discarding all EXIF data.
///
/// On web, uses the pure-Dart `image` package to re-encode JPEGs without
/// metadata. Other formats are left untouched on web.
class ImageMetadataStripper {
  static const _channel = MethodChannel('image_metadata_stripper');

  /// Strips all EXIF metadata from the image at [inputPath] and writes
  /// the cleaned image to [outputPath].
  ///
  /// On web, decodes JPEG files via the `image` package and re-encodes
  /// them without EXIF data. Non-JPEG files are copied as-is.
  ///
  /// Throws [PlatformException] if the native call fails.
  static Future<void> stripMetadata({
    required String inputPath,
    required String outputPath,
  }) async {
    if (kIsWeb) {
      // coverage:ignore-start
      // kIsWeb is a compile-time constant; tested via stripMetadataWeb.
      await stripMetadataWeb(inputPath: inputPath, outputPath: outputPath);
      // coverage:ignore-end
    } else {
      await _channel.invokeMethod<void>('stripImageMetadata', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
    }
  }

  /// Convenience: strips metadata in-place by writing to a temp file
  /// and replacing the original.
  ///
  /// Non-PNG images are re-encoded as JPEG by the native strippers, so
  /// this method also renames the file to `.jpg` when the original
  /// extension is not `.png` to keep the extension consistent with the
  /// actual content.
  ///
  /// Returns the resulting [File] (path may differ from input).
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

      // The native strippers output JPEG for every format except PNG.
      // Rename the file so the extension matches the actual content.
      final isPng = imageFile.path.toLowerCase().endsWith('.png');
      final targetFile = isPng
          ? await tempFile.rename(imageFile.path)
          : await tempFile.rename(
              '${withoutExtension(imageFile.path)}.jpg',
            );

      // Remove the original if it had a different path.
      if (targetFile.path != imageFile.path && imageFile.existsSync()) {
        await imageFile.delete();
      }

      return targetFile;
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

  /// Web fallback: strips metadata from JPEG and PNG files using
  /// pure Dart. JPEG EXIF is replaced losslessly (only orientation is
  /// preserved). PNG is decoded and re-encoded (lossless).
  /// Other formats are copied unchanged.
  @visibleForTesting
  static Future<void> stripMetadataWeb({
    required String inputPath,
    required String outputPath,
  }) async {
    final inputFile = File(inputPath);
    final bytes = await inputFile.readAsBytes();
    final lowerPath = inputPath.toLowerCase();

    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
      final clean = stripJpegExif(bytes);
      await File(outputPath).writeAsBytes(clean);
      return;
    } else if (lowerPath.endsWith('.png')) {
      final decoded = img.decodePng(bytes);
      if (decoded != null) {
        final clean = img.encodePng(decoded);
        await File(outputPath).writeAsBytes(clean);
        return;
      }
    }

    // Unsupported format or decode failed — copy as-is.
    await inputFile.copy(outputPath);
  }

  /// Replaces all JPEG EXIF data with a minimal block that only
  /// contains the orientation tag (if present). No re-encoding,
  /// no quality loss.
  @visibleForTesting
  static Uint8List stripJpegExif(Uint8List bytes) {
    if (bytes.length < 2 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return bytes;
    }

    final originalExif = img.decodeJpgExif(bytes);
    final orientation = originalExif?.imageIfd.orientation;

    final cleanExif = img.ExifData();
    if (orientation != null) {
      cleanExif.imageIfd.orientation = orientation;
    }

    return img.injectJpgExif(bytes, cleanExif) ?? bytes;
  }

  /// Returns [path] without its file extension (including the dot).
  @visibleForTesting
  static String withoutExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0) return path;
    return path.substring(0, dotIndex);
  }
}
