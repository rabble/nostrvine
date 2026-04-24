import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/widgets/hashtag_more_menu.dart';

/// Called when a profile reference is tapped.
typedef LinkifiedProfileTap = void Function(String hexPubkey);

/// Called when a video/event reference is tapped.
typedef LinkifiedVideoTap = void Function(String routeReference);

/// Called when a hashtag is tapped.
typedef LinkifiedHashtagTap = void Function(String hashtag);

/// Called when a plain @mention is tapped.
typedef LinkifiedMentionTap = void Function(String username);

/// Called when a URL or email address is tapped.
typedef LinkifiedUrlTap = Future<void> Function(String rawUrl);

/// Builds linkified [InlineSpan]s without owning navigation or data lookup.
class LinkifiedTextSpanBuilder {
  /// Creates a span builder for [text].
  const LinkifiedTextSpanBuilder({
    required this.text,
    required this.defaultStyle,
    required this.linkStyle,
    this.mentionStyle,
    this.onHashtagTap,
    this.onProfileTap,
    this.onVideoTap,
    this.onMentionTap,
    this.onUrlTap,
    this.profileLabelForHex,
    this.videoLabel,
    this.showHashtagMoreButton = false,
    this.hashtagMoreLabelStyle,
    this.onVideoStateChange,
  });

  static final _combinedRegex = RegExp(
    r'((?:[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})|(?:https?:\/\/[^\s]+|www\.[^\s]+|(?<![@\w])(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s]*)?))|#(\w+)|(?<![A-Za-z0-9])(?:nostr:)?((?:npub|nprofile|note|nevent|naddr)1[a-z0-9]+)\b|(?<![A-Fa-f0-9])([A-Fa-f0-9]{64})(?![A-Fa-f0-9])|@([a-zA-Z][a-zA-Z0-9_]{0,30})',
    caseSensitive: false,
  );

  static const _trailingUrlPunctuation = '.!,?:;';

  /// Text to split into plain and tappable spans.
  final String text;

  /// Style for non-link text.
  final TextStyle defaultStyle;

  /// Style for hashtags, URLs, and video references.
  final TextStyle linkStyle;

  /// Optional style for profile and @mention references.
  final TextStyle? mentionStyle;

  /// Callback for hashtag taps, without the leading `#`.
  final LinkifiedHashtagTap? onHashtagTap;

  /// Callback for profile taps with a hex public key.
  final LinkifiedProfileTap? onProfileTap;

  /// Callback for video/event taps with a route-safe reference.
  final LinkifiedVideoTap? onVideoTap;

  /// Callback for plain @mention taps, without the leading `@`.
  final LinkifiedMentionTap? onMentionTap;

  /// Callback for URL/email taps with the matched raw text.
  final LinkifiedUrlTap? onUrlTap;

  /// Resolves a profile label for a decoded hex public key.
  final String Function(String hexPubkey)? profileLabelForHex;

  /// Display label for video/event references.
  final String? videoLabel;

  /// When true, each hashtag is rendered as `#tag` plus an app-bar-style
  /// overflow control that opens [showHashtagMoreMenu].
  final bool showHashtagMoreButton;

  /// Label style for `#tag` when [showHashtagMoreButton] is true.
  final TextStyle? hashtagMoreLabelStyle;

  /// Notified before hashtag navigation or opening the hashtag overflow menu.
  final VoidCallback? onVideoStateChange;

  /// Builds spans preserving the token precedence from [ClickableHashtagText].
  ///
  /// When [showHashtagMoreButton] is true, [context] and [ref] must be
  /// provided (typically from a [ConsumerStatefulWidget]).
  List<InlineSpan> build([BuildContext? context, WidgetRef? ref]) {
    assert(
      !showHashtagMoreButton || (context != null && ref != null),
      'BuildContext and WidgetRef are required when showHashtagMoreButton is true.',
    );

    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in _combinedRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(_plainSpan(text.substring(lastEnd, match.start)));
      }

      final matchedUrl = match.group(1);
      final hashtag = match.group(2);
      final nostrId = match.group(3);
      final hexReference = match.group(4);
      final plainMention = match.group(5);

      if (matchedUrl != null) {
        spans.addAll(_buildUrlSpans(matchedUrl));
      } else if (hashtag != null) {
        spans.add(_buildHashtagSpan(hashtag, context, ref));
      } else if (nostrId != null) {
        spans.add(_buildNostrReferenceSpan(nostrId));
      } else if (hexReference != null) {
        spans.add(_buildHexReferenceSpan(hexReference, match.start));
      } else if (plainMention != null) {
        spans.add(_buildPlainMentionSpan(plainMention));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(_plainSpan(text.substring(lastEnd)));
    }

