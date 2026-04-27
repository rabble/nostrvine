// ABOUTME: Imports archived classic Vine videos into the local clip library.
// ABOUTME: Copies cached media into documents so saved clip paths survive app restarts.

import 'dart:io';

import 'package:models/models.dart' as models;
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

typedef ClassicVineVideoDownloader =
    Future<File?> Function({required String url, required String cacheKey});

typedef ClassicVineThumbnailExtractor =
    Future<ClassicVineThumbnail?> Function({
      required String videoPath,
      required Duration targetTimestamp,
    });

typedef ClassicVineLastFrameExtractor =
    Future<String?> Function({
      required String videoPath,
      required Duration videoDuration,
    });

typedef DocumentsPathProvider = Future<String> Function();
typedef Clock = DateTime Function();

class ClassicVineThumbnail {
  const ClassicVineThumbnail({required this.path, required this.timestamp});

  final String path;
  final Duration timestamp;
}

sealed class ClassicVineClipImportResult {
  const ClassicVineClipImportResult();
}

final class ClassicVineClipImportSuccess extends ClassicVineClipImportResult {
  const ClassicVineClipImportSuccess(this.clip);

  final DivineVideoClip clip;
}

final class ClassicVineClipImportFailure extends ClassicVineClipImportResult {
  const ClassicVineClipImportFailure(this.reason);

  final ClassicVineClipImportFailureReason reason;
}

enum ClassicVineClipImportFailureReason {
  notClassicVine,
  missingVideoUrl,
  unsupportedPlatform,
  downloadFailed,
  copyFailed,
  saveFailed,
}

class ClassicVineClipImportService {
  ClassicVineClipImportService({
    required ClipLibraryService clipLibraryService,
    required DocumentsPathProvider getDocumentsPath,
    required ClassicVineVideoDownloader downloadVideo,
    required ClassicVineThumbnailExtractor extractThumbnail,
    required ClassicVineLastFrameExtractor extractLastFrame,
    Clock? now,
  }) : _clipLibraryService = clipLibraryService,
       _getDocumentsPath = getDocumentsPath,
       _downloadVideo = downloadVideo,
       _extractThumbnail = extractThumbnail,
       _extractLastFrame = extractLastFrame,
       _now = now ?? DateTime.now;

  static const _logName = 'ClassicVineClipImportService';

  final ClipLibraryService _clipLibraryService;
  final DocumentsPathProvider _getDocumentsPath;
  final ClassicVineVideoDownloader _downloadVideo;
  final ClassicVineThumbnailExtractor _extractThumbnail;
  final ClassicVineLastFrameExtractor _extractLastFrame;
  final Clock _now;

  Future<ClassicVineClipImportResult> importToLibrary(
    models.VideoEvent video,
  ) async {
    if (!video.isOriginalVine) {
      return const ClassicVineClipImportFailure(
        ClassicVineClipImportFailureReason.notClassicVine,
      );
    }

    final playableUrl = await video.getPlayableUrl();
    if (playableUrl == null || playableUrl.isEmpty) {
      return const ClassicVineClipImportFailure(
        ClassicVineClipImportFailureReason.missingVideoUrl,
      );
    }

    final documentsPath = await _getDocumentsPath();
    if (documentsPath.isEmpty) {
      return const ClassicVineClipImportFailure(
        ClassicVineClipImportFailureReason.unsupportedPlatform,
      );
    }

    final downloaded = await _downloadVideo(
      url: playableUrl,
      cacheKey: video.id,
    );
    if (downloaded == null || !downloaded.existsSync()) {
      return const ClassicVineClipImportFailure(
        ClassicVineClipImportFailureReason.downloadFailed,
      );
    }

    final clipId = _clipIdFor(video);
    final duration = _durationFor(video);

    try {
      await Directory(documentsPath).create(recursive: true);
      final copiedVideo = await _copyVideoIntoDocuments(
        downloaded,
        documentsPath,
        clipId,
      );

      final thumbnail = await _extractThumbnail(
        videoPath: copiedVideo.path,
        targetTimestamp: _thumbnailTimestampFor(duration),
      );
      final ghostFramePath = await _extractLastFrame(
        videoPath: copiedVideo.path,
        videoDuration: duration,
      );

      final clip = DivineVideoClip(
        id: clipId,
        video: EditorVideo.file(copiedVideo.path),
        duration: duration,
        recordedAt: _now(),
        thumbnailPath: thumbnail?.path,
        thumbnailTimestamp: thumbnail?.timestamp,
        originalAspectRatio: _aspectRatioFor(video) ?? 1,
        targetAspectRatio: models.AspectRatio.square,
        ghostFramePath: ghostFramePath,
      );

      await _clipLibraryService.saveClip(clip);
      return ClassicVineClipImportSuccess(clip);
    } on FileSystemException catch (e) {
      Log.warning(
        'Failed to copy classic Vine into documents: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return const ClassicVineClipImportFailure(
        ClassicVineClipImportFailureReason.copyFailed,
      );
    } catch (e) {
      Log.warning(
        'Failed to save classic Vine clip: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return const ClassicVineClipImportFailure(
        ClassicVineClipImportFailureReason.saveFailed,
      );
    }
  }

  Future<File> _copyVideoIntoDocuments(
    File source,
    String documentsPath,
    String clipId,
  ) {
    final sourceExtension = p.extension(source.path);
    final extension = sourceExtension.isEmpty ? '.mp4' : sourceExtension;
    final targetPath = p.join(documentsPath, '$clipId$extension');
    return source.copy(targetPath);
  }

  String _clipIdFor(models.VideoEvent video) {
    final safeStableId = video.stableId.replaceAll(
      RegExp('[^a-zA-Z0-9_-]'),
      '_',
    );
    return 'classic_vine_${safeStableId}_${_now().microsecondsSinceEpoch}';
  }

  Duration _durationFor(models.VideoEvent video) {
    final seconds = video.duration;
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds);
    }
    return const Duration(seconds: 6);
  }

  Duration _thumbnailTimestampFor(Duration duration) {
    const preferred = Duration(milliseconds: 210);
    final half = Duration(milliseconds: duration.inMilliseconds ~/ 2);
    return half < preferred ? half : preferred;
  }

  double? _aspectRatioFor(models.VideoEvent video) {
    final dimensions = video.dimensions;
    if (dimensions == null || dimensions.isEmpty) return null;

    final match = RegExp(r'^(\d+)x(\d+)$').firstMatch(dimensions);
    if (match == null) return null;

    final width = int.tryParse(match.group(1)!);
    final height = int.tryParse(match.group(2)!);
    if (width == null || height == null || height == 0) return null;

    return width / height;
  }
}
