// ABOUTME: Service for generating and caching video thumbnails and keyframes
// ABOUTME: Optimizes thumbnail generation for video timeline scrubbing and clip previews

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Service for managing thumbnail and keyframe generation and caching
class VideoEditorThumbnailService {
  VideoEditorThumbnailService({
    required this.context,
    required this.thumbnailCount,
  });

  final BuildContext context;
  final int thumbnailCount;

  final _proVideoEditor = ProVideoEditor.instance;

  /// Get or generate a single keyframe for a video clip
  Future<Uint8List> getKeyFrame(EditorVideo video) async {
    final result = await _proVideoEditor.getKeyFrames(
      KeyFramesConfigs(
        video: EditorVideo.autoSource(
          assetPath: video.assetPath,
          byteArray: video.byteArray,
          file: video.file,
          networkUrl: video.networkUrl,
        ),
        outputSize: const Size.square(200),
        boxFit: ThumbnailBoxFit.cover,
        maxOutputFrames: 1,
        outputFormat: ThumbnailFormat.jpeg,
      ),
    );
    return result.first;
  }

  /// Get or generate multiple keyframes for a video clip
  Future<List<Uint8List>> getKeyFrames(EditorVideo video) async {
    final result = await _proVideoEditor.getKeyFrames(
      KeyFramesConfigs(
        video: EditorVideo.autoSource(
          assetPath: video.assetPath,
          byteArray: video.byteArray,
          file: video.file,
          networkUrl: video.networkUrl,
        ),
        outputSize: const Size.square(200),
        boxFit: ThumbnailBoxFit.cover,
        maxOutputFrames: 7,
        outputFormat: ThumbnailFormat.jpeg,
      ),
    );
    return result;
  }

  /// Generates thumbnails for the given video
  Future<List<ImageProvider>?> generateThumbnails({
    required EditorVideo video,
    required VideoMetadata videoMetadata,
  }) async {
    Log.info(
      '🎬 VideoEditorThumbnailService.generateThumbnails() START - Generating $thumbnailCount thumbnails',
      category: LogCategory.video,
    );

    if (!context.mounted) {
      Log.warning(
        '🎬 VideoEditorThumbnailService.generateThumbnails() - Widget unmounted',
        category: LogCategory.video,
      );
      return null;
    }

    var imageWidth =
        MediaQuery.sizeOf(context).width /
        thumbnailCount *
        MediaQuery.devicePixelRatioOf(context);
    Log.info(
      '🎬 VideoEditorThumbnailService.generateThumbnails() - Image width: $imageWidth',
      category: LogCategory.video,
    );

    List<Uint8List> thumbnailList = [];

    /// On android `getKeyFrames` is a way faster than `getThumbnails` but
    /// the timestamps are more "random". If you want the best results i
    /// recommend you to use only `getThumbnails`.
    final duration = videoMetadata.duration;
    final segmentDuration = duration.inMilliseconds / thumbnailCount;
    Log.info(
      '🎬 VideoEditorThumbnailService.generateThumbnails() - Generating thumbnails...',
      category: LogCategory.video,
    );
    thumbnailList = await _proVideoEditor.getThumbnails(
      ThumbnailConfigs(
        video: video,
        outputSize: Size.square(imageWidth),
        boxFit: ThumbnailBoxFit.cover,
        timestamps: List.generate(thumbnailCount, (i) {
          final midpointMs = (i + 0.5) * segmentDuration;
          return Duration(milliseconds: midpointMs.round());
        }),
        outputFormat: ThumbnailFormat.jpeg,
      ),
    );

    List<ImageProvider> temporaryThumbnails = thumbnailList
        .map(MemoryImage.new)
        .toList();

    /// Optional precache every thumbnail
    Log.info(
      '🎬 VideoEditorThumbnailService.generateThumbnails() - '
      'Precaching ${temporaryThumbnails.length} thumbnails...',
      category: LogCategory.video,
    );
    var cacheList = temporaryThumbnails.map(
      (item) => precacheImage(item, context),
    );
    if (!context.mounted) return null;
    await Future.wait(cacheList);

    Log.info(
      '🎬 VideoEditorThumbnailService.generateThumbnails() COMPLETE',
      category: LogCategory.video,
    );

    return temporaryThumbnails;
  }
}