    if (spans.isEmpty) return [_plainSpan(text)];
    return spans;
  }

  TextSpan _plainSpan(String value) =>
      TextSpan(text: value, style: defaultStyle);

  List<InlineSpan> _buildUrlSpans(String matchedUrl) {
    final linkText = _trimTrailingUrlPunctuation(matchedUrl);
    final trailingText = matchedUrl.substring(linkText.length);
    return [
      TextSpan(
        text: linkText,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            final callback = onUrlTap;
            if (callback != null) unawaited(callback(linkText));
          },
      ),
      if (trailingText.isNotEmpty) _plainSpan(trailingText),
    ];
  }

  InlineSpan _buildHashtagSpan(
    String hashtag,
    BuildContext? context,
    WidgetRef? ref,
  ) {
    if (!showHashtagMoreButton) {
      return TextSpan(
        text: '#$hashtag',
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => onHashtagTap?.call(hashtag),
      );
    }
    final labelStyle = hashtagMoreLabelStyle ?? VineTheme.titleMediumFont();
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: _HashtagWithMoreButton(
        hashtag: hashtag,
        labelStyle: labelStyle,
        onTagTap: () => onHashtagTap?.call(hashtag),
        onVideoStateChange: onVideoStateChange,
      ),
    );
  }

  TextSpan _buildNostrReferenceSpan(String nostrId) {
    final normalized = _stripNostrScheme(nostrId);
    final lower = normalized.toLowerCase();
    final style = mentionStyle ?? linkStyle;

    if (lower.startsWith('npub1') || lower.startsWith('nprofile1')) {
      final hexPubkey = npubToHexOrNull(normalized);
      if (hexPubkey == null || hexPubkey.length != 64) {
        return TextSpan(text: nostrId, style: style);
      }
      return _buildProfileReferenceSpan(hexPubkey, style);
    }

    if (lower.startsWith('note1') ||
        lower.startsWith('nevent1') ||
        lower.startsWith('naddr1')) {
      return _buildVideoReferenceSpan(
        routeReference: _normalizeVideoRouteReference(normalized),
        originalReference: nostrId,
      );
    }

    return TextSpan(text: nostrId, style: style);
  }

  TextSpan _buildHexReferenceSpan(String hexReference, int start) {
    if (_hexReferenceLooksLikeProfile(start)) {
      return _buildProfileReferenceSpan(
        hexReference,
        mentionStyle ?? linkStyle,
      );
    }

    return _buildVideoReferenceSpan(
      routeReference: hexReference,
      originalReference: hexReference,
    );
  }

  TextSpan _buildProfileReferenceSpan(String hexPubkey, TextStyle style) {
    final label = profileLabelForHex?.call(hexPubkey) ?? hexPubkey;
    final displayText = label.startsWith('@') ? label : '@$label';
    return TextSpan(
      text: displayText,
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () => onProfileTap?.call(hexPubkey),
    );
  }

  TextSpan _buildVideoReferenceSpan({
    required String routeReference,
    required String originalReference,
  }) => TextSpan(
    text: videoLabel ?? originalReference,
    style: linkStyle,
    recognizer: TapGestureRecognizer()
      ..onTap = () => onVideoTap?.call(routeReference),
  );

  TextSpan _buildPlainMentionSpan(String username) => TextSpan(
    text: '@$username',
    style: mentionStyle ?? linkStyle,
    recognizer: TapGestureRecognizer()
      ..onTap = () => onMentionTap?.call(username),
  );

  bool _hexReferenceLooksLikeProfile(int start) {
    final prefixStart = start >= 32 ? start - 32 : 0;
    final prefix = text.substring(prefixStart, start).toLowerCase();
    return RegExp(
      r'(profile|pubkey|public key|author|user)\s*:?\s*$',
    ).hasMatch(prefix);
  }

  String _normalizeVideoRouteReference(String reference) {
    final normalized = _stripNostrScheme(reference);
    final lower = normalized.toLowerCase();

    if (lower.startsWith('note1')) {
      try {
        final decoded = Nip19.decode(normalized);
        if (decoded.length == 64) return decoded;
      } catch (_) {
        return normalized;
      }
    }

    if (lower.startsWith('nevent1')) {
      try {
        final decoded = NIP19Tlv.decodeNevent(normalized);
        final id = decoded?.id;
        if (id != null && id.isNotEmpty) return id;
      } catch (_) {
        return normalized;
      }
    }

    return normalized;
  }

  String _stripNostrScheme(String reference) =>
      reference.replaceFirst(RegExp('^nostr:', caseSensitive: false), '');

  String _trimTrailingUrlPunctuation(String url) {
    var end = url.length;
    while (end > 0 && _trailingUrlPunctuation.contains(url[end - 1])) {
      end--;
    }
    return url.substring(0, end);
  }
}

/// `#tag` + More control aligned with [HashtagFeedScreen] app bar actions.
class _HashtagWithMoreButton extends ConsumerWidget {
  const _HashtagWithMoreButton({
    required this.hashtag,
    required this.labelStyle,
    required this.onTagTap,
    this.onVideoStateChange,
  });

  final String hashtag;
  final TextStyle labelStyle;
  final VoidCallback onTagTap;
  final VoidCallback? onVideoStateChange;

  static const DiVineAppBarStyle _appBarActionStyle =
      DiVineAppBarStyle.defaultStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTagTap,
          child: Text(
            '#$hashtag',
            style: labelStyle,
          ),
        ),
        const SizedBox(width: 2),
        DiVineAppBarIconButton(
          icon: SvgIconSource(DivineIconName.dotsThree.assetPath),
          onPressed: () {
            onVideoStateChange?.call();
            showHashtagMoreMenu(context, ref, hashtag: hashtag);
          },
          tooltip: l10n.hashtagOptionsMoreTooltip,
          semanticLabel: l10n.hashtagOptionsMoreTooltip,
          backgroundColor: _appBarActionStyle.iconButtonBackgroundColor,
          borderSide: _appBarActionStyle.iconButtonBorderSide,
          iconColor: _appBarActionStyle.iconColor,
          size: _appBarActionStyle.iconButtonSize,
          iconSize: _appBarActionStyle.iconSize,
          borderRadius: _appBarActionStyle.iconButtonBorderRadius,
        ),
      ],
    );
  }
}
