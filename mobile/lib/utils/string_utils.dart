// ABOUTME: String utility functions for safe operations and formatting
// ABOUTME: Provides safe substring operations and string truncation for logging

import 'package:count_formatter/count_formatter.dart';
import 'package:text_sanitizer/text_sanitizer.dart' as text_sanitizer;

/// Utility functions for safe string operations
class StringUtils {
  /// Safely truncate a string to a maximum length for logging purposes
  /// Returns the string truncated to [maxLength] characters, or the full string if shorter
  static String safeTruncate(String str, int maxLength) {
    if (str.length <= maxLength) {
      return str;
    }
    return str.substring(0, maxLength);
  }

  /// Safe substring operation that won't throw RangeError
  /// Returns substring from [start] to [end], handling bounds automatically
  static String safeSubstring(String str, int start, [int? end]) {
    if (str.isEmpty) return '';

    final clampedStart = start.clamp(0, str.length);
    final clampedEnd = (end ?? str.length).clamp(clampedStart, str.length);

    return str.substring(clampedStart, clampedEnd);
  }

  /// Format an ID for logging - safely truncates to 8 characters
  /// Commonly used pattern throughout the codebase for logging video/event IDs
  static String formatIdForLogging(String id) => safeTruncate(id, 8);

  /// Format a number to a compact, locale-aware string.
  ///
  /// Delegates to [CountFormatter.formatCompact] for consistent,
  /// locale-aware number formatting across the app.
  static String formatCompactNumber(int number, {String? locale}) =>
      CountFormatter.formatCompact(number, locale: locale);

  /// Render a compact-formatted count through an ICU plural lookup.
  ///
  /// [plural] is a generated `AppLocalizations` getter whose first parameter
  /// selects the plural form and whose second is the displayed numeral, so the
  /// grammar follows the raw [value] while the display stays compact (`1.2K`).
  /// Evaluating [value] once keeps the two provably consistent.
  static String compactPlural(
    int value,
    String Function(int, String) plural, {
    String? locale,
  }) => plural(value, formatCompactNumber(value, locale: locale));

  /// Strip unpaired UTF-16 surrogate code units from [input].
  ///
  /// Flutter's text rendering asserts that strings are well-formed UTF-16.
  /// Sender-controlled content reaching the app via JSON `\uXXXX` escapes
  /// (notably NIP-17 DM rumor bodies after `jsonDecode`) can carry
  /// unpaired surrogates that survive transport and crash the renderer
  /// with `Invalid argument(s): string is not well-formed UTF-16`. Apply
  /// this at render boundaries that display untrusted text.
  ///
  /// Returns [input] unchanged when it is already well-formed.
  static String sanitizeUtf16(String input) =>
      text_sanitizer.sanitizeUtf16(input);
}
