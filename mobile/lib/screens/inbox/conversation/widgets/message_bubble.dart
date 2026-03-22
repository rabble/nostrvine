// ABOUTME: Chat message bubble widget for sent and received messages.
// ABOUTME: Supports message grouping with variable border radius,
// ABOUTME: conditional timestamp display, clickable URLs, and long-press actions.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Regex to detect linkifiable text in messages.
///
/// Matches (in priority order):
/// 1. Email addresses like `user@example.com`
/// 2. Explicit URLs starting with http:// or https://
/// 3. Bare domains like `google.com` or `sub.example.co.uk/path`
///
/// Bare domains must contain a dot followed by a valid TLD (2+ alpha chars).
/// Matching stops at whitespace or end of string.
final _linkRegex = RegExp(
  r'(?:[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})'
  r'|(?:https?://[^\s]+)'
  r'|(?:(?<![/@\w])(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}(?:[/][^\s]*)?)',
  caseSensitive: false,
);

final _emailRegex = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

/// A single chat message bubble.
///
/// Sent messages (right-aligned): surfaceContainer background.
/// Received messages (left-aligned): neutral10 background.
///
/// Grouping behaviour:
/// - Only the first message in a group shows a timestamp (inside the bubble,
///   above the message text).
/// - The last message in a group gets a small (4px) "tail" corner on the
///   sender's side (bottom-right for sent, bottom-left for received).
/// - Non-last messages have all 16px rounded corners.
///
/// URLs in message text are rendered as tappable links that open in an
/// external browser. Long-pressing the bubble triggers [onLongPress].
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.timestamp,
    required this.isSent,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.onLongPress,
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

  /// Called when the user long-presses the bubble.
  final VoidCallback? onLongPress;

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
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSent ? VineTheme.surfaceContainer : VineTheme.neutral10,
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
                _MessageText(message: message),
              ],
            ),
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

/// Renders message text with clickable URLs and email addresses.
///
/// Links matching [_linkRegex] are styled as underlined links. URLs open in
/// an external browser; email addresses open the default mail client.
/// Non-link text is rendered with the default body medium style.
class _MessageText extends StatelessWidget {
  const _MessageText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (!_linkRegex.hasMatch(message)) {
      return Text(message, style: VineTheme.bodyMediumFont());
    }

    return Text.rich(
      TextSpan(children: _buildSpans()),
    );
  }

  List<TextSpan> _buildSpans() {
    final spans = <TextSpan>[];
    final defaultStyle = VineTheme.bodyMediumFont();
    const linkStyle = TextStyle(
      color: VineTheme.info,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      letterSpacing: 0.25,
      decoration: TextDecoration.underline,
      decorationColor: VineTheme.info,
    );

    var lastEnd = 0;
    for (final match in _linkRegex.allMatches(message)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: message.substring(lastEnd, match.start),
            style: defaultStyle,
          ),
        );
      }

      final link = match.group(0)!;
      spans.add(
        TextSpan(
          text: link,
          style: linkStyle,
          recognizer: TapGestureRecognizer()..onTap = () => _openLink(link),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < message.length) {
      spans.add(
        TextSpan(
          text: message.substring(lastEnd),
          style: defaultStyle,
        ),
      );
    }

    return spans;
  }

  Future<void> _openLink(String link) async {
    final Uri? uri;
    if (_emailRegex.hasMatch(link)) {
      uri = Uri(scheme: 'mailto', path: link);
    } else {
      final normalized =
          link.startsWith(RegExp('https?://', caseSensitive: false))
          ? link
          : 'https://$link';
      uri = Uri.tryParse(normalized);
    }
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
