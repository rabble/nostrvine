/// Source format the runtime should drive for a given URL.
enum HlsAuthWebSourceKind {
  /// Direct MP4 (or unknown non-HLS) — use the `fetch` + blob path.
  mp4,

  /// HLS playlist — use hls.js with the auth loader.
  hls,
}

/// Chooses between the MP4 and HLS paths. The rule mirrors divine-web:
/// anything ending in `.m3u8` uses HLS; everything else (including direct
/// `.mp4`, no extension, signed URLs with query strings) starts on MP4.
///
/// The MP4 path fetches the full response into a browser blob before assigning
/// an object URL to the video element. That is acceptable for Divine's
/// short-form videos, but longer media should prefer an HLS source.
/// Callers can still fall back to HLS on 404 by explicitly requesting an
/// HLS URL through [sourceKindFor].
HlsAuthWebSourceKind sourceKindFor(String url) {
  final withoutQuery = url.split('?').first;
  final lower = withoutQuery.toLowerCase();
  if (lower.endsWith('.m3u8')) {
    return HlsAuthWebSourceKind.hls;
  }
  return HlsAuthWebSourceKind.mp4;
}
