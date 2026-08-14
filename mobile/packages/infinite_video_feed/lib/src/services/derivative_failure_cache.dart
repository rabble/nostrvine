import 'package:infinite_video_feed/src/utils/canonical_divine_url.dart';

/// How long a failed Divine derivative should be demoted behind fallbacks.
const derivativeFailureCacheTtl = Duration(seconds: 90);

/// Provides the current wall-clock time for [DerivativeFailureCache].
typedef DerivativeFailureClock = DateTime Function();

/// Remembers recent failures for derived Divine media URLs by blob hash.
///
/// This is intentionally small and in-memory. It only needs to survive
/// controller recycling inside the feed window so a freshly published video
/// does not keep selecting a derivative that just failed.
class DerivativeFailureCache {
  /// Creates an in-memory cache with an optional [ttl] and testable [clock].
  DerivativeFailureCache({
    Duration ttl = derivativeFailureCacheTtl,
    DerivativeFailureClock? clock,
  }) : _ttl = ttl,
       _clock = clock ?? DateTime.now;

  final Duration _ttl;
  final DerivativeFailureClock _clock;
  final _failedAtByHash = <String, DateTime>{};

  /// Records a recent failure if [source] is a Divine derivative URL.
  void recordFailureForSource(String source) {
    final hash = derivativeHashForSource(source);
    if (hash == null) return;
    _failedAtByHash[hash] = _clock();
  }

  /// Returns whether [hash] has a live failure entry.
  bool hasFreshFailureForHash(String hash) {
    final failedAt = _failedAtByHash[hash];
    if (failedAt == null) return false;
    if (_clock().difference(failedAt) <= _ttl) return true;

    _failedAtByHash.remove(hash);
    return false;
  }
}

/// Returns the blob hash for derivative URLs, excluding raw and HLS sources.
String? derivativeHashForSource(String source) {
  final hash = extractCanonicalDivineBlobHash(source);
  if (hash == null) return null;

  final rawUrl = canonicalDivineBlobRawUrl(hash);
  final hlsUrl = canonicalDivineBlobHlsUrl(hash);
  if (source == rawUrl || source == hlsUrl || source.contains('/hls/')) {
    return null;
  }

  return hash;
}
