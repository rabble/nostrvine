// ABOUTME: Utility for formatting numbers in compact human-readable notation.
// ABOUTME: Used for follower counts, video counts, and similar metrics.

/// Formats numbers in compact human-readable notation.
abstract class CountFormatter {
  /// Formats [count] as a compact string (e.g., 1.2k, 3m).
  static String formatCompact(Object count) {
    final n = count is int ? count : int.tryParse('$count') ?? 0;
    if (n >= 1000000) {
      final m = n / 1000000;
      return m == m.roundToDouble()
          ? '${m.round()}m'
          : '${m.toStringAsFixed(1)}m';
    }
    if (n >= 1000) {
      final k = n / 1000;
      if (k >= 999.95) return '1m';
      return k == k.roundToDouble()
          ? '${k.round()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return '$n';
  }
}
