// ABOUTME: Deterministic seeded windowed jitter for For You ordering.
// ABOUTME: Adds per-session variety to recommendation feeds while
// ABOUTME: keeping ordering stable within a pagination session (#5027).

import 'dart:math';

final Random _sessionSeedRandom = Random();

/// Generates an opaque seed string for a recommendation session.
///
/// Intentionally non-cryptographic: the seed only diversifies feed
/// ordering between sessions and protects nothing sensitive, so a
/// plain [Random] is sufficient (and avoids platform-secure-RNG cost
/// on the feed hot path).
String generateRecommendationSessionSeed() =>
    _sessionSeedRandom.nextInt(1 << 31).toRadixString(16);

/// Reorders [items] by shuffling WITHIN consecutive rank windows of
/// [windowSize], deterministically derived from [seed].
///
/// Properties:
/// - **Deterministic**: the same [items], [seed], and [windowSize]
///   always produce the same ordering, so cache replays and feed-mode
///   switches reproduce the identical jittered order.
/// - **Window containment**: an item in rank window `k` (server ranks
///   `k*windowSize ..< (k+1)*windowSize`) stays in window `k`, so a
///   top-[windowSize] recommendation stays in the top [windowSize].
/// - **Prefix stability**: each window's shuffle is seeded from
///   `'$seed:$windowIndex'`, independent of list length, so jittering
///   a longer list with the same seed yields the identical ordering
///   for every complete window shared with a shorter list. This keeps
///   limit-growth pagination (re-fetching with a larger limit) stable.
///
/// A trailing partial window is shuffled within itself; it only matches
/// a longer list's ordering once it becomes a complete window there.
///
/// Pure function: [items] is not mutated and a new list is returned.
/// Empty and single-item lists are returned as (shallow) copies.
List<T> applyRecommendationSessionJitter<T>(
  List<T> items,
  String seed, {
  int windowSize = 5,
}) {
  assert(windowSize >= 1, 'windowSize must be at least 1');
  final result = List<T>.of(items);
  if (result.length < 2 || windowSize < 2) return result;

  for (
    var start = 0, windowIndex = 0;
    start < result.length;
    start += windowSize, windowIndex++
  ) {
    final end = min(start + windowSize, result.length);
    final window = result.sublist(start, end)
      ..shuffle(Random(_stableStringHash('$seed:$windowIndex')));
    result.setRange(start, end, window);
  }

  return result;
}

/// 32-bit FNV-1a hash over the string's code units.
///
/// Used instead of [String.hashCode] because Dart's built-in string
/// hash is not guaranteed stable across platforms or SDK versions,
/// and the jitter must be reproducible for a given seed.
int _stableStringHash(String input) {
  const fnvPrime = 0x01000193;
  const fnvOffsetBasis = 0x811c9dc5;
  var hash = fnvOffsetBasis;
  for (final codeUnit in input.codeUnits) {
    hash = ((hash ^ codeUnit) * fnvPrime) & 0xFFFFFFFF;
  }
  return hash;
}
