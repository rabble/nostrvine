// ABOUTME: Extension methods for VideoEvent that have app-specific dependencies.
// ABOUTME: These methods require services (M3u8ResolverService) or platform
// ABOUTME: detection (dart:io) that don't belong in the pure data model.

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:openvine/services/m3u8_resolver_service.dart';
import 'package:openvine/services/video_format_preference.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// Get quality string based on bandwidth tracker recommendation (3-tier)
String _getBandwidthBasedQuality() {
  final tracker = bandwidthTracker;
  switch (tracker.recommendedQuality) {
    case VideoQuality.high:
      return 'high';
    case VideoQuality.medium:
      return 'medium';
    case VideoQuality.low:
      return 'low';
  }
}

/// Extension methods for VideoEvent that require app-level dependencies.
///
/// These methods are separated from the core VideoEvent model because they
/// depend on:
/// - Platform detection (dart:io)
/// - App services (M3u8ResolverService)
///
/// The core VideoEvent model in the models package remains pure and testable.
extension VideoEventAppExtensions on VideoEvent {
  // ---------------------------------------------------------------------------
  // Platform Detection
  // ---------------------------------------------------------------------------

  /// Check if video format is supported on current platform.
  ///
  /// WebM is not supported on iOS/macOS (AVPlayer limitation).
  /// All other formats (MP4, MOV, M4V, HLS) work on all platforms.
  bool get isSupportedOnCurrentPlatform {
    // WebM only works on Android and Web, not iOS/macOS
    if (isWebM) {
      if (kIsWeb) return true;
      return defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.macOS;
    }
    // All other formats work on all platforms
    return true;
  }

  // ---------------------------------------------------------------------------
  // Divine Server Detection
  // ---------------------------------------------------------------------------

  /// Check if video is hosted on Divine servers.
  ///
  /// Matches any *.divine.video subdomain including:
  /// - cdn.divine.video (R2 blob storage)
  /// - stream.divine.video (BunnyStream HLS)
  /// - media.divine.video (default Blossom server)
  /// - blossom.divine.video (Blossom protocol server)
  bool get isFromDivineServer {
    final url = videoUrl;
    if (url == null || url.isEmpty) return false;

    try {
      final host = Uri.parse(url).host.toLowerCase();
      return host == 'divine.video' || host.endsWith('.divine.video');
    } catch (_) {
      return false;
    }
  }

  /// Check for `media.divine.video` URLs that are just a bare sha256 hash path.
  ///
  /// These URLs look like `https://media.divine.video/{hash}` with no file
  /// extension or quality suffix. Some of these assets do not expose a direct
  /// downloadable file and are only playable via the derived HLS manifest.
  bool get hasBareDivineHashPath {
    final url = videoUrl;
    if (url == null || url.isEmpty || !isFromDivineServer) {
      return false;
    }

    try {
      final uri = Uri.parse(url);
      if (uri.host.toLowerCase() != 'media.divine.video') {
        return false;
      }

      final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
      if (segments.length != 1) {
        return false;
      }

      final segment = segments.first;
      return segment.length == 64 &&
          RegExp(r'^[a-fA-F0-9]+$').hasMatch(segment);
    } catch (_) {
      return false;
    }
  }

  /// Check if we should show the "Not Divine" badge.
  ///
  /// Shows badge for content that is:
  /// - NOT from Divine servers
  /// - AND does NOT have ProofMode verification (those show ProofMode badge)
  /// - AND is NOT an original Vine archive video (those show V Original badge)
  bool get shouldShowNotDivineBadge {
    return !isFromDivineServer && !hasProofMode && !isOriginalVine;
  }

  // ---------------------------------------------------------------------------
  // Platform-Aware URL Selection
  // ---------------------------------------------------------------------------

  /// Divine media server base URL for HLS streaming.
  static const String _divineMediaBase = 'https://media.divine.video';

