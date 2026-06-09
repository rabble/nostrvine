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
/// ends with `.m3u8`. Some Divine CDN paths (e.g. `<hash>/720p.mp4`) serve
/// content that ExoPlayer cannot parse with its progressive extractors even
/// though the file is reachable. HLS is tried second so at most one failed
/// attempt is needed before ExoPlayer switches to the adaptive source.
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
    // For the raw blob, HLS is the first fallback.
    // For quality-specific variants (e.g. 720p.mp4), HLS comes before raw
    // because the variant URL may serve content ExoPlayer cannot parse as
    // a progressive stream.
    return isRawBlob
        ? orderedUniqueSources([resolvedSource, hlsUrl, originalUrl])
        : orderedUniqueSources([
            resolvedSource,
            hlsUrl,
            rawUrl,
            originalUrl,
          ]);
  }

  return orderedUniqueSources([resolvedSource, originalUrl]);
}

/// Classifies a playback failure into a [VideoErrorType] using the error
/// message and (optionally) the source that produced it.
VideoErrorType classifyVideoError({
  String? errorMessage,
  String? source,
}) {
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

bool _mentionsHttpStatus(String lower, int status) {
  if (!lower.contains('http') &&
      !lower.contains('status') &&
      !lower.contains('response code')) {
    return false;
  }
  return RegExp('(^|[^0-9])$status([^0-9]|\$)').hasMatch(lower);
}
