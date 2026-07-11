import 'package:infinite_video_feed/src/models/video_error_type.dart';
import 'package:infinite_video_feed/src/utils/canonical_divine_url.dart';
import 'package:models/models.dart';

/// Resolves the ordered list of playback URLs to attempt for [video].
///
/// When [urlResolver] is provided, its output is preferred over
/// [VideoEvent.videoUrl]. For Divine blob URLs the list is expanded with
/// canonical HLS and raw variants so the runtime can fail over between them.
///
/// **Fallback order rationale**: when the resolved source is progressive (raw
/// blob or `<hash>/720p.mp4`) it is attempted first and HLS is only a fallback.
/// (When the resolved source is itself an HLS URL — a Developer Options HLS
/// override or an HLS-only event — that HLS URL is honoured first; the
/// progressive-first ordering below applies to raw/MP4 resolved sources.)
/// We deliberately do NOT prefer HLS for progressive sources, for two reasons
/// specific to Divine:
///
/// 1. Divine videos are short (≤ 6.3s). HLS pays a fixed startup cost — fetch
///    the master playlist, then a media playlist, then the first segment
///    before a single frame renders. For a clip this short that manifest
///    round-trip overhead makes HLS noticeably slower to first frame than a
///    single progressive MP4 request (moov at front, one round trip).
/// 2. HLS is bad for preloading. A progressive MP4 is one cacheable file we
///    can warm ahead of the feed; an HLS stream is a manifest tree of many
///    segments that cannot be single-file cached, so preloading barely helps.
///
/// ExoPlayer/AVPlayer use a progressive source for MP4/raw URLs and only
/// switch to an HLS source for `.m3u8` URLs. On top of the speed and
/// preloading costs, fresh Divine uploads publish the raw/progressive blob
/// before their HLS rendition finishes transcoding, so probing
/// `<hash>/hls/master.m3u8` first returns a manifest with no playable video
/// track and stalls every video. HLS is kept only as a last-resort fallback
/// for assets whose progressive source fails to start.
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
    // Progressive first, HLS last. For a quality variant (e.g. 720p.mp4) the
    // guaranteed raw blob comes before HLS: if the variant is not transcoded
    // yet, the raw blob plays immediately, whereas HLS may also be mid-encode
    // and only pays the manifest-round-trip cost. HLS stays the last resort.
    return isRawBlob
        ? orderedUniqueSources([resolvedSource, hlsUrl, originalUrl])
        : orderedUniqueSources([resolvedSource, rawUrl, hlsUrl, originalUrl]);
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
