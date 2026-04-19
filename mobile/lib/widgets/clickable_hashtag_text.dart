// ABOUTME: Widget that renders text with clickable hashtags, nostr: mentions, and @mentions
// ABOUTME: Parses hashtags, nostr: URIs, and plain @mentions - makes them tappable for navigation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that displays text with clickable hashtags and nostr: mentions
///
/// Parses both hashtags (#something) and nostr: URIs (nostr:npub..., nostr:nprofile...)
/// and makes them tappable for navigation. Nostr mentions are displayed as @username
/// if the profile is cached, otherwise as a truncated npub.
class ClickableHashtagText extends ConsumerWidget {
  const ClickableHashtagText({
    required this.text,
    super.key,
    this.style,
    this.hashtagStyle,
    this.mentionStyle,
    this.maxLines,
    this.overflow,
    this.onVideoStateChange,
  });
  final String text;
  final TextStyle? style;
  final TextStyle? hashtagStyle;
  final TextStyle? mentionStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final Function()? onVideoStateChange;

  /// Regex to detect bare or `nostr:`-prefixed npub/nprofile mentions.
  static final _nostrMentionRegex = RegExp(
    r'(?<![A-Za-z0-9])(?:nostr:)?(npub1[a-z0-9]{58}|nprofile1[a-z0-9]+)\b',
    caseSensitive: false,
  );

  /// Regex to detect plain @ mentions (legacy format from Vine)
  /// Matches @username where username is alphanumeric with underscores
  static final _plainMentionRegex = RegExp('@([a-zA-Z][a-zA-Z0-9_]{0,30})');

