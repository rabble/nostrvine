// ABOUTME: Widget that renders text with clickable hashtags, nostr: mentions, and @mentions
// ABOUTME: Parses hashtags, nostr: URIs, and plain @mentions - makes them tappable for navigation

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/utils/hashtag_extractor.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/unified_logger.dart';

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

  /// Regex to detect nostr: URIs (npub and nprofile)
  static final _nostrUriRegex = RegExp(
    'nostr:(npub1[a-z0-9]{58}|nprofile1[a-z0-9]+)',
    caseSensitive: false,
  );

  /// Regex to detect plain @ mentions (legacy format from Vine)
  /// Matches @username where username is alphanumeric with underscores
  static final _plainMentionRegex = RegExp('@([a-zA-Z][a-zA-Z0-9_]{0,30})');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check if text contains any clickable/stylable elements
    final hasHashtags = HashtagExtractor.extractHashtags(text).isNotEmpty;
    final hasNostrUris = _nostrUriRegex.hasMatch(text);
    final hasPlainMentions = _plainMentionRegex.hasMatch(text);

    // If no clickable elements, return simple text
    if (!hasHashtags && !hasNostrUris && !hasPlainMentions) {
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
        style ?? const TextStyle(color: Colors.white70, fontSize: 14);
    final tagStyle =
        hashtagStyle ??
        const TextStyle(
          color: Colors.blue,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
    final profileStyle =
        mentionStyle ?? tagStyle.copyWith(fontWeight: FontWeight.w600);

    // Combined regex to find hashtags, nostr: URIs, and plain @mentions
    // Group 1: hashtag, Group 2: nostr ID, Group 3: plain mention username
    final combinedRegex = RegExp(
      r'#(\w+)|nostr:(npub1[a-z0-9]{58}|nprofile1[a-z0-9]+)|@([a-zA-Z][a-zA-Z0-9_]{0,30})',
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

      final fullMatch = match.group(0)!;

      if (fullMatch.startsWith('#')) {
        // Handle hashtag
        final hashtag = match.group(1)!;
        spans.add(
          TextSpan(
            text: fullMatch,
            style: tagStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _navigateToHashtagFeed(context, hashtag),
          ),
        );
      } else if (fullMatch.startsWith('nostr:')) {
        // Handle nostr: URI
        final nostrId = match.group(2)!;
        spans.add(_buildNostrMentionSpan(context, ref, nostrId, profileStyle));
      } else if (fullMatch.startsWith('@')) {
        // Handle plain @mention (legacy Vine format)
        final username = match.group(3)!;
        spans.add(_buildPlainMentionSpan(context, ref, username, profileStyle));
      }

      lastEnd = match.end;
    }

    // Add any remaining text after the last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: defaultStyle));
    }

    return spans;
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

    // Try to get cached profile
    final userProfileService = ref.read(userProfileServiceProvider);
    final profile = userProfileService.getCachedProfile(hexPubkey);

    // Trigger background fetch if not cached
    if (profile == null) {
      userProfileService.fetchProfile(hexPubkey);
    }

    // Display name: @username if available, otherwise @truncated_npub
    final displayName = profile?.bestDisplayName;
    final displayText = displayName != null
        ? '@$displayName'
        : '@${NostrKeyUtils.truncateNpub(hexPubkey)}';

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
    // Try to find a cached profile that matches this username
    final userProfileService = ref.read(userProfileServiceProvider);
    final allProfiles = userProfileService.allProfiles;

    // Search for a profile with matching name or displayName (case-insensitive)
    final usernameLower = username.toLowerCase();
    String? matchedPubkey;

    for (final entry in allProfiles.entries) {
      final profile = entry.value;
      final nameMatch = profile.name?.toLowerCase() == usernameLower;
      final displayNameMatch =
          profile.displayName?.toLowerCase() == usernameLower;
      if (nameMatch || displayNameMatch) {
        matchedPubkey = entry.key;
        break;
      }
    }

    return TextSpan(
      text: '@$username',
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          if (matchedPubkey != null) {
            // Found matching profile - navigate directly to it
            _navigateToProfile(context, matchedPubkey);
          } else {
            // No cached match - navigate to search with username
            _navigateToSearch(context, username);
          }
        },
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

    // Navigate to hashtag grid view (no index = grid mode)
    context.go(HashtagScreenRouter.pathForTag(hashtag));
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

    // Navigate to search with the username pre-filled
    context.goSearch(searchTerm);
  }
}
