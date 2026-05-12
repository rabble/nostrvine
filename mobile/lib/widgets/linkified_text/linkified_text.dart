import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_span_builder.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkifiedText extends ConsumerStatefulWidget {
  const LinkifiedText({
    required this.text,
    super.key,
    this.style,
    this.linkStyle,
    this.mentionStyle,
    this.maxLines,
    this.overflow,
    this.onVideoStateChange,
    this.onUrlTap,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextStyle? mentionStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final VoidCallback? onVideoStateChange;
  final Future<void> Function(String rawUrl)? onUrlTap;

  @override
  ConsumerState<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends ConsumerState<LinkifiedText> {
  List<TextSpan> _currentSpans = const [];

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    if (text.isEmpty) {
      _replaceCurrentSpans(const []);
      return const SizedBox.shrink();
    }

    final defaultStyle =
        widget.style ??
        const TextStyle(color: VineTheme.onSurfaceVariant, fontSize: 14);
    final linkStyle =
        widget.linkStyle ??
        const TextStyle(
          color: VineTheme.info,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
    final mentionStyle =
        widget.mentionStyle ?? linkStyle.copyWith(fontWeight: FontWeight.w600);
    final spans = LinkifiedTextSpanBuilder(
      text: text,
      defaultStyle: defaultStyle,
      linkStyle: linkStyle,
      mentionStyle: mentionStyle,
      videoLabel: Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      )?.clickableTextViewVideoLink,
      profileLabelForHex: _profileDisplayText,
      onHashtagTap: (hashtag) => _navigateToHashtagFeed(context, hashtag),
      onProfileTap: (hexPubkey) => _navigateToProfile(context, hexPubkey),
      onVideoTap: (routeReference) => _navigateToVideo(context, routeReference),
      onMentionTap: (username) => _navigateToSearch(context, username),
      onUrlTap: _handleUrlTap,
    ).build();

    if (!_hasClickableOrStylableToken(spans, defaultStyle)) {
      _replaceCurrentSpans(const []);
      return Text(
        text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    _replaceCurrentSpans(spans);
    return Text.rich(
      TextSpan(children: _currentSpans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  String _profileDisplayText(String hexPubkey) {
    final profile = ref.watch(userProfileReactiveProvider(hexPubkey)).value;
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

  void _navigateToHashtagFeed(BuildContext context, String hashtag) {
    widget.onVideoStateChange?.call();
    context.push(HashtagScreenRouter.pathForTag(hashtag));
  }

  void _navigateToProfile(BuildContext context, String hexPubkey) {
    widget.onVideoStateChange?.call();
    context.pushOtherProfile(hexPubkey);
  }

  void _navigateToVideo(BuildContext context, String routeReference) {
    widget.onVideoStateChange?.call();
    context.push(VideoDetailScreen.pathForId(routeReference));
  }

  void _navigateToSearch(BuildContext context, String username) {
    widget.onVideoStateChange?.call();
    context.go(SearchResultsPage.pathForQuery(username));
  }

  Future<void> _handleUrlTap(String rawUrl) async {
    widget.onVideoStateChange?.call();
    final customHandler = widget.onUrlTap;
    if (customHandler != null) {
      await customHandler(rawUrl);
      return;
    }
    await _launchUrl(rawUrl);
  }

  Future<void> _launchUrl(String rawUrl) async {
    final uri = _uriForRawUrl(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Uri? _uriForRawUrl(String rawUrl) {
    if (_emailRegex.hasMatch(rawUrl)) {
      return Uri(scheme: 'mailto', path: rawUrl);
    }
    final normalizedUrl =
        rawUrl.startsWith(
          RegExp('https?://', caseSensitive: false),
        )
        ? rawUrl
        : 'https://$rawUrl';
    return Uri.tryParse(normalizedUrl);
  }

  bool _hasClickableOrStylableToken(List<TextSpan> spans, TextStyle style) =>
      spans.any((span) => span.recognizer != null || span.style != style);

  void _replaceCurrentSpans(List<TextSpan> spans) {
    final previousSpans = _currentSpans;
    _currentSpans = spans;
    _disposeSpans(previousSpans);
  }

  void _disposeSpans(List<TextSpan> spans) {
    for (final span in spans) {
      span.recognizer?.dispose();
      final children = span.children;
      if (children == null) continue;
      _disposeInlineSpans(children);
    }
  }

  void _disposeInlineSpans(List<InlineSpan> spans) {
    for (final span in spans) {
      if (span is TextSpan) {
        span.recognizer?.dispose();
        final children = span.children;
        if (children != null) _disposeInlineSpans(children);
      }
    }
  }

  @override
  void dispose() {
    _disposeSpans(_currentSpans);
    super.dispose();
  }
}

final _emailRegex = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);
