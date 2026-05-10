// ABOUTME: Shared comment-quote primitive for notification rows. Renders
// ABOUTME: the quoted comment text with curly quotes and an optional
// ABOUTME: muted relative-timestamp suffix appended inline at the end.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Renders a notification's quoted comment beneath the message text.
///
/// The text is wrapped in curly quotes and rendered in
/// [VineTheme.bodyMediumFont]. When [timestamp] is non-empty the
/// formatted relative time (e.g. `2d`) is appended inline at the end of
/// the quote in [VineTheme.onSurfaceMuted55] — keeping the timestamp
/// anchored to the visual end of the row rather than floating between
/// the message text and the quote, which is what happens when the quote
/// is rendered as a separate widget below a message that already
/// includes its own trailing timestamp.
///
/// Capped at two lines so a long quote doesn't push the row's intrinsic
/// height past the rest of the list.
class NotificationCommentQuote extends StatelessWidget {
  /// Creates a [NotificationCommentQuote].
  const NotificationCommentQuote({
    required this.text,
    this.timestamp,
    super.key,
  });

  /// The quoted comment body. Surrounding curly quotes are added by
  /// the widget — pass the raw string.
  final String text;

  /// Optional formatted relative timestamp (e.g. `2d`). When non-null
  /// and non-empty it's appended inline after the closing curly quote
  /// in muted styling.
  final String? timestamp;

  @override
  Widget build(BuildContext context) {
    final ts = timestamp;
    final showTimestamp = ts != null && ts.isNotEmpty;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '“$text”', style: VineTheme.bodyMediumFont()),
          if (showTimestamp)
            TextSpan(
              text: ' $ts',
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceMuted55,
              ),
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