  /// Extract video hash from a Divine server URL.
  ///
  /// Handles URLs like:
  /// - https://media.divine.video/{hash}
  /// - https://cdn.divine.video/{hash}
  /// - https://media.divine.video/{hash}/hls/master.m3u8
  static String? _extractVideoHash(String? url) {
    if (url == null || url.isEmpty) return null;

    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      // Only extract from Divine servers
      if (!host.contains('divine.video')) return null;

      // Path segments: ['', 'hash'] or ['', 'hash', 'hls', 'master.m3u8']
      final segments = uri.pathSegments;
      if (segments.isEmpty) return null;

      // First segment should be the hash (64 hex characters)
      final hash = segments.first;
      if (hash.length == 64 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(hash)) {
        return hash;
      }
    } catch (_) {
      // Invalid URL, return null
    }
    return null;
  }

  /// Get HLS streaming URL for Divine videos.
  ///
  /// All Divine videos are automatically transcoded to HLS format with
  /// adaptive bitrate (720p/480p). This URL provides:
  /// - Android compatibility via H.264 baseline profile
  /// - iOS/macOS native AVPlayer support
  /// - Automatic quality switching based on connection speed
  ///
  /// Returns null if:
  /// - Video is not from Divine servers
  /// - Hash cannot be extracted from URL
  String? get hlsUrl => getHlsUrl();

  /// Whether the current format selection uses HLS delivery.
  ///
  /// True when a developer override selects an HLS format. Production default
  /// (MP4) returns false. Used by [getCacheableVideoUrlForPlatform] to skip
  /// disk caching for HLS (which can't be single-file cached).
  bool get shouldPreferHlsPlayback =>
      isFromDivineServer && videoFormatPreference.isHlsFormat;

  /// Whether background file caching should be skipped for this video.
  bool get shouldSkipFileCaching => false;

  /// Get HLS URL with optional quality override.
  ///
  /// [quality] - null for master playlist (ABR), 'high' for 720p, 'low' for 480p
  String? getHlsUrl({String? quality}) {
    final hash = _extractVideoHash(videoUrl);
    if (hash == null) return null;

    // Quality-specific streams vs adaptive master playlist
    switch (quality) {
      case 'high':
        return '$_divineMediaBase/$hash/hls/stream_720p.m3u8';
      case 'low':
        return '$_divineMediaBase/$hash/hls/stream_480p.m3u8';
      default:
        return '$_divineMediaBase/$hash/hls/master.m3u8';
    }
  }

  /// Get the optimal video URL for initial playback.
  ///
  /// **Strategy**:
  /// - Classic Vine originals use the raw blob directly (/{hash}) because the
  ///   source is already 480p or lower — transcoded variants are upscales at
  ///   best and may not exist, causing needless 404s.
  /// - Other Divine videos default to progressive MP4 720p (faststart, moov at
  ///   front) for fastest startup with short videos (1 request, no manifest
  ///   overhead).
  /// - Developer options can override to HLS or other formats for A/B testing.
  /// - If MP4 fails (e.g. not yet transcoded after upload), [getFallbackUrl]
  ///   provides an HLS fallback via the quality variant error handler.
  ///
  /// Non-Divine videos always use original (no transcoded variants exist).
  String? getOptimalVideoUrlForPlatform() {
    // Non-Divine videos: always use original (no transcoded variants)
    if (!isFromDivineServer) return videoUrl;

    final hash = _extractVideoHash(videoUrl);
    if (hash == null) return videoUrl;

    // Classic Vine originals are 480p or lower — serve the raw blob directly.
    // Transcoded 720p variants are pointless upscales and may not exist.
    if (isOriginalVine) return '$_divineMediaBase/$hash';

    // Developer format override takes priority
    final override = videoFormatPreference.format;
    if (override != null) {
      return switch (override) {
            VideoPlaybackFormat.hlsDefault => _hlsForBandwidth(),
            VideoPlaybackFormat.raw => videoUrl,
            VideoPlaybackFormat.hlsMaster => getHlsUrl(),
            VideoPlaybackFormat.hls720p => getHlsUrl(quality: 'high'),
            VideoPlaybackFormat.hls480p => getHlsUrl(quality: 'low'),
            VideoPlaybackFormat.ts720p => '$_divineMediaBase/$hash/720p',
            VideoPlaybackFormat.ts480p => '$_divineMediaBase/$hash/480p',
            VideoPlaybackFormat.mp4_720p => '$_divineMediaBase/$hash/720p.mp4',
            VideoPlaybackFormat.mp4_480p => '$_divineMediaBase/$hash/480p.mp4',
          } ??
          videoUrl;
    }

    // Production default: progressive MP4 720p (faststart).
    // Fastest startup (1 request, moov at front), correct colors on all
    // platforms, and 3-8x smaller than the raw blob.
    return '$_divineMediaBase/$hash/720p.mp4';
  }

  /// HLS URL selected by bandwidth tracker quality.
  String? _hlsForBandwidth() {
    final hlsQuality = switch (bandwidthTracker.recommendedQuality) {
      VideoQuality.high || VideoQuality.medium => 'high',
      VideoQuality.low => 'low',
    };
    return getHlsUrl(quality: hlsQuality);
  }

  /// Get the URL to use for disk caching, if any.
  ///
  /// Returns null for Divine HLS videos (can't be single-file cached).
  /// Progressive formats (ts, mp4, raw) can be cached.
  String? getCacheableVideoUrlForPlatform() {
    if (shouldSkipFileCaching) return null;
    // HLS can't be single-file cached; progressive formats can
    if (isFromDivineServer && videoFormatPreference.isHlsFormat) return null;
    return getOptimalVideoUrlForPlatform() ?? videoUrl;
  }

  /// Get fallback URL when the primary playback URL fails.
  ///
  /// For Divine MP4 quality variants, falls back to HLS (bandwidth-selected).
  /// HLS is the proven reliable format and avoids the same-URL retry loop.
  /// Returns null for non-Divine videos or when no fallback is available.
  String? getFallbackUrl() {
    if (!isFromDivineServer) return null;
    return _hlsForBandwidth();
  }

  /// Get HLS fallback URL for Android codec errors.
  ///
  /// Called when original video fails with a codec error on Android.
  /// HLS transcoding provides H.264 Baseline Profile which is universally
  /// supported, unlike High Profile which some devices can't decode.
  ///
  /// Uses 3-tier bandwidth quality: high (720p HLS), medium (720p HLS),
  /// low (480p HLS).
  ///
  /// Returns null if:
  /// - Not on Android
  /// - Video is not from Divine servers (no HLS available)
  String? getHlsFallbackUrl() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    final quality = _getBandwidthBasedQuality();
    // Map 3-tier quality to HLS stream quality
    // 'medium' maps to 'high' HLS since 720p is already the "medium" tier
    final hlsQuality = quality == 'low' ? 'low' : 'high';
    final hls = getHlsUrl(quality: hlsQuality);

    if (hls != null) {
      developer.log(
        '📱 Android: HLS fallback available ($quality -> $hlsQuality HLS): $hls',
        name: 'VideoEventExtensions',
      );
    }

    return hls;
  }

  // ---------------------------------------------------------------------------
  // URL Resolution (m3u8 to MP4)
  // ---------------------------------------------------------------------------

  /// Get the best playable URL for this video.
  ///
  /// This is an async convenience method that resolves m3u8 URLs to MP4.
  /// Use this when preparing to play a video.
  Future<String?> getPlayableUrl() async {
    return resolvePlayableUrl(videoUrl);
  }

  /// Resolve a video URL to its best playable format.
  ///
  /// For m3u8 (HLS) URLs, attempts to extract the underlying MP4 URL.
  /// For other URLs, returns as-is.
  ///
  /// This is useful because:
  /// - MP4 is more efficient for short videos (6 seconds)
  /// - MP4 loads faster (single file vs manifest + segments)
  /// - Some players handle MP4 better than HLS for short content
  static Future<String?> resolvePlayableUrl(String? videoUrl) async {
    if (videoUrl == null || videoUrl.isEmpty) {
      return null;
    }

    // Check if this is an m3u8 URL
    final urlLower = videoUrl.toLowerCase();
    if (!urlLower.contains('.m3u8') && !urlLower.contains('/hls/')) {
      // Not an m3u8 URL, return as-is
      return videoUrl;
    }

    developer.log(
      '🎬 Attempting to resolve m3u8 URL to MP4: $videoUrl',
      name: 'VideoEventExtensions',
    );

    // Try to resolve to MP4
    final resolver = M3u8ResolverService();
    final resolvedUrl = await resolver.resolveM3u8ToMp4(videoUrl);

    if (resolvedUrl != null) {
      developer.log(
        '✅ Resolved m3u8 to MP4: $resolvedUrl',
        name: 'VideoEventExtensions',
      );
      return resolvedUrl;
    } else {
      developer.log(
        '⚠️ Failed to resolve m3u8, using original URL: $videoUrl',
        name: 'VideoEventExtensions',
      );
      return videoUrl; // Fallback to original if resolution fails
    }
  }
}

/// Collection helpers for converting [VideoEvent] objects into pooled-player
/// items with the same platform-aware URL selection used elsewhere in the app.
extension VideoEventCollectionAppExtensions on Iterable<VideoEvent> {
  /// Convert videos to pooled-player items, filtering out null URLs and
  /// normalizing Divine-hosted playback URLs for the current platform.
  List<VideoItem> toPooledVideoItems() =>
      where((video) => video.videoUrl != null)
          .map(
            (video) => VideoItem(
              id: video.id,
              url: video.getOptimalVideoUrlForPlatform() ?? video.videoUrl!,
              originalUrl: video.videoUrl,
            ),
          )
          .toList();
}
