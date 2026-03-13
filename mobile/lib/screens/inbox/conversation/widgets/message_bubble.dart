// ABOUTME: Chat message bubble widget for sent and received messages.
// ABOUTME: Supports message grouping with variable border radius and
// ABOUTME: conditional timestamp display based on position in group.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A single chat message bubble.
///
/// Sent messages (right-aligned): primaryAccessible background.
/// Received messages (left-aligned): containerLow background.
///
/// Grouping behaviour:
/// - Only the first message in a group shows a timestamp (inside the bubble,
///   above the message text).
/// - The last message in a group gets a small (4px) "tail" corner on the
///   sender's side (bottom-right for sent, bottom-left for received).
/// - Non-last messages have all 16px rounded corners.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.timestamp,
    required this.isSent,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    super.key,
  });

  final String message;
  final String timestamp;
  final bool isSent;

  /// Whether this is the first (topmost) message in a consecutive group
  /// from the same sender.  When true the timestamp is displayed.
  final bool isFirstInGroup;

  /// Whether this is the last (bottommost) message in a consecutive group
  /// from the same sender.  When true the tail corner is rendered.
  final bool isLastInGroup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: isFirstInGroup ? 8 : 2,
        bottom: isLastInGroup ? 8 : 2,
      ),
      child: Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSent
                ? VineTheme.primaryAccessible
                : VineTheme.containerLow,
            borderRadius: _borderRadius,
          ),
          child: Column(
            crossAxisAlignment: isSent
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (isFirstInGroup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    timestamp,
                    style: VineTheme.labelSmallFont(
                      color: VineTheme.onSurfaceMuted,
                    ),
                  ),
                ),
              Text(
                message,
                style: VineTheme.bodyMediumFont(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BorderRadius get _borderRadius {
    if (!isLastInGroup) {
      return BorderRadius.circular(16);
    }
    return BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isSent ? 16 : 4),
      bottomRight: Radius.circular(isSent ? 4 : 16),
    );
  }
}
