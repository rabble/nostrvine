// ABOUTME: Widget that renders text with clickable hashtags, nostr: mentions, and @mentions
// ABOUTME: Parses hashtags, nostr: URIs, and plain @mentions - makes them tappable for navigation

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that displays text with clickable hashtags and Nostr references.
///
/// Parses hashtags (#something), profile references (npub/nprofile/hex with a
/// profile-like label), and event references (note/nevent/naddr/hex).
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

  /// Regex to detect Nostr profile and event references.
  static final _nostrReferenceRegex = RegExp(
    r'(?<![A-Za-z0-9])(?:nostr:)?((?:npub|nprofile|note|nevent|naddr)1[a-z0-9]+)\b',
    caseSensitive: false,
  );

  /// Regex to detect raw 32-byte hex references.
  static final _hexReferenceRegex = RegExp(
    '(?<![A-Fa-f0-9])([A-Fa-f0-9]{64})(?![A-Fa-f0-9])',
  );

  /// Regex to detect plain @ mentions (legacy format from Vine)
  /// Matches @username where username is alphanumeric with underscores
  static final _plainMentionRegex = RegExp('@([a-zA-Z][a-zA-Z0-9_]{0,30})');

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Regex to detect plain URLs and bare domains.
  static final _urlRegex = RegExp(
    r'(?:[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})'
    r'|(?:https?:\/\/[^\s]+|www\.[^\s]+|(?<![@\w])(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s]*)?)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check if text contains any clickable/stylable elements
    final hasHashtags = HashtagExtractor.extractHashtags(text).isNotEmpty;
    final hasNostrMentions = _nostrReferenceRegex.hasMatch(text);
    final hasHexReferences = _hexReferenceRegex.hasMatch(text);
    final hasPlainMentions = _plainMentionRegex.hasMatch(text);
    final hasUrls = _urlRegex.hasMatch(text);

    // If no clickable elements, return simple text
    if (!hasHashtags &&
        !hasNostrMentions &&
        !hasHexReferences &&
        !hasPlainMentions &&
        !hasUrls) {
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

    // Combined regex to find URLs, hashtags, Nostr references, hex references,
    // and plain @mentions.
    // Group 1: URL, Group 2: hashtag, Group 3: nostr ID,
    // Group 4: hex reference, Group 5: plain mention username
    final combinedRegex = RegExp(
      r'((?:[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})|(?:https?:\/\/[^\s]+|www\.[^\s]+|(?<![@\w])(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s]*)?))|#(\w+)|(?<![A-Za-z0-9])(?:nostr:)?((?:npub|nprofile|note|nevent|naddr)1[a-z0-9]+)\b|(?<![A-Fa-f0-9])([A-Fa-f0-9]{64})(?![A-Fa-f0-9])|@([a-zA-Z][a-zA-Z0-9_]{0,30})',
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
      final hexReference = match.group(4);
      final plainMention = match.group(5);

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
        spans.add(
          _buildNostrReferenceSpan(context, ref, nostrId, profileStyle),
        );
      } else if (hexReference != null) {
        spans.add(
          _buildHexReferenceSpan(
            context,
            ref,
            hexReference,
            match.start,
            profileStyle,
          ),
        );
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
          final customHandler = onUrlTap;
          if (customHandler != null) {
            unawaited(customHandler(matchedUrl));
          } else {
            _launchUrl(matchedUrl);
          }
        },
    );
  }

  TextSpan _buildNostrReferenceSpan(
    BuildContext context,
    WidgetRef ref,
    String nostrId,
    TextStyle style,
  ) {
    final normalized = _stripNostrScheme(nostrId);
    final lower = normalized.toLowerCase();

    if (lower.startsWith('npub1') || lower.startsWith('nprofile1')) {
      final hexPubkey = npubToHexOrNull(normalized);
      if (hexPubkey == null) {
        return TextSpan(text: nostrId, style: style);
      }
      return _buildProfileReferenceSpan(context, ref, hexPubkey, style);
    }

    if (lower.startsWith('note1') ||
        lower.startsWith('nevent1') ||
        lower.startsWith('naddr1')) {
      return _buildVideoReferenceSpan(context, normalized, style);
    }

    return TextSpan(text: nostrId, style: style);
  }

  TextSpan _buildHexReferenceSpan(
    BuildContext context,
    WidgetRef ref,
    String hexReference,
    int start,
    TextStyle style,
  ) {
    if (_hexReferenceLooksLikeProfile(start)) {
      return _buildProfileReferenceSpan(context, ref, hexReference, style);
    }

    return _buildVideoReferenceSpan(context, hexReference, style);
  }

  TextSpan _buildProfileReferenceSpan(
    BuildContext context,
    WidgetRef ref,
    String hexPubkey,
    TextStyle style,
  ) {
    // Try to get cached profile (reactive provider handles background fetch)
    final profile = ref.watch(userProfileReactiveProvider(hexPubkey)).value;

    final displayText = _profileDisplayText(profile, hexPubkey);

    return TextSpan(
      text: displayText,
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () => _navigateToProfile(context, hexPubkey),
    );
  }

  TextSpan _buildVideoReferenceSpan(
    BuildContext context,
    String routeReference,
    TextStyle style,
  ) {
    return TextSpan(
      text: context.l10n.clickableTextViewVideoLink,
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () => _navigateToVideo(context, routeReference),
    );
  }

  String _profileDisplayText(UserProfile? profile, String hexPubkey) {
    final profileText = switch (profile) {
      UserProfile(:final displayName?) when displayName.isNotEmpty =>
        displayName,
      UserProfile(:final name?) when name.isNotEmpty => name,
      UserProfile(:final shortDisplayNip05?)
          when shortDisplayNip05.isNotEmpty =>
        shortDisplayNip05,
      _ => UserProfile.defaultDisplayNameFor(hexPubkey),
    };
    return profileText.startsWith('@') ? profileText : '@$profileText';
  }

  bool _hexReferenceLooksLikeProfile(int start) {
    final prefixStart = start >= 32 ? start - 32 : 0;
    final prefix = text.substring(prefixStart, start).toLowerCase();
    return RegExp(
      r'(profile|pubkey|public key|author|user)\s*:?\s*$',
    ).hasMatch(prefix);
  }

  String _stripNostrScheme(String reference) {
    return reference.replaceFirst(RegExp('^nostr:', caseSensitive: false), '');
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

  void _navigateToVideo(BuildContext context, String reference) {
    Log.debug(
      'Navigating to video reference',
      name: 'ClickableHashtagText',
      category: LogCategory.ui,
    );

    onVideoStateChange?.call();

    final routeReference = _normalizeVideoRouteReference(reference);
    context.push(VideoDetailScreen.pathForId(routeReference));
  }

  String _normalizeVideoRouteReference(String reference) {
    final normalized = _stripNostrScheme(reference);
    final lower = normalized.toLowerCase();

    if (lower.startsWith('note1')) {
      final decoded = Nip19.decode(normalized);
      if (decoded.length == 64) return decoded;
    }

    if (lower.startsWith('nevent1')) {
      final decoded = NIP19Tlv.decodeNevent(normalized);
      final id = decoded?.id;
      if (id != null && id.isNotEmpty) return id;
    }

    return normalized;
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
    final Uri? uri;
    if (_emailRegex.hasMatch(rawUrl)) {
      uri = Uri(scheme: 'mailto', path: rawUrl);
    } else {
      final normalizedUrl =
          rawUrl.startsWith(RegExp('https?://', caseSensitive: false))
          ? rawUrl
          : 'https://$rawUrl';
      uri = Uri.tryParse(normalizedUrl);
    }
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
