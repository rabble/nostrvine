// ABOUTME: Shared matching and stale cleanup for regenerable temp render files.
// ABOUTME: Keeps upload, watermark, and storage cleanup using the same filename rules.

import 'dart:io';

import 'package:openvine/models/pending_upload.dart';
import 'package:path/path.dart' as p;

/// Filename pattern for a regenerable temp render.
class TempRenderPattern {
  /// Creates a pattern matched by filename [prefix] and [extension].
  const TempRenderPattern({
    required this.prefix,
    required this.extension,
    this.excludedPrefixes = const [],
  });

  /// Required filename prefix.
  final String prefix;

  /// Required filename extension, including the leading dot.
  final String extension;

  /// Prefixes that should not match even when [prefix] does.
  final List<String> excludedPrefixes;

  /// Whether [name] matches this temp-render pattern.
  bool matches(String name) =>
      name.startsWith(prefix) &&
      name.endsWith(extension) &&
      !excludedPrefixes.any(name.startsWith);
}

/// Shared temp-render filename patterns.
abstract final class TempRenderPatterns {
  /// Watermarked gallery-save render.
  static const watermarkedVideo = TempRenderPattern(
    prefix: 'watermarked_',
    extension: '.mp4',
  );

  /// Multi-clip upload merge render.
  static const mergedVideo = TempRenderPattern(
    prefix: 'merged_',
    extension: '.mp4',
    excludedPrefixes: ['merged_audio_'],
  );

  /// Multi-clip caption/audio merge render.
  static const mergedAudio = TempRenderPattern(
    prefix: 'merged_audio_',
    extension: '.wav',
  );

  /// All temp-render files that are safe to count and clear.
  static const List<TempRenderPattern> all = [
    watermarkedVideo,
    mergedVideo,
    mergedAudio,
  ];
}

/// Best-effort janitor for regenerable temp render files.
abstract final class TempRenderJanitor {
  /// Files older than this are no longer expected to be owned by an in-flight
  /// render or platform handoff.
  static const staleRenderAge = Duration(hours: 1);

  /// Whether [name] matches any temp-render [patterns].
  static bool isTempRenderName(
    String name, {
    Iterable<TempRenderPattern> patterns = TempRenderPatterns.all,
  }) => patterns.any((pattern) => pattern.matches(name));

  /// Deletes stale temp renders in [tempDir]. Best-effort: never throws.
  static void deleteStaleTempRenders(
    Directory tempDir, {
    Iterable<TempRenderPattern> patterns = TempRenderPatterns.all,
    Set<String> protectedPaths = const {},
    DateTime? now,
    Duration staleAge = staleRenderAge,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(staleAge);
    final normalizedProtectedPaths = {
      for (final filePath in protectedPaths) _normalizePath(filePath),
    };
    try {
      for (final entity in tempDir.listSync(followLinks: false)) {
        if (entity is! File) continue;
        if (!isTempRenderName(p.basename(entity.path), patterns: patterns)) {
          continue;
        }
        if (normalizedProtectedPaths.contains(_normalizePath(entity.path))) {
          continue;
        }
        try {
          if (entity.statSync().modified.isAfter(cutoff)) continue;
          entity.deleteSync();
        } on Object {
          // Best-effort; a file we cannot delete is retried on the next sweep.
        }
      }
    } on Object {
      // Best-effort; a listing failure must not block the caller.
    }
  }

  /// Deletes stale upload merge renders while preserving unpublished uploads.
  static void deleteStaleMergedUploadRenders(
    Directory tempDir,
    Iterable<PendingUpload> pendingUploads,
  ) => deleteStaleTempRenders(
    tempDir,
    patterns: const [TempRenderPatterns.mergedVideo],
    protectedPaths: {
      for (final upload in pendingUploads)
        if (upload.status != UploadStatus.published) upload.localVideoPath,
    },
  );

  static String _normalizePath(String filePath) =>
      p.normalize(p.absolute(filePath));
}
