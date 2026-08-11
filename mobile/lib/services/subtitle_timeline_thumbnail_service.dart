// ABOUTME: Streams filmstrip thumbnails for a published video's subtitle
// ABOUTME: timeline, caching the remote file before extracting frames.

import 'dart:io';
import 'dart:ui';

import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/subtitle_editor/timeline_frame.dart';
import 'package:openvine/services/video_editor/clip_thumbnail_manager.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Downloads a video and hands back a local file, or `null` when it could not
/// be fetched.
typedef TimelineVideoDownloader =
    Future<File?> Function({required String url, required String cacheKey});

/// Produces the frames shown under the subtitle editor's timeline.
///
/// The editor works on an already-published video, so unlike the video
/// editor's clip strip there is no local source file to read: the video is
/// pulled through the media cache first, then handed to the same frame
/// extractor the clip strip uses.
class SubtitleTimelineThumbnailService {
  /// Creates the service.
  ///
  /// [stripThumbnailStreamFactory] defaults to the production extractor and is
  /// injectable so tests never touch the native decoder.
  SubtitleTimelineThumbnailService({
    required TimelineVideoDownloader downloadVideo,
    StripThumbnailStreamFactory? stripThumbnailStreamFactory,
  }) : _downloadVideo = downloadVideo,
       _generateStripThumbnails =
           stripThumbnailStreamFactory ??
           VideoThumbnailService.generateStripThumbnails;

  final TimelineVideoDownloader _downloadVideo;
  final StripThumbnailStreamFactory _generateStripThumbnails;

  /// Frames per second of video to extract.
  ///
  /// Matches the clip strip: enough to fill every slot at maximum zoom.
  static int get _thumbsPerSecond =>
      (TimelineConstants.maxPixelsPerSecond / TimelineConstants.thumbnailWidth)
          .ceil();

  /// Streams progressively denser filmstrips for [videoUrl].
  ///
  /// Each event is the full set extracted so far, so a listener can render the
  /// latest batch and drop the previous one. Emits nothing when the video
  /// cannot be cached or [duration] is unknown — the timeline then simply has
  /// no frames behind its cue bars.
  ///
  /// [devicePixelRatio] sizes the extracted frames for the screen they land
  /// on; pass `MediaQuery.devicePixelRatioOf(context)`.
  Stream<List<TimelineFrame>> thumbnailsFor({
    required String videoUrl,
    required String videoId,
    required Duration duration,
    required double devicePixelRatio,
  }) async* {
    if (duration <= Duration.zero) return;

    final File? file;
    try {
      file = await _downloadVideo(url: videoUrl, cacheKey: videoId);
    } catch (e) {
      // Frames are decoration: a failed fetch leaves the timeline usable, so
      // it is logged rather than surfaced.
      Log.warning(
        'Could not cache video for the subtitle timeline: $e',
        name: 'SubtitleTimelineThumbnailService',
      );
      return;
    }
    if (file == null || !file.existsSync()) return;

    final batches = _generateStripThumbnails(
      videoPath: file.path,
      clipId: videoId,
      duration: duration,
      outputSize: Size(
        TimelineConstants.thumbnailWidth * devicePixelRatio,
        TimelineConstants.thumbnailStripHeight * devicePixelRatio,
      ),
      thumbsPerSecond: _thumbsPerSecond,
    );
    await for (final batch in batches) {
      yield [
        for (final frame in batch)
          TimelineFrame(path: frame.path, timestamp: frame.timestamp),
      ];
    }
  }
}
