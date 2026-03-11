// ABOUTME: Utility for formatting timestamps into
// ABOUTME: human-readable relative strings.
// ABOUTME: Used by conversation list items and message bubbles.

import 'package:intl/intl.dart';

/// Formats Unix timestamps into human-readable relative time strings.
abstract class TimeFormatter {
  /// Formats a Unix timestamp (seconds) into a relative time string.
  ///
  /// Examples: "now", "3m", "2h", "14h", "3d", "2w"
  static String formatRelative(int unixSeconds) {
    final now = DateTime.now();
    final then = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    final difference = now.difference(then);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    if (difference.inDays < 60) return '${difference.inDays ~/ 7}w';
    if (difference.inDays < 365) return '${difference.inDays ~/ 30}mo';
    return '${difference.inDays ~/ 365}y';
  }

  /// Formats a Unix timestamp (seconds) into a verbose relative time string.
  ///
  /// Examples: "Now", "3m ago", "2h ago"
  static String formatRelativeVerbose(int unixSeconds) {
    final short = formatRelative(unixSeconds);
    if (short == 'now') return 'Now';
    return '$short ago';
  }

  /// Formats a Unix timestamp (seconds) into a date label for chat dividers.
  ///
  /// Returns "Today", "Yesterday", the day name for the past week,
  /// or "Month Day" for older dates.
  static String formatDateLabel(int unixSeconds) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(messageDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMMM d').format(date);
  }
}
