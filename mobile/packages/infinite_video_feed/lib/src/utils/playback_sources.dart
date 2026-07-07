import 'package:infinite_video_feed/src/models/video_error_type.dart';
import 'package:infinite_video_feed/src/utils/canonical_divine_url.dart';
import 'package:models/models.dart';

/// Resolves the ordered list of playback URLs to attempt for [video].
///
/// When [urlResolver] is provided, its output is preferred over
/// [VideoEvent.videoUrl]. For Divine blob URLs the list is expanded with
/// canonical HLS and raw variants so the runtime can fail over between them.
///
/// **Fallback order rationale**: ExoPlayer uses `ProgressiveMediaSource` for
/// `.mp4`-extension URLs and only switches to `HlsMediaSource` when the URL
/// ends with `.m3u8`. Some Divine CDN paths (including raw blob URLs and
/// `<hash>/720p.mp4`) serve content that ExoPlayer cannot parse or start
/// quickly with its progressive extractors even though the file is reachable.
/// HLS is preferred for canonical Divine blobs, with raw MP4 retained as a
/// fallback for assets whose HLS rendition is still unavailable.
List<String> resolvePlaybackSources(
  VideoEvent video, {
  String? Function(VideoEvent video)? urlResolver,
}) {
  final resolvedSource = urlResolver?.call(video) ?? video.videoUrl;
  final originalUrl = video.videoUrl;

  if (resolvedSource == null || resolvedSource.isEmpty) {
    return orderedUniqueSources([originalUrl]);
  }

  final hash = extractCanonicalDivineBlobHash(resolvedSource);
  if (hash != null) {
    final rawUrl = canonicalDivineBlobRawUrl(hash);
    final hlsUrl = canonicalDivineBlobHlsUrl(hash);
    final isAlreadyHls = resolvedSource.contains('/hls/');
    if (isAlreadyHls) {
      return orderedUniqueSources([resolvedSource, rawUrl, originalUrl]);
    }

    final isRawBlob = resolvedSource == rawUrl;
    // For the raw blob, prefer HLS so cold progressive MP4 metadata/layout
    // does not stall feed playback before falling back to raw bytes.
    // For quality-specific variants (e.g. 720p.mp4), HLS comes before raw
    // because the variant URL may serve content ExoPlayer cannot parse as
    // a progressive stream.
    return isRawBlob
        ? orderedUniqueSources([hlsUrl, resolvedSource, originalUrl])
        : orderedUniqueSources([resolvedSource, hlsUrl, rawUrl, originalUrl]);
  }

  return orderedUniqueSources([resolvedSource, originalUrl]);
}

/// Classifies a playback failure into a [VideoErrorType] using the error
/// message and (optionally) the source that produced it.
VideoErrorType classifyVideoError({String? errorMessage, String? source}) {
  final lower = (errorMessage ?? '').toLowerCase();
  // Divine derivative URLs can legitimately return HTTP 202 while MP4/HLS
  // processing catches up after upload. Treat that as transient playback
  // failure, not as proof that the blob is missing.
  if (_mentionsHttpStatus(lower, 202)) {
    return VideoErrorType.generic;
  }
  if (lower.contains('401') || lower.contains('unauthorized')) {
    return VideoErrorType.ageRestricted;
  }
  if (lower.contains('403') || lower.contains('forbidden')) {
    return VideoErrorType.forbidden;
  }
  if (lower.contains('404') || lower.contains('not found')) {
    return VideoErrorType.notFound;
  }

  // Only use the Divine blob heuristic when a concrete source was provided
  // by a failing load/init path. Runtime error events often lack detailed
  // context and should stay generic unless we have explicit 4xx evidence.
  if (source != null && extractCanonicalDivineBlobHash(source) != null) {
    return VideoErrorType.notFound;
  }

  return VideoErrorType.generic;
}

/// Whether an error represents Divine media still preparing renditions.
///
/// Freshly-published Divine derivative URLs can return HTTP 202 while the
/// server finishes MP4/HLS processing. Playback should retry the same source
/// for these responses instead of treating the rendition as failed.
bool isMediaProcessingError(Object? error, {String? errorMessage}) {
  final lower = '${errorMessage ?? ''} ${error ?? ''}'.toLowerCase();
  return _mentionsHttpStatus(lower, 202);
}

bool _mentionsHttpStatus(String lower, int status) {
  if (!lower.contains('http') &&
      !lower.contains('status') &&
      !lower.contains('response code')) {
    return false;
  }
  return RegExp('(^|[^0-9])$status([^0-9]|\$)').hasMatch(lower);
}
