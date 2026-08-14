/// Resolves and scores candidate video URLs extracted from Nostr event tags
/// and content.
///
/// Extracted from `VideoEvent` (#4740) so that URL selection — which is
/// business logic, not data — lives outside the data model. All methods are
/// pure: no I/O, no state.
class VideoUrlResolver {
  VideoUrlResolver._();

  /// Delivery hosts known to be unreachable.
  ///
  /// Transitional pending the hostname disposition in divinevideo/divine-blossom#202.
  static const deadMediaHosts = {'stream.divine.video'};

  /// Corrects the common `apt.openvine.co` typo to `api.openvine.co`.
  ///
  /// The target stays on the legacy host on purpose (#5286). These are content
  /// URLs already published inside archive events, shaped
  /// `/media/<timestamp>-<hash>` — an openvine-era scheme, not the
  /// content-addressed sha256 paths Divine serves from `media.divine.video`.
  /// Retargeting to `api.divine.video` would name a route that host does not
  /// serve, so it would be wrong rather than merely unhelpful. `apt` is the
  /// typo, and it does not resolve at all.
  static String fixOpenvineTypo(String url) {
    if (url.contains('apt.openvine.co')) {
      return url.replaceAll('apt.openvine.co', 'api.openvine.co');
    }
    return url;
  }

  /// Whether [url] is a usable video URL (a well-formed HTTP/HTTPS URL).
  ///
  /// Divine is an open protocol — videos can be hosted anywhere — so any valid
  /// HTTP/HTTPS URL with a host is accepted; the player decides playability.
  static bool isValidVideoUrl(String url) {
    if (url.isEmpty) return false;

    final correctedUrl = fixOpenvineTypo(url);

    try {
      final uri = Uri.parse(correctedUrl);

      // Must be HTTP or HTTPS.
      if (!['http', 'https'].contains(uri.scheme.toLowerCase())) {
        return false;
      }

      // Must have a valid host.
      if (uri.host.isEmpty) return false;

      return true;
    } on FormatException {
      return false;
    }
  }

  /// Whether [url] points at a known dead media delivery host.
  static bool isKnownDeadMediaUrl(String url) {
    try {
      final uri = Uri.parse(fixOpenvineTypo(url));
      final host = uri.host.toLowerCase();
      return deadMediaHosts.contains(host);
    } on FormatException {
      return false;
    }
  }

  /// Scores [url] by format preference (higher = better).
  ///
  /// For short videos MP4 is always preferred over HLS (single file, fast,
  /// universal). Dead `vine.co` URLs and the often-broken
  /// `cdn.divine.video/*/manifest/*.m3u8` pattern are deprioritized.
  static int scoreVideoUrl(String url) {
    final urlLower = url.toLowerCase();

    // Reject broken vine.co URLs immediately (but NOT openvine.co,
    // divine.video, etc.). Only reject URLs from the dead vine.co domain.
    if (urlLower.contains('//vine.co/') ||
        urlLower.contains('//www.vine.co/') ||
        urlLower.startsWith('vine.co/')) {
      return -1;
    }

    // POSTEL'S LAW: Deprioritize known broken URL patterns.
    // The cdn.divine.video/*/manifest/video.m3u8 pattern is often broken;
    // prefer direct MP4 files or generic HLS.
    if (isKnownDeadMediaUrl(url)) {
      return 1;
    }

    if (urlLower.contains('cdn.divine.video') &&
        urlLower.contains('/manifest/')) {
      return 5;
    }

    // ALWAYS prefer MP4 over HLS for short videos (6 seconds).
    // HLS adaptive bitrate is pointless for content this short; MP4 is simpler
    // and faster (single file vs manifest + segments).

    // Direct MP4 from cdn.divine.video (blob storage) - highest priority.
    if (urlLower.contains('.mp4') && urlLower.contains('cdn.divine.video')) {
      return 115;
    }

    // Any other MP4 - still preferred.
    if (urlLower.contains('.mp4')) return 110;

    // Generic HLS fallback.
    if (urlLower.contains('.m3u8') || urlLower.contains('hls')) return 100;

    // WebM is good for web.
    if (urlLower.contains('.webm')) return 90;

    // MOV is decent but large.
    if (urlLower.contains('.mov')) return 70;

    // AVI is supported but not optimal.
    if (urlLower.contains('.avi')) return 60;

    // DASH can be problematic.
    if (urlLower.contains('.mpd') || urlLower.contains('dash')) return 10;

    // Generic URLs get medium priority.
    return 50;
  }

  /// Selects the highest-scoring valid URL from [candidates], or `null`.
  static String? selectBestVideoUrl(List<String> candidates) {
    if (candidates.isEmpty) return null;

    String? bestUrl;
    var bestScore = -1;

    for (final url in candidates) {
      if (isValidVideoUrl(url)) {
        final score = scoreVideoUrl(url);
        if (score > bestScore) {
          bestScore = score;
          bestUrl = url;
        }
      }
    }

    return bestUrl;
  }

  /// Extracts the first valid video URL from free-text [content] (fallback).
  static String? extractVideoUrlFromContent(String content) {
    final urlRegex = RegExp(r'https?://[^\s]+');
    final matches = urlRegex.allMatches(content);

    for (final match in matches) {
      var url = match.group(0);
      if (url != null) {
        url = fixOpenvineTypo(url);
        if (isValidVideoUrl(url)) {
          return url;
        }
      }
    }

    return null;
  }

  /// Finds any valid video URL across all [tags] (aggressive fallback).
  static String? findAnyVideoUrlInTags(List<dynamic> tags) {
    for (final tagRaw in tags) {
      if (tagRaw is! List || tagRaw.isEmpty) continue;

      final tag = tagRaw.map((e) => e.toString()).toList();

      for (var i = 1; i < tag.length; i++) {
        var value = tag[i];
        if (value.isNotEmpty) {
          value = fixOpenvineTypo(value);
          if (isValidVideoUrl(value)) {
            return value;
          }
        }
      }
    }

    return null;
  }
}
