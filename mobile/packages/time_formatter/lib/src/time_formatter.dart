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
    final then = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal();
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
    final date = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(messageDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMMM d').format(date);
  }

  /// Formats a Unix timestamp (seconds) for conversation list timestamps.
  ///
  /// - Under 1 minute: "1m" (floor — never "0m" or "now")
  /// - Under 1 hour: relative minutes — "1m", "5m", "59m"
  /// - Same calendar day: relative hours — "1h", "3h", "23h"
  /// - Yesterday: "Yesterday"
  /// - 2–6 days ago: day of week — "Monday", "Tuesday"
  /// - 7–364 days (same year): "Mar 3", "Jan 15"
  /// - 1+ years ago: "Mar 3, 2025"
  static String formatConversationTimestamp(int unixSeconds) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return '1m';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';

    final dayDiff = _calendarDayDiff(now, date);
    if (dayDiff == 0) return '${diff.inHours}h';
    return _formatByDayDiff(dayDiff, date, now);
  }

  /// Formats a Unix timestamp (seconds) for message bubble timestamps.
  ///
  /// Returns "Now" for < 60s, "9:41 AM" for today, "Yesterday" for
  /// yesterday, day name for 2–6 days, "Mar 3" for same year, or
  /// "Mar 3, 2025" for older.
  static String formatMessageTime(int unixSeconds) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toLocal();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Now';

    final dayDiff = _calendarDayDiff(now, date);
    if (dayDiff == 0) return DateFormat.jm().format(date);
    return _formatByDayDiff(dayDiff, date, now);
  }

  /// Returns the number of calendar days between [now] and [date].
  static int _calendarDayDiff(DateTime now, DateTime date) {
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    return today.difference(messageDay).inDays;
  }

  /// Shared formatting for dates 1+ days old.
  static String _formatByDayDiff(int dayDiff, DateTime date, DateTime now) {
    if (dayDiff == 1) return 'Yesterday';
    if (dayDiff >= 2 && dayDiff <= 6) return DateFormat.EEEE().format(date);
    if (date.year == now.year) return DateFormat.MMMd().format(date);
    return DateFormat.yMMMd().format(date);
  }
}
