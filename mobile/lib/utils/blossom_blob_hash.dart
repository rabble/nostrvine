/// Returns a normalized lowercase SHA-256 hex hash, or `null` if invalid.
String? normalizeSha256Hash(String? sha256) {
  if (sha256 == null) return null;
  final trimmed = sha256.trim().toLowerCase();
  if (trimmed.length != 64) return null;
  final isHex = RegExp(r'^[0-9a-f]{64}$').hasMatch(trimmed);
  return isHex ? trimmed : null;
}

/// Extracts a SHA-256 blob hash from any path segment in a Blossom-style URL.
String? extractSha256FromBlossomUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  try {
    final uri = Uri.parse(url);
    for (final segment in uri.pathSegments) {
      final base = segment.split('.').first;
      final normalized = normalizeSha256Hash(base);
      if (normalized != null) return normalized;
    }
  } catch (_) {
    return null;
  }
  return null;
}
