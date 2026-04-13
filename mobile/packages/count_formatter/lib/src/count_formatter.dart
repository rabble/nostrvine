// ABOUTME: Utility for formatting numbers in compact human-readable notation.
// ABOUTME: Used for follower counts, video counts, and similar metrics.

import 'package:intl/intl.dart';

/// Formats numbers in compact human-readable notation.
abstract class CountFormatter {
  /// Formats [count] as a compact, locale-aware string.
  ///
  /// When [locale] is provided, uses locale-specific compact
  /// suffixes and decimal separators (e.g. 'Tsd.' in German,
  /// '万' in Japanese). Defaults to the current locale.
  ///
  /// Values below 1000 are returned as plain integers.
  static String formatCompact(Object count, {String? locale}) {
    final n = count is int ? count : int.tryParse('$count') ?? 0;
    if (n < 1000) return '$n';
    return NumberFormat.compact(locale: locale).format(n);
  }
}
