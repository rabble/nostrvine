// ABOUTME: Shared parsing for video engagement counters from API/Nostr data.
// ABOUTME: Keeps absent or sentinel count values from surfacing in the UI.

const _invalidEngagementCountStrings = {
  // Common max-int sentinels/underflow values that mean "no count" in
  // upstream analytics stores, not real human engagement.
  '2147483647',
  '4294967295',
  '9223372036854775807',
  '18446744073709551615',
};

/// Parses an engagement counter and returns a display-safe non-negative value.
///
/// Engagement counts are user-visible numbers. Negative values and known
/// max-int sentinel values are treated as absent and normalized to zero.
int parseEngagementCount(dynamic value) {
  final parsed = _parseCount(value);
  if (parsed == null || parsed < 0) return 0;
  return parsed;
}

int? _parseCount(dynamic value) {
  if (value is int) {
    return _invalidEngagementCountStrings.contains(value.toString())
        ? null
        : value;
  }
  if (value is double) {
    if (!value.isFinite) return null;
    final parsed = value.toInt();
    return _invalidEngagementCountStrings.contains(parsed.toString())
        ? null
        : parsed;
  }
  if (value is String) {
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    if (_invalidEngagementCountStrings.contains(normalized)) return null;
    final asInt = int.tryParse(normalized);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(normalized);
    if (asDouble == null || !asDouble.isFinite) return null;
    return asDouble.toInt();
  }
  return null;
}