  /// Regex to detect plain URLs and bare domains.
  static final _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+|www\.[^\s]+|(?<![@\w])(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s]*)?)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check if text contains any clickable/stylable elements
    final hasHashtags = HashtagExtractor.extractHashtags(text).isNotEmpty;
    final hasNostrMentions = _nostrMentionRegex.hasMatch(text);
    final hasPlainMentions = _plainMentionRegex.hasMatch(text);
    final hasUrls = _urlRegex.hasMatch(text);

    // If no clickable elements, return simple text
    if (!hasHashtags && !hasNostrMentions && !hasPlainMentions && !hasUrls) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    // Build text spans with clickable hashtags and nostr mentions
    final spans = _buildTextSpans(context, ref);

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  List<TextSpan> _buildTextSpans(BuildContext context, WidgetRef ref) {
    final spans = <TextSpan>[];
    final defaultStyle =
        style ??
        const TextStyle(color: VineTheme.onSurfaceVariant, fontSize: 14);
    final tagStyle =
        hashtagStyle ??
        const TextStyle(
          color: VineTheme.info,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
    final profileStyle =
        mentionStyle ?? tagStyle.copyWith(fontWeight: FontWeight.w600);

    // Combined regex to find URLs, hashtags, npub/nprofile mentions,
    // and plain @mentions.
    // Group 1: URL, Group 2: hashtag, Group 3: nostr ID,
    // Group 4: plain mention username
    final combinedRegex = RegExp(
      r'(https?:\/\/[^\s]+|www\.[^\s]+|(?<![@\w])(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s]*)?)|#(\w+)|(?<![A-Za-z0-9])(?:nostr:)?(npub1[a-z0-9]{58}|nprofile1[a-z0-9]+)\b|@([a-zA-Z][a-zA-Z0-9_]{0,30})',
      caseSensitive: false,
    );

    var lastEnd = 0;
    for (final match in combinedRegex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: defaultStyle,
          ),
        );
      }

      final matchedUrl = match.group(1);
      final hashtag = match.group(2);
      final nostrId = match.group(3);
      final plainMention = match.group(4);

      if (matchedUrl != null) {
        spans.add(_buildUrlSpan(matchedUrl, tagStyle));
      } else if (hashtag != null) {
        // Handle hashtag
        spans.add(
          TextSpan(
            text: '#$hashtag',
            style: tagStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _navigateToHashtagFeed(context, hashtag),
          ),
        );
      } else if (nostrId != null) {
        // Handle bare or `nostr:`-prefixed npub/nprofile mention.
        spans.add(_buildNostrMentionSpan(context, ref, nostrId, profileStyle));
      } else if (plainMention != null) {
        // Handle plain @mention (legacy Vine format)
        spans.add(
          _buildPlainMentionSpan(context, ref, plainMention, profileStyle),
        );
      }

      lastEnd = match.end;
    }

    // Add any remaining text after the last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: defaultStyle));
    }

    return spans;
  }

  TextSpan _buildUrlSpan(String matchedUrl, TextStyle style) {
    return TextSpan(
      text: matchedUrl,
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          onVideoStateChange?.call();
          _launchUrl(matchedUrl);
        },
    );
  }

  /// Build a TextSpan for a nostr mention (npub or nprofile)
  ///
  /// Displays @username if profile is cached, otherwise truncated npub
  TextSpan _buildNostrMentionSpan(
    BuildContext context,
    WidgetRef ref,
    String nostrId,
    TextStyle style,
  ) {
    // Convert npub/nprofile to hex pubkey
    final hexPubkey = npubToHexOrNull(nostrId);
    if (hexPubkey == null) {
      // Invalid nostr ID, just show it as-is
      return TextSpan(text: 'nostr:$nostrId', style: style);
    }

    // Try to get cached profile (reactive provider handles background fetch)
    final profile = ref.watch(userProfileReactiveProvider(hexPubkey)).value;

    final displayText = switch (profile) {
      UserProfile(:final displayName?) when displayName.isNotEmpty =>
        '@$displayName',
      UserProfile(:final name?) when name.isNotEmpty => '@$name',
      UserProfile(:final displayNip05?) when displayNip05.isNotEmpty =>
        displayNip05,
      _ => '@${NostrKeyUtils.truncateNpub(hexPubkey)}',
    };

    return TextSpan(
      text: displayText,
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () => _navigateToProfile(context, hexPubkey),
    );
  }

  /// Build a TextSpan for a plain @mention (legacy Vine format)
  ///
  /// Tries to find a matching cached profile by username/displayName.
  /// If found, navigates to that profile. Otherwise navigates to search.
  TextSpan _buildPlainMentionSpan(
    BuildContext context,
    WidgetRef ref,
    String username,
    TextStyle style,
  ) {
    // Plain @mentions (legacy Vine format) — navigate to search
    return TextSpan(
      text: '@$username',
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () => _navigateToSearch(context, username),
    );
  }

  void _navigateToHashtagFeed(BuildContext context, String hashtag) {
    Log.debug(
      '📍 Navigating to hashtag grid: #$hashtag',
      name: 'ClickableHashtagText',
      category: LogCategory.ui,
    );

    // Notify parent about video state change if callback provided
    onVideoStateChange?.call();

    // Navigate to standalone hashtag screen (outside shell, no bottom nav)
    context.push(HashtagScreenRouter.pathForTag(hashtag));
  }

  void _navigateToProfile(BuildContext context, String hexPubkey) {
    Log.debug(
      '📍 Navigating to profile: $hexPubkey',
      name: 'ClickableHashtagText',
      category: LogCategory.ui,
    );

    // Notify parent about video state change if callback provided
    onVideoStateChange?.call();

    // Navigate to the user's profile
    context.pushOtherProfile(hexPubkey);
  }

  void _navigateToSearch(BuildContext context, String searchTerm) {
    Log.debug(
      '📍 Navigating to search: $searchTerm',
      name: 'ClickableHashtagText',
      category: LogCategory.ui,
    );

    // Notify parent about video state change if callback provided
    onVideoStateChange?.call();

    // Navigate to search results with the username pre-filled
    context.go(SearchResultsPage.pathForQuery(searchTerm));
  }

  Future<void> _launchUrl(String rawUrl) async {
    final normalizedUrl =
        rawUrl.startsWith(
          RegExp('https?://', caseSensitive: false),
        )
        ? rawUrl
        : 'https://$rawUrl';
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
