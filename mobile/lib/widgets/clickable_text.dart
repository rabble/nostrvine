// ABOUTME: Renders text with clickable URLs, hashtags, nostr mentions, and @mentions.
// ABOUTME: Owns TapGestureRecognizer lifecycle so spans don't leak across rebuilds.

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

/// Renders [text] with clickable URLs, hashtags, `nostr:` mentions, and
/// plain `@username` mentions.
///
/// URLs are validated with [Uri.tryParse] and have trailing punctuation
/// (`.,;:!?)]}>`) stripped before launching. Hashtags navigate to the
/// hashtag screen. Nostr mentions resolve to the cached profile when
/// available, falling back to a truncated npub.
///
/// All [TapGestureRecognizer]s created for the spans are tracked and
/// disposed when the widget is removed or the spans are rebuilt — the
/// old [ClickableHashtagText] leaked them on every rebuild.
class ClickableText extends ConsumerStatefulWidget {
  const ClickableText({
    required this.text,
    super.key,
    this.style,
    this.hashtagStyle,
    this.mentionStyle,
    this.maxLines,
    this.overflow,
    this.onVideoStateChange,
    this.onLaunchUrl,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? hashtagStyle;
  final TextStyle? mentionStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final VoidCallback? onVideoStateChange;

  /// Hook for tests / alternate launch behaviour. Defaults to
  /// `url_launcher`'s `launchUrl` in external-application mode.
  final Future<bool> Function(Uri uri)? onLaunchUrl;

  /// Trailing characters stripped from a matched URL before launch.
  static const _urlTrailingPunctuation = '.,;:!?)]}>';

  static final _nostrMentionRegex = RegExp(
    r'(?<![A-Za-z0-9])(?:nostr:)?(npub1[a-z0-9]{58}|nprofile1[a-z0-9]+)\b',
    caseSensitive: false,
  );

  static final _plainMentionRegex = RegExp('@([a-zA-Z][a-zA-Z0-9_]{0,30})');

  /// Combined regex covering URLs, hashtags, nostr ids, and plain mentions.
  ///
  /// Group 1: URL (incl. bare domain) · Group 2: hashtag · Group 3: nostr id ·
  /// Group 4: plain @mention.
  static final _combinedRegex = RegExp(
    r'(https?:\/\/[^\s]+|www\.[^\s]+|(?<![@\w])(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s]*)?)|#(\w+)|(?<![A-Za-z0-9])(?:nostr:)?(npub1[a-z0-9]{58}|nprofile1[a-z0-9]+)\b|@([a-zA-Z][a-zA-Z0-9_]{0,30})',
    caseSensitive: false,
  );

  @override
  ConsumerState<ClickableText> createState() => _ClickableTextState();
}

class _ClickableTextState extends ConsumerState<ClickableText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _trackRecognizer(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasHashtags = HashtagExtractor.extractHashtags(
      widget.text,
    ).isNotEmpty;
    final hasNostrMentions = ClickableText._nostrMentionRegex.hasMatch(
      widget.text,
    );
    final hasPlainMentions = ClickableText._plainMentionRegex.hasMatch(
      widget.text,
    );
    final hasUrls = _hasUrl(widget.text);

    if (!hasHashtags && !hasNostrMentions && !hasPlainMentions && !hasUrls) {
      _disposeRecognizers();
      return Text(
        widget.text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    _disposeRecognizers();
    final spans = _buildTextSpans(context);

    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  bool _hasUrl(String s) =>
      ClickableText._combinedRegex.allMatches(s).any((m) => m.group(1) != null);

  List<InlineSpan> _buildTextSpans(BuildContext context) {
    final spans = <InlineSpan>[];
    final defaultStyle =
        widget.style ??
        const TextStyle(color: VineTheme.onSurfaceVariant, fontSize: 14);
    final tagStyle =
        widget.hashtagStyle ??
        const TextStyle(
          color: VineTheme.info,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
    final profileStyle =
        widget.mentionStyle ?? tagStyle.copyWith(fontWeight: FontWeight.w600);

    var lastEnd = 0;
    for (final match in ClickableText._combinedRegex.allMatches(widget.text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: widget.text.substring(lastEnd, match.start),
            style: defaultStyle,
          ),
        );
      }

      final matchedUrl = match.group(1);
      final hashtag = match.group(2);
      final nostrId = match.group(3);
      final plainMention = match.group(4);

      if (matchedUrl != null) {
        final urlSpans = _buildUrlSpans(matchedUrl, tagStyle, defaultStyle);
        spans.addAll(urlSpans);
      } else if (hashtag != null) {
        spans.add(
          TextSpan(
            text: '#$hashtag',
            style: tagStyle,
            recognizer: _trackRecognizer(
              () => _navigateToHashtagFeed(context, hashtag),
            ),
          ),
        );
      } else if (nostrId != null) {
        spans.add(_buildNostrMentionSpan(context, nostrId, profileStyle));
      } else if (plainMention != null) {
        spans.add(_buildPlainMentionSpan(context, plainMention, profileStyle));
      }

      lastEnd = match.end;
    }

    if (lastEnd < widget.text.length) {
      spans.add(
        TextSpan(text: widget.text.substring(lastEnd), style: defaultStyle),
      );
    }

    return spans;
  }

  /// Splits [matched] into a tappable URL span plus any trailing punctuation
  /// that bled into the regex match. Falls back to a plain text span if
  /// [Uri.tryParse] rejects the cleaned URL.
  List<InlineSpan> _buildUrlSpans(
    String matched,
    TextStyle linkStyle,
    TextStyle defaultStyle,
  ) {
    var end = matched.length;
    while (end > 0 &&
        ClickableText._urlTrailingPunctuation.contains(matched[end - 1])) {
      end -= 1;
    }
    final url = matched.substring(0, end);
    final trailing = matched.substring(end);

    final normalized = url.startsWith(RegExp('https?://', caseSensitive: false))
        ? url
        : 'https://$url';
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return [TextSpan(text: matched, style: defaultStyle)];
    }

    return [
      TextSpan(
        text: url,
        style: linkStyle,
        recognizer: _trackRecognizer(() {
          widget.onVideoStateChange?.call();
          _launchUrl(uri);
        }),
        semanticsLabel: url,
      ),
      if (trailing.isNotEmpty) TextSpan(text: trailing, style: defaultStyle),
    ];
  }

  TextSpan _buildNostrMentionSpan(
    BuildContext context,
    String nostrId,
    TextStyle style,
  ) {
    final hexPubkey = npubToHexOrNull(nostrId);
    if (hexPubkey == null) {
      return TextSpan(text: 'nostr:$nostrId', style: style);
    }

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
      recognizer: _trackRecognizer(
        () => _navigateToProfile(context, hexPubkey),
      ),
    );
  }

  TextSpan _buildPlainMentionSpan(
    BuildContext context,
    String username,
    TextStyle style,
  ) {
    return TextSpan(
      text: '@$username',
      style: style,
      recognizer: _trackRecognizer(() => _navigateToSearch(context, username)),
    );
  }

  void _navigateToHashtagFeed(BuildContext context, String hashtag) {
    Log.debug(
      '📍 Navigating to hashtag grid: #$hashtag',
      name: 'ClickableText',
      category: LogCategory.ui,
    );
    widget.onVideoStateChange?.call();
    context.push(HashtagScreenRouter.pathForTag(hashtag));
  }

  void _navigateToProfile(BuildContext context, String hexPubkey) {
    Log.debug(
      '📍 Navigating to profile: $hexPubkey',
      name: 'ClickableText',
      category: LogCategory.ui,
    );
    widget.onVideoStateChange?.call();
    context.pushOtherProfile(hexPubkey);
  }

  void _navigateToSearch(BuildContext context, String searchTerm) {
    Log.debug(
      '📍 Navigating to search: $searchTerm',
      name: 'ClickableText',
      category: LogCategory.ui,
    );
    widget.onVideoStateChange?.call();
    context.go(SearchResultsPage.pathForQuery(searchTerm));
  }

  Future<void> _launchUrl(Uri uri) async {
    final launcher = widget.onLaunchUrl ?? _defaultLaunch;
    await launcher(uri);
  }

  Future<bool> _defaultLaunch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
