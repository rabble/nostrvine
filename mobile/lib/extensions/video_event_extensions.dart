// ABOUTME: Extension methods for VideoEvent that have app-specific dependencies.
// ABOUTME: These methods require services (ThumbnailApiService, M3u8ResolverService)
// ABOUTME: or platform detection (dart:io) that don't belong in the pure data model.

import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:models/models.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:openvine/services/m3u8_resolver_service.dart';
import 'package:openvine/services/thumbnail_api_service.dart';

/// Get quality string based on bandwidth tracker recommendation
String? _getBandwidthBasedQuality() {
  final tracker = bandwidthTracker;
  return tracker.shouldUseHighQuality ? 'high' : 'low';
}

/// Extension methods for VideoEvent that require app-level dependencies.
///
/// These methods are separated from the core VideoEvent model because they
/// depend on:
/// - Platform detection (dart:io)
/// - App services (ThumbnailApiService, M3u8ResolverService)
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
      return !Platform.isIOS && !Platform.isMacOS;
    }
    // All other formats work on all platforms
    return true;
  }

  // ---------------------------------------------------------------------------
  // Divine Server Detection
  // ---------------------------------------------------------------------------

  /// Check if video is hosted on Divine servers.
  bool get isFromDivineServer {
    final url = videoUrl?.toLowerCase() ?? '';
    return url.contains('divine.video') ||
        url.contains('cdn.divine.video') ||
        url.contains('stream.divine.video') ||
        url.contains('media.divine.video');
  }

  /// Check if we should show the "Not Divine" badge.
  ///
  /// Shows badge for content that is:
  /// - NOT from Divine servers
  /// - AND does NOT have ProofMode verification (those show ProofMode badge)
  /// - AND is NOT a vintage recovered vine (those show V Original badge)
  bool get shouldShowNotDivineBadge {
    return !isFromDivineServer && !hasProofMode && !isOriginalVine;
  }

  // ---------------------------------------------------------------------------
  // Thumbnail API Integration
  // ---------------------------------------------------------------------------

  /// Get thumbnail URL from API service with automatic generation.
  ///
  /// This method provides an async fallback that generates thumbnails
  /// when the video doesn't have one set.
  ///
  /// Parameters:
  /// - [timeSeconds]: Time offset in the video to capture (default 2.5s)
  /// - [size]: Thumbnail size preset (default medium)
  Future<String?> getApiThumbnailUrl({
    double timeSeconds = 2.5,
    ThumbnailSize size = ThumbnailSize.medium,
  }) async {
    // First check if we already have a thumbnail URL
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl;
    }

    // Use the thumbnail API service for automatic generation
    return ThumbnailApiService.getThumbnailWithFallback(
      id,
      timeSeconds: timeSeconds,
      size: size,
    );
  }

  /// Get thumbnail URL synchronously from API service (no generation).
  ///
  /// This method provides immediate URL construction without async calls.
  /// The URL may or may not exist, but provides a proper fallback.
  String getApiThumbnailUrlSync({
    double timeSeconds = 2.5,
    ThumbnailSize size = ThumbnailSize.medium,
  }) {
    // First check if we already have a thumbnail URL
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl!;
    }

    // Generate API URL (may or may not exist, but provides proper fallback)
    return ThumbnailApiService.getThumbnailUrl(
      id,
      timeSeconds: timeSeconds,
      size: size,
    );
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
  /// **Strategy**: Try original video first on all platforms.
  /// Many Android devices CAN play the original codec fine.
  /// HLS is used as a fallback only when codec errors occur.
  ///
  /// For HLS fallback on Android codec errors, see [getHlsFallbackUrl].
  String? getOptimalVideoUrlForPlatform() {
    // Always try original video first - many devices can play it
    // HLS fallback is handled in error recovery (see individual_video_providers.dart)
    return videoUrl;
  }

  /// Get HLS fallback URL for Android codec errors.
  ///
  /// Called when original video fails with a codec error on Android.
  /// HLS transcoding provides H.264 Baseline Profile which is universally
  /// supported, unlike High Profile which some devices can't decode.
  ///
  /// Returns null if:
  /// - Not on Android
  /// - Video is not from Divine servers (no HLS available)
  String? getHlsFallbackUrl() {
    if (!Platform.isAndroid) return null;

    final quality = _getBandwidthBasedQuality();
    final hls = getHlsUrl(quality: quality);

    if (hls != null) {
      developer.log(
        '📱 Android: HLS fallback available ($quality quality): $hls',
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
