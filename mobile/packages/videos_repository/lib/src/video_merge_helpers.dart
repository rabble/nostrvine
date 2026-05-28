/// Shared merge helpers for profile and Nostr enrichment code paths.
///
/// Keeps engagement parity with Funnelcake when relay/Nostr copies disagree
/// (#3384). Lives in `videos_repository` because both the package's author-feed
/// composition and the app-layer Nostr enrichment utility consume them — the
/// repository is the canonical owner of the merge policy.
library;

import 'dart:math' as math;

/// Merges raw video tags with primary-wins semantics on duplicate keys
/// (`{...secondary, ...primary}`), except `views`: the higher parsed
/// non-negative count wins (#3384).
///
/// Used by profile relay/REST merge and by Nostr enrichment (#3384).
Map<String, String> mergeVideoRawTagsPrimaryWins(
  Map<String, String> primary,
  Map<String, String> secondary,
) {
  final merged = {...secondary, ...primary};
  final p = _parseNonNegativeIntTag(primary['views']);
  final s = _parseNonNegativeIntTag(secondary['views']);
  if (p == null && s == null) return merged;
  merged['views'] = math.max(p ?? 0, s ?? 0).toString();
  return merged;
}

int? _parseNonNegativeIntTag(String? raw) {
  if (raw == null) return null;
  final n = raw.replaceAll(',', '').trim();
  if (n.isEmpty) return null;
  final asInt = int.tryParse(n);
  if (asInt != null) return asInt < 0 ? null : asInt;
  final asDouble = double.tryParse(n);
  if (asDouble == null) return null;
  final rounded = asDouble.round();
  return rounded < 0 ? null : rounded;
}

/// Higher of two nullable counters; null only when both are null (#3384).
int? mergeNullableEngagementMax(int? primary, int? secondary) {
  if (primary == null && secondary == null) return null;
  return math.max(primary ?? 0, secondary ?? 0);
}
