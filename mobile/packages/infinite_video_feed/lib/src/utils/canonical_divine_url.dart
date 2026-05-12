/// Helpers for extracting and rebuilding canonical Divine blob URLs.
library;

/// Returns the 64-character hex blob hash from a Divine media URL, or `null`
/// when [url] does not point to a Divine blob.
String? extractCanonicalDivineBlobHash(String url) {
  try {
    final uri = Uri.parse(url);
    if (!uri.host.toLowerCase().contains('divine.video')) return null;

    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;

    final hash = segments.first;
    final isHexHash =
        hash.length == 64 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(hash);
    return isHexHash ? hash : null;
  } on FormatException {
    return null;
  }
}

/// Builds the canonical HLS master URL for a Divine blob [hash].
String canonicalDivineBlobHlsUrl(String hash) =>
    'https://media.divine.video/$hash/hls/master.m3u8';

/// Builds the canonical raw blob URL for a Divine blob [hash].
String canonicalDivineBlobRawUrl(String hash) =>
    'https://media.divine.video/$hash';

/// Returns the input [sources] de-duplicated while preserving their order
/// and skipping null/empty entries.
List<String> orderedUniqueSources(Iterable<String?> sources) {
  final ordered = <String>[];
  final seen = <String>{};

  for (final source in sources) {
    if (source == null || source.isEmpty) continue;
    if (seen.add(source)) ordered.add(source);
  }

  return ordered;
}
