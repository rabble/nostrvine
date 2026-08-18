import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

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

/// Builds linkified [TextSpan]s without owning navigation or data lookup.
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
    this.profilePubkeyForMention,
    this.videoLabel,
    this.allowWidgetSpans = true,
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

  /// Resolves a plain typed @mention to a hex public key when the caller has
  /// surrounding event metadata that identifies the mentioned user.
  final String? Function(String username)? profilePubkeyForMention;

  /// Display label for video/event references.
  final String? videoLabel;

  /// Whether plain runs may be split into non-text spans — today, the
  /// brand-green heart.
  ///
  /// Selectable text seeds its editing controller from the span plain text,
  /// where a [WidgetSpan] contributes U+FFFC, so a copied run silently loses
  /// the character. Selectable callers pass false to keep copied text intact.
  final bool allowWidgetSpans;

  /// Builds spans preserving the token precedence from [LinkifiedText].
  ///
  /// Unpaired UTF-16 surrogates are normalized here rather than at each
  /// caller. Flutter's paragraph builder throws on them during layout — a
  /// crash, not a rendering glitch — and they reach spans from two independent
  /// directions: [text] itself, and the labels injected for profile
  /// references. This is the one point every span passes through, so guarding
  /// it covers both. Sanitizing is code-unit-for-code-unit, so match offsets
  /// stay valid.
  List<InlineSpan> build() {
    final safeText = sanitizeUtf16(text);
    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in _combinedRegex.allMatches(safeText)) {
      if (match.start > lastEnd) {
        spans.addAll(_plainSpans(safeText.substring(lastEnd, match.start)));
      }

      final matchedUrl = match.group(1);
      final hashtag = match.group(2);
      final nostrId = match.group(3);
      final hexReference = match.group(4);
      final plainMention = match.group(5);

      if (matchedUrl != null) {
        spans.addAll(_buildUrlSpans(matchedUrl));
      } else if (hashtag != null) {
        spans.add(_buildHashtagSpan(hashtag));
      } else if (nostrId != null) {
        spans.add(_buildNostrReferenceSpan(nostrId));
      } else if (hexReference != null) {
        spans.add(_buildHexReferenceSpan(hexReference, match.start));
      } else if (plainMention != null) {
        spans.add(_buildPlainMentionSpan(plainMention));
      }

      lastEnd = match.end;
    }

    if (lastEnd < safeText.length) {
      spans.addAll(_plainSpans(safeText.substring(lastEnd)));
    }

    if (spans.isEmpty) return _plainSpans(safeText);
    return spans;
  }

  /// Plain runs are split on the green heart so Divine paints it in the
  /// brand green rather than the platform emoji font's own green — unless
  /// [allowWidgetSpans] is false, for surfaces where a widget span cannot
  /// survive, such as selectable text.
  List<InlineSpan> _plainSpans(String value) {
    if (!allowWidgetSpans) return [TextSpan(text: value, style: defaultStyle)];
    return divineHeartSpans(value, style: defaultStyle);
  }

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
      if (trailingText.isNotEmpty) ..._plainSpans(trailingText),
    ];
  }

  TextSpan _buildHashtagSpan(String hashtag) => TextSpan(
    text: '#$hashtag',
    style: linkStyle,
    recognizer: TapGestureRecognizer()
      ..onTap = () => onHashtagTap?.call(hashtag),
  );

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
    // Resolved from profile metadata, so it does not come through the
    // sanitized source text and needs its own pass (see [build]).
    final label = sanitizeUtf16(
      profileLabelForHex?.call(hexPubkey) ?? hexPubkey,
    );
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
      ..onTap = () {
        final hexPubkey = profilePubkeyForMention?.call(username);
        if (hexPubkey != null) {
          onProfileTap?.call(hexPubkey);
        } else {
          onMentionTap?.call(username);
        }
      },
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
