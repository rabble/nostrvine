import 'package:flutter/material.dart';
import 'package:openvine/widgets/linkified_text/linkified_text.dart';

/// A widget that displays text with clickable hashtags and Nostr references.
///
/// Parses hashtags (#something), profile references (npub/nprofile/hex with a
/// profile-like label), event references (note/nevent/naddr/hex), URLs, email
/// addresses, and plain @mentions.
class ClickableHashtagText extends StatelessWidget {
  const ClickableHashtagText({
    required this.text,
    super.key,
    this.style,
    this.hashtagStyle,
    this.mentionStyle,
    this.maxLines,
    this.overflow,
    this.onVideoStateChange,
    this.onUrlTap,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? hashtagStyle;
  final TextStyle? mentionStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final Function()? onVideoStateChange;
  final Future<void> Function(String rawUrl)? onUrlTap;

  @override
  Widget build(BuildContext context) {
    return LinkifiedText(
      text: text,
      style: style,
      linkStyle: hashtagStyle,
      mentionStyle: mentionStyle,
      maxLines: maxLines,
      overflow: overflow,
      onVideoStateChange: onVideoStateChange,
      onUrlTap: onUrlTap,
    );
  }
}
