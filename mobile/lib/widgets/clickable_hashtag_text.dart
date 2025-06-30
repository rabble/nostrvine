// ABOUTME: Widget that renders text with clickable hashtags
// ABOUTME: Parses hashtags in text and makes them tappable for navigation

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../utils/hashtag_extractor.dart';
import '../screens/hashtag_feed_screen.dart';
import '../utils/unified_logger.dart';
import '../main.dart';

/// A widget that displays text with clickable hashtags
class ClickableHashtagText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? hashtagStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final Function()? onVideoStateChange;

  const ClickableHashtagText({
    super.key,
    required this.text,
    this.style,
    this.hashtagStyle,
    this.maxLines,
    this.overflow,
    this.onVideoStateChange,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    // Extract hashtags from the text
    final hashtags = HashtagExtractor.extractHashtags(text);
    
    // If no hashtags, return simple text
    if (hashtags.isEmpty) {
      return SelectableText(
        text,
        style: style,
        maxLines: maxLines,
      );
    }

    // Build text spans with clickable hashtags
    final spans = _buildTextSpans(context);
    
    return SelectableText.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
    );
  }

  List<TextSpan> _buildTextSpans(BuildContext context) {
    final spans = <TextSpan>[];
    final defaultStyle = style ?? const TextStyle(color: Colors.white70, fontSize: 14);
    final tagStyle = hashtagStyle ?? const TextStyle(
      color: Colors.blue,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
    );
    
    // Regular expression to find hashtags
    final hashtagRegex = RegExp(r'#(\w+)', caseSensitive: false);
    
    int lastEnd = 0;
    for (final match in hashtagRegex.allMatches(text)) {
      // Add text before the hashtag
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: defaultStyle,
        ));
      }
      
      // Add the clickable hashtag
      final hashtag = match.group(1)!;
      spans.add(TextSpan(
        text: match.group(0), // Include the # symbol
        style: tagStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => _navigateToHashtagFeed(context, hashtag),
      ));
      
      lastEnd = match.end;
    }
    
    // Add any remaining text after the last hashtag
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: defaultStyle,
      ));
    }
    
    return spans;
  }

  void _navigateToHashtagFeed(BuildContext context, String hashtag) {
    Log.debug('📍 Navigating to hashtag feed: #$hashtag', name: 'ClickableHashtagText', category: LogCategory.ui);
    
    // Notify parent about video state change if callback provided
    onVideoStateChange?.call();
    
    // Use global navigation key for hashtag navigation
    final mainNavState = mainNavigationKey.currentState;
    
    if (mainNavState != null) {
      // Navigate through main navigation to maintain footer
      mainNavState.navigateToHashtag(hashtag);
    } else {
      // Fallback to direct navigation
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => HashtagFeedScreen(hashtag: hashtag),
        ),
      );
    }
  }
}