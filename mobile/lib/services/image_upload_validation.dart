// ABOUTME: Client-side image upload policy (#4272) — byte cap and filename checks
// ABOUTME: before Blossom metadata strip / hashing; not a security boundary.

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Profile / banner Blossom uploads: matches EN l10n "max 10MB" for file-too-large copy.
const int kProfileImageUploadMaxBytes = 10 * 1024 * 1024;

/// Which upload path is being validated (drives [ImageUploadPolicy.maxBytes]).
enum ImageUploadKind {
  /// Staged profile avatar on the profile editor flow.
  avatar,

  /// Staged profile banner on the profile editor flow.
  banner,

  /// Generated video thumbnail uploaded via the upload manager pipeline.
  videoThumbnail,

  /// Bug report attachment images (Zendesk / email); same byte ceiling as profile
  /// until product defines a separate attachment policy.
  bugReportAttachment,
}

/// Named limits per [ImageUploadKind] (single source of truth for validators).
abstract final class ImageUploadPolicy {
  /// Maximum uncompressed / on-disk size in bytes before calling Blossom.
  static int maxBytes(ImageUploadKind kind) => switch (kind) {
    ImageUploadKind.avatar => kProfileImageUploadMaxBytes,
    ImageUploadKind.banner => kProfileImageUploadMaxBytes,
    ImageUploadKind.videoThumbnail => kProfileImageUploadMaxBytes,
    ImageUploadKind.bugReportAttachment => kProfileImageUploadMaxBytes,
  };

  // --- `image_picker` downscaling hints (keep in sync with call sites) ---

  /// Square cap for profile avatar picks (gallery / camera / web).
  static const double profileAvatarPickerMaxWidth = 1024;
  static const double profileAvatarPickerMaxHeight = 1024;
  static const int profileAvatarPickerImageQuality = 85;

  /// Wide cap for profile banner picks (matches PR #4232 / issue #4272 notes).
  static const double profileBannerPickerMaxWidth = 1500;
  static const double profileBannerPickerMaxHeight = 500;
  static const int profileBannerPickerImageQuality = 85;

  /// Cap for bug-report multi-image picks (mobile).
  static const double bugReportAttachmentPickerMaxWidth = 1920;
  static const double bugReportAttachmentPickerMaxHeight = 1920;
  static const int bugReportAttachmentPickerImageQuality = 80;
}

/// Outcome of [validateImageBytes] / [validateImageFile].
sealed class ImageUploadValidationResult {
  const ImageUploadValidationResult();

  /// True when validation passed and upload policy allows proceeding.
  bool get isOk => this is ImageUploadValidationOk;
}

/// Validation passed.
final class ImageUploadValidationOk extends ImageUploadValidationResult {
  const ImageUploadValidationOk();
}

/// Byte length exceeds [ImageUploadPolicy.maxBytes] for this [ImageUploadKind].
final class ImageUploadValidationTooLarge extends ImageUploadValidationResult {
  const ImageUploadValidationTooLarge({
    required this.limitBytes,
    required this.actualBytes,
  });

  final int limitBytes;
  final int actualBytes;
}

/// Filename extension is present and not in the allowed image set (see
/// [_kAllowedImageExtensions]).
final class ImageUploadValidationUnsupportedFormat
    extends ImageUploadValidationResult {
  const ImageUploadValidationUnsupportedFormat({required this.extension});

  /// Lowercase extension without leading dot, e.g. `txt`, `mp4`.
  final String extension;
}

/// File missing, unreadable length, or other I/O failure when checking size.
final class ImageUploadValidationUnreadable
    extends ImageUploadValidationResult {
  const ImageUploadValidationUnreadable({this.cause});

  final Object? cause;
}

const Set<String> _kAllowedImageExtensions = {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
};

String? _normalizedExtension(String? filename, {String? fallbackPath}) {
  final source = (filename != null && filename.isNotEmpty)
      ? filename
      : fallbackPath;
  if (source == null || source.isEmpty) return null;
  final ext = p.extension(source).replaceFirst('.', '').toLowerCase();
  return ext.isEmpty ? null : ext;
}

ImageUploadValidationResult _validateLengthAndExtension(
  int length,
  ImageUploadKind kind, {
  String? filename,
  String? fallbackPath,
}) {
  final limit = ImageUploadPolicy.maxBytes(kind);
  if (length > limit) {
    return ImageUploadValidationTooLarge(
      limitBytes: limit,
      actualBytes: length,
    );
  }

  final ext = _normalizedExtension(filename, fallbackPath: fallbackPath);
  if (ext != null && !_kAllowedImageExtensions.contains(ext)) {
    return ImageUploadValidationUnsupportedFormat(extension: ext);
  }

  return const ImageUploadValidationOk();
}

/// Validates [bytes] length against [ImageUploadPolicy.maxBytes].
///
/// When [filename] is non-empty, a non-empty extension must be in the allowed
/// image set; missing extension does not fail (web / odd paths stay permissive).
ImageUploadValidationResult validateImageBytes(
  Uint8List bytes,
  ImageUploadKind kind, {
  String? filename,
}) {
  return _validateLengthAndExtension(
    bytes.length,
    kind,
    filename: filename,
  );
}

/// Reads length from [file] via metadata only (no full file read into memory).
ImageUploadValidationResult validateImageFile(File file, ImageUploadKind kind) {
  if (!file.existsSync()) {
    return const ImageUploadValidationUnreadable();
  }

  int length;
  try {
    length = file.lengthSync();
  } on Object catch (e) {
    return ImageUploadValidationUnreadable(cause: e);
  }

  return _validateLengthAndExtension(
    length,
    kind,
    fallbackPath: file.path,
  );
}
