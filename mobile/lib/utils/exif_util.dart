// ABOUTME: Utility for stripping EXIF metadata from images before upload
// ABOUTME: Prevents GPS coordinates and device info from leaking to servers

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Utilities for sanitizing image metadata before upload.
class ExifUtil {
  /// Strips EXIF metadata from JPEG bytes without re-encoding.
  ///
  /// Operates directly on the JPEG byte stream: scans for the APP1 marker,
  /// removes the EXIF block, and copies the rest verbatim. No pixel decoding
  /// or recompression occurs, so there is zero quality loss.
  ///
  /// Returns the original [bytes] unchanged if the input is not a valid JPEG
  /// or contains no EXIF data.
  static Uint8List stripJpegExif(Uint8List bytes) {
    // JPEG magic: 0xFF 0xD8
    if (bytes.length < 2 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return bytes;
    }
    return img.injectJpgExif(bytes, img.ExifData()) ?? bytes;
  }
}
