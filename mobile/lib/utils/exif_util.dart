// ABOUTME: Utility for stripping EXIF metadata from images before upload
// ABOUTME: Prevents GPS coordinates and device info from leaking to servers

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Utilities for sanitizing image metadata before upload.
class ExifUtil {
  /// Strips privacy-sensitive EXIF metadata from JPEG bytes without
  /// re-encoding.
  ///
  /// Removes GPS coordinates, device make/model, timestamps, and all other
  /// EXIF tags while **preserving the orientation tag** so the image displays
  /// with the correct rotation.
  ///
  /// Operates directly on the JPEG byte stream — no pixel decoding or
  /// recompression occurs, so there is zero quality loss.
  ///
  /// Returns the original [bytes] unchanged if the input is not a valid JPEG
  /// or contains no EXIF data.
  static Uint8List stripJpegExif(Uint8List bytes) {
    // JPEG magic: 0xFF 0xD8
    if (bytes.length < 2 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return bytes;
    }

    // Read the existing orientation tag before stripping.
    final originalExif = img.decodeJpgExif(bytes);
    final orientation = originalExif?.imageIfd.orientation;

    // Build a minimal EXIF block that only contains orientation (if present).
    final cleanExif = img.ExifData();
    if (orientation != null) {
      cleanExif.imageIfd.orientation = orientation;
    }

    return img.injectJpgExif(bytes, cleanExif) ?? bytes;
  }
}
