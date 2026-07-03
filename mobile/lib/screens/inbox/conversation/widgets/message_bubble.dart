// ABOUTME: Chat message bubble widget for sent and received messages.
// ABOUTME: Supports message grouping with variable border radius,
// ABOUTME: conditional timestamp display, clickable URLs, long-press actions,
// ABOUTME: and inline video preview cards for divine.video links.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide AspectRatio, LogCategory;
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/inbox/conversation/widgets/video_link_preview_cubit.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/utils/divine_video_url.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_support.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/markdown/markdown.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:url_launcher/url_launcher.dart';

final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

/// Matches a single line whose entire content is a straight-quoted
/// string — the shape `VideoSharingService` uses to embed the title in
/// the share-message body (`"<title>"`). The bubble drops this line so
/// the title isn't duplicated alongside the overlay-footer rendering.
final _quotedTitleRegex = RegExp(r'^".*"$');

/// Matches a line that is just a NIP-21 `nostr:` citation (or bare entity).
/// The share body carries a `nostr:naddr…`/`nevent…` reference for other
/// clients to resolve, but in-app it duplicates the tappable video card, so
/// the bubble drops it rather than rendering a redundant "View video" link.
final _nostrRefLineRegex = RegExp(
  r'^(?:nostr:)?(?:naddr|nevent|note|npub|nprofile)1[0-9a-z]+$',
  caseSensitive: false,
);

/// Width of the video share card thumbnail (also used to cap the
/// surrounding bubble's max width so the bubble doesn't grow wider
/// than the card when a personal note wraps below it).
const double _videoCardWidth = 248;

/// Height of the video share card thumbnail.
const double _videoCardHeight = 350;

/// Corner radius of the video share card thumbnail across all states
/// (resolved, loading, unavailable). Matches the Figma
/// `part/video thumbnail` component's radius/16.
const double _videoCardRadius = 16;

/// A single chat message bubble.
///
/// Text bubbles — sent (right-aligned): primaryAccessible background;
/// received (left-aligned): surfaceContainer background. Shared-video
/// bubbles use a neutral dark frame (neutral10) in both directions so the
/// thumbnail reads as a media card, matching the Figma
/// `part/video thumbnail` share bubble.
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
    this.onDoubleTap,
    this.deliveryStatus = DmDeliveryStatus.delivered,
    this.dmReplyContext,
    this.sharedVideoRef,
    this.quotedVideoRef,
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

  /// Called when the user double-taps the bubble. Wired to double-tap-to-like,
  /// which adds a ❤️ reaction to the message. Null disables double-tap on the
  /// bubble (e.g. failed own sends). It is also suppressed internally on
  /// bubbles whose dominant content is itself a tap target (shared-video card,
  /// quoted-video reply) so the ancestor double-tap recognizer can't delay
  /// tap-to-open — see the wiring below. Screen readers never reach this —
  /// double-tap is the AT activation gesture — so the long-press picker stays
  /// the a11y path.
  final VoidCallback? onDoubleTap;

  /// Per-bubble delivery state. Only rendered for sent messages; received
  /// bubbles ignore it. Defaults to [DmDeliveryStatus.delivered] so test
  /// fixtures and call sites that don't track outgoing-queue state work
  /// without churn.
  final DmDeliveryStatus deliveryStatus;

  /// Context for the in-player reply/reaction bar, used when this bubble's
  /// shared reel is tapped open. Null in non-DM call sites / tests.
  final DmReplyContext? dmReplyContext;

  /// Structured q-tag video reference parsed from the DM rumor, when present.
  /// Drives the message's OWN full share card. Mutually exclusive with
  /// [quotedVideoRef] — the call site passes one or the other.
  final DmSharedVideoRef? sharedVideoRef;

  /// Structured reference to the video this message *replies to*, when the
  /// message is a reply to a shared-reel DM. Renders a compact WhatsApp-style
  /// quoted preview above the reply text (distinct from the full [sharedVideoRef]
  /// card). Null for non-reply messages.
  final DmSharedVideoRef? quotedVideoRef;

  @override
  Widget build(BuildContext context) {
    // NIP-17 rumor bodies (and any sender-controlled text reaching the
    // app via JSON `\uXXXX` escapes) can carry unpaired UTF-16
    // surrogates that crash Flutter's text renderer. Sanitize once at
    // the top so every downstream substring / split / Text widget sees
    // well-formed input.
    final safeMessage = StringUtils.sanitizeUtf16(message);
    final videoMatch = divineVideoUrlRegex.firstMatch(safeMessage);
    final structuredVideo = _videoTargetFromRef(sharedVideoRef);
    final videoStableId = videoMatch?.group(1) ?? structuredVideo?.stableId;
    final videoAuthorPubkey = structuredVideo?.authorPubkey;
    final videoKind = structuredVideo?.videoKind;

    // Slice the message body around the video URL.
    //
    // The share-message template emitted by VideoSharingService is
    //   [optional personal note]
    //   <blank line>
    //   "<video title>"
    //   <blank line>
    //   <URL>
    //   [optional trailing text]
    //
    // The quoted-title line duplicates what the video card's overlay
    // footer already shows, so it's stripped. Everything else before
    // the URL is treated as the user's personal note and rendered
    // below the thumbnail. Text after the URL is preserved as-is.
    final String? personalMessage;
    final String? textAfterUrl;
    if (videoMatch != null) {
      // Drop the machine-readable `nostr:` citation line (kept on the wire for
      // other clients) so it doesn't render as a redundant "View video" link
      // beside the tappable card.
      final afterLines = safeMessage
          .substring(videoMatch.end)
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .where((line) => !_nostrRefLineRegex.hasMatch(line))
          .toList();
      textAfterUrl = afterLines.isEmpty ? null : afterLines.join('\n');

      final beforeLines = safeMessage
          .substring(0, videoMatch.start)
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .where((line) => !_quotedTitleRegex.hasMatch(line))
          .where((line) => !_nostrRefLineRegex.hasMatch(line))
          .toList();
      personalMessage = beforeLines.isEmpty ? null : beforeLines.join('\n');
    } else if (structuredVideo != null) {
      final lines = safeMessage
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .where((line) => !_quotedTitleRegex.hasMatch(line))
          .where((line) => !_nostrRefLineRegex.hasMatch(line))
          .toList();
      personalMessage = lines.isEmpty ? null : lines.join('\n');
      textAfterUrl = null;
    } else {
      personalMessage = null;
      textAfterUrl = null;
    }

    // Video shares are always rendered as standalone blocks: the
    // thumbnail is too prominent to share a tail with an adjacent text
    // bubble from the same sender. Force first-and-last-in-group so
    // they get their own timestamp header, the tail corner on the
    // sender's side, and the full 8 px outer padding above and below.
    final hasVideo = videoStableId != null;
    final effectiveIsFirstInGroup = hasVideo || isFirstInGroup;
    final effectiveIsLastInGroup = hasVideo || isLastInGroup;

    // A reply that references a video (but doesn't itself render a full card)
    // shows a compact quoted preview above its text. Strip the trailing
    // machine-readable `nostr:` citation line the reply carries on the wire so
    // only the user's comment renders below the quote.
    final hasQuotedVideo = quotedVideoRef != null && !hasVideo;
    final quotedReplyText = hasQuotedVideo
        ? safeMessage
              .split('\n')
              .where((line) => !_nostrRefLineRegex.hasMatch(line.trim()))
              .join('\n')
              .trim()
        : safeMessage;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: effectiveIsFirstInGroup ? 8 : 2,
        bottom: effectiveIsLastInGroup ? 8 : 2,
      ),
      child: Align(
        alignment: isSent
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Semantics(
          hint: isSent
              ? context.l10n.dmMessageBubbleSentHint
              : context.l10n.dmMessageBubbleReceivedHint,
          onLongPressHint: onLongPress != null
              ? context.l10n.dmMessageBubbleLongPressHint
              : null,
          child: GestureDetector(
            onLongPress: onLongPress,
            // Suppress double-tap-to-like on bubbles whose dominant content is
            // itself a tap target — the shared-video card and the quoted-video
            // reply both open the reel on tap. An ancestor onDoubleTap makes
            // its DoubleTapGestureRecognizer hold the gesture arena for
            // ~kDoubleTapTimeout after the first tap, so the inner onTap only
            // fires once that window elapses (~300 ms delay to tap-to-open).
            // Text bubbles keep double-tap-to-like.
            onDoubleTap: hasVideo || hasQuotedVideo ? null : onDoubleTap,
            child: Container(
              // Video bubbles cap their max width at the thumbnail's
              // own width (248) plus the symmetric 16 px padding so the
              // bubble doesn't grow wider than the card when a personal
              // message wraps below it. Text-only bubbles stay at the
              // chat-typical 75 % of screen width.
              constraints: BoxConstraints(
                maxWidth: hasVideo
                    ? _videoCardWidth + 32
                    : MediaQuery.sizeOf(context).width * 0.75,
              ),
              // Both text and video bubbles use 16 px horizontal / 12 px
              // vertical padding (Figma spacing/16 + spacing/12) so the
              // thumbnail and text sit in the same frame rhythm.
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // Shared-video bubbles sit on a neutral dark frame
                // (neutral10, #1B1C1C) in both directions so the thumbnail
                // reads as a media card rather than a bright accent pill —
                // matching the Figma `part/video thumbnail` share bubble.
                // Text bubbles keep the sent/received accent split.
                color: hasVideo
                    ? VineTheme.neutral10
                    : isSent
                    ? VineTheme.primaryAccessible
                    : VineTheme.surfaceContainer,
                borderRadius: _borderRadiusFor(effectiveIsLastInGroup),
              ),
              child: Column(
                crossAxisAlignment: isSent
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (effectiveIsFirstInGroup)
                    Padding(
                      // Video messages need a bigger breath between the
                      // date header and the thumbnail; text messages
                      // keep the tighter 4 px rhythm.
                      padding: EdgeInsets.only(bottom: hasVideo ? 12 : 4),
                      child: Text(
                        timestamp,
                        style: VineTheme.labelSmallFont(
                          color: VineTheme.onSurfaceMuted,
                        ),
                      ),
                    ),
                  if (videoStableId != null) ...[
                    _VideoLinkPreview(
                      videoStableId: videoStableId,
                      authorPubkey: videoAuthorPubkey,
                      videoKind: videoKind,
                      isSent: isSent,
                      dmReplyContext: dmReplyContext,
                    ),
                    // Optional personal note (text before the URL minus
                    // the quoted title) sits directly under the
                    // thumbnail, inside the same bubble pill.
                    if (personalMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _MessageText(
                          message: personalMessage,
                          isSent: isSent,
                          dmReplyContext: dmReplyContext,
                        ),
                      ),
                    if (textAfterUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _MessageText(
                          message: textAfterUrl,
                          isSent: isSent,
                          dmReplyContext: dmReplyContext,
                        ),
                      ),
                  ] else ...[
                    if (hasQuotedVideo)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: quotedReplyText.isEmpty ? 0 : 6,
                        ),
                        child: _QuotedVideoPreview(
                          quotedVideoRef: quotedVideoRef!,
                          isSent: isSent,
                          dmReplyContext: dmReplyContext,
                        ),
                      ),
                    if (quotedReplyText.isNotEmpty)
                      _MessageText(
                        message: quotedReplyText,
                        isSent: isSent,
                        dmReplyContext: dmReplyContext,
                      ),
                  ],
                  if (isSent && deliveryStatus != DmDeliveryStatus.delivered)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _DeliveryStatusIndicator(status: deliveryStatus),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BorderRadius _borderRadiusFor(bool lastInGroup) {
    if (!lastInGroup) {
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

class _SharedVideoTarget {
  const _SharedVideoTarget({
    required this.stableId,
    required this.videoKind,
    this.authorPubkey,
  });

  final String stableId;
  final int videoKind;
  final String? authorPubkey;
}

_SharedVideoTarget? _videoTargetFromRef(DmSharedVideoRef? ref) {
  if (ref == null) return null;
  if (!ref.isAddressable) {
    return _SharedVideoTarget(
      stableId: ref.coordinateOrId,
      videoKind: ref.videoKind.kind,
      authorPubkey: ref.authorPubkey,
    );
  }

  final coordParts = ref.coordinateOrId.split(':');
  if (coordParts.length < 3) return null;
  final kind = int.tryParse(coordParts[0]);
  final author = coordParts[1];
  final dTag = coordParts.sublist(2).join(':');
  if (kind == null || dTag.isEmpty) return null;

  return _SharedVideoTarget(
    stableId: dTag,
    videoKind: kind,
    authorPubkey: author.isNotEmpty ? author : ref.authorPubkey,
  );
}

/// Trusted domains that open without an external-link warning.
const _trustedDomains = {
  'divine.video',
  'invite.divine.video',
  'login.divine.video',
  'media.divine.video',
  'relay.divine.video',
  'cdn.divine.video',
  'stream.divine.video',
};

/// Returns `true` if [host] is a trusted Divine domain.
bool _isTrustedDomain(String host) {
  final lower = host.toLowerCase();
  return _trustedDomains.any((d) => lower == d || lower.endsWith('.$d'));
}

/// Renders message text with inline markdown (bold / italic / strike /
/// inline code / `[label](url)`) plus clickable URLs and Nostr
/// references.
///
/// Markdown parsing produces an AST; plain leaves are delegated to
/// [LinkifiedTextSpanBuilder] so URLs / @mentions / #hashtags / nostr
/// references inside, e.g., a `**bold**` run remain tappable.
class _MessageText extends ConsumerStatefulWidget {
  const _MessageText({
    required this.message,
    required this.isSent,
    this.dmReplyContext,
  });

  final String message;
  final bool isSent;
  final DmReplyContext? dmReplyContext;

  @override
  ConsumerState<_MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends ConsumerState<_MessageText> {
  List<InlineSpan> _currentSpans = const [];

  @override
  Widget build(BuildContext context) {
    final defaultStyle = VineTheme.bodyMediumFont();
    // Sent bubbles have a primaryAccessible background → use white for
    // contrast. Received bubbles use surfaceContainer → primary green
    // reads cleanly there.
    final linkColor = widget.isSent ? VineTheme.whiteText : VineTheme.primary;
    final referenceStyle = defaultStyle.copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );
    // Translucent white overlay reads on both bubble colors without
    // needing a per-side palette swap.
    final codeBackground = VineTheme.whiteText.withValues(
      alpha: widget.isSent ? 0.18 : 0.10,
    );
    final codeStyle = VineTheme.codeFont(color: defaultStyle.color!);

    final ast = const InlineMarkdownParser().parse(widget.message);
    final builder = MarkdownTextSpanBuilder(
      defaultStyle: defaultStyle,
      codeStyle: codeStyle,
      codeBackgroundColor: codeBackground,
      linkStyle: referenceStyle,
      buildPlainSpans: (text, effectiveStyle) =>
          _buildLinkifiedPlain(text, effectiveStyle, referenceStyle),
      onLinkTap: (rawUrl) => _openLink(context, rawUrl),
    );
    final spans = builder.build(ast);
    _replaceCurrentSpans(spans);

    if (spans.isEmpty) {
      return Text(widget.message, style: defaultStyle);
    }
    return Text.rich(TextSpan(children: spans));
  }

  /// Delegates plain markdown leaves to [LinkifiedTextSpanBuilder] so
  /// the linkifier's URL / @mention / #hashtag / nostr-ref pipeline
  /// runs inside markdown wrappers.
  List<InlineSpan> _buildLinkifiedPlain(
    String text,
    TextStyle plainStyle,
    TextStyle linkStyle,
  ) {
    if (text.isEmpty) return const [];
    // Apply the surrounding emphasis to linked / mentioned tokens too
    // so `**check @alice**` renders the mention in bold + reference
    // color.
    final emphasizedLink = linkStyle.copyWith(
      fontWeight: plainStyle.fontWeight,
      fontStyle: plainStyle.fontStyle,
      decoration:
          plainStyle.decoration == null ||
              plainStyle.decoration == TextDecoration.none
          ? linkStyle.decoration
          : TextDecoration.combine([
              linkStyle.decoration ?? TextDecoration.none,
              plainStyle.decoration!,
            ]),
    );
    return LinkifiedTextSpanBuilder(
      text: text,
      defaultStyle: plainStyle,
      linkStyle: emphasizedLink,
      mentionStyle: emphasizedLink,
      videoLabel: Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      )?.clickableTextViewVideoLink,
      profileLabelForHex: _profileDisplayText,
      onHashtagTap: _navigateToHashtag,
      onProfileTap: _navigateToProfile,
      onVideoTap: _navigateToVideo,
      onMentionTap: _navigateToSearch,
      onUrlTap: (rawUrl) => _openLink(context, rawUrl),
    ).build();
  }

  String _profileDisplayText(String hexPubkey) {
    return LinkifiedTextSupport.profileDisplayText(ref, hexPubkey);
  }

  void _navigateToHashtag(String hashtag) {
    context.push(HashtagScreenRouter.pathForTag(hashtag));
  }

  void _navigateToProfile(String hexPubkey) {
    context.pushOtherProfile(hexPubkey);
  }

  void _navigateToVideo(String routeReference) {
    final dmReplyContext = widget.dmReplyContext;
    context.push(
      VideoDetailScreen.pathForId(routeReference),
      extra: dmReplyContext != null
          ? VideoDetailRouteExtra(dmReplyContext: dmReplyContext)
          : null,
    );
  }

  void _navigateToSearch(String username) {
    context.push(
      SearchResultsPage.pathForQuery(username, requestFocusOnMount: false),
    );
  }

  void _replaceCurrentSpans(List<InlineSpan> spans) {
    final previousSpans = _currentSpans;
    _currentSpans = spans;
    LinkifiedTextSupport.disposeSpans(previousSpans);
  }

  @override
  void dispose() {
    LinkifiedTextSupport.disposeSpans(_currentSpans);
    super.dispose();
  }

  Future<void> _openLink(BuildContext context, String link) async {
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

    final appRoute = divineUrlToPushRoute(uri);
    if (appRoute != null && context.mounted) {
      await context.push(appRoute);
      return;
    }

    // Show a warning for external (non-Divine) URLs.
    if (uri.scheme != 'mailto' && !_isTrustedDomain(uri.host)) {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: VineTheme.cardBackground,
          title: Text(
            ctx.l10n.messageExternalLinkDialogTitle,
            style: VineTheme.titleMediumFont(),
          ),
          content: Text(
            ctx.l10n.messageExternalLinkDialogBody(uri.toString()),
            style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                ctx.l10n.commonCancel,
                style: VineTheme.bodyMediumFont(color: VineTheme.onSurface),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                ctx.l10n.messageExternalLinkDialogOpen,
                style: VineTheme.bodyMediumFont(color: VineTheme.primary),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Inline video preview card for `divine.video/video/{stableId}` links.
///
/// Creates a [VideoLinkPreviewCubit] via [BlocProvider] to resolve the video
/// and renders state via [BlocBuilder]. Falls back to a tappable link when
/// the video cannot be resolved.
class _VideoLinkPreview extends ConsumerWidget {
  const _VideoLinkPreview({
    required this.videoStableId,
    required this.isSent,
    this.authorPubkey,
    this.videoKind,
    this.dmReplyContext,
  });

  final String videoStableId;
  final bool isSent;
  final String? authorPubkey;
  final int? videoKind;
  final DmReplyContext? dmReplyContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider(
      create: (_) => VideoLinkPreviewCubit(
        videoStableId: videoStableId,
        videoEventService: ref.read(videoEventServiceProvider),
        nostrClient: ref.read(nostrServiceProvider),
        authorPubkey: authorPubkey,
        videoKind: videoKind,
      ),
      child: BlocBuilder<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        builder: (context, state) => switch (state) {
          VideoLinkPreviewLoading() => _buildLoadingPlaceholder(),
          VideoLinkPreviewNotFound() => const _VideoUnavailableCard(),
          VideoLinkPreviewResolved(:final video) => _VideoCard(
            video: video,
            dmReplyContext: dmReplyContext,
          ),
        },
      ),
    );
  }

  static Widget _buildLoadingPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_videoCardRadius),
      child: Container(
        width: _videoCardWidth,
        height: _videoCardHeight,
        color: VineTheme.cardBackground,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VineTheme.vineGreen,
            ),
          ),
        ),
      ),
    );
  }
}

/// Thumbnail width of the compact quoted-reply preview.
const double _quotedThumbWidth = 40;

/// Thumbnail height of the compact quoted-reply preview.
const double _quotedThumbHeight = 56;

/// Corner radius of the compact quoted-reply thumbnail.
const double _quotedThumbRadius = 6;

/// Fixed overall width of the compact quoted-reply preview. Pinning it keeps
/// the bubble from reflowing when the cited video resolves out of its loading
/// skeleton — the loading, resolved, and unavailable states all render at this
/// width, so there is no horizontal jump as the reel loads.
const double _quotedPreviewWidth = 200;

/// Diameter of the compact quoted-thumbnail play badge. Smaller than the shared
/// [VideoThumbnailWidget] default so it reads as a neat chip with margin on the
/// 40-wide thumb.
const double _quotedPlayBadgeSize = 22;

/// Play-glyph diameter inside the badge, inset from the badge edge so the
/// triangle keeps visible padding within the chip.
const double _quotedPlayGlyphSize = 11;

/// Compact WhatsApp-style quoted preview of the video a reply references.
///
/// Reuses the [VideoLinkPreviewCubit] resolve harness (cache → relay fetch) so
/// it can render even when the cited video was never seen locally, and swaps
/// the full [_VideoCard] for a small thumbnail + label strip rendered above the
/// reply text.
class _QuotedVideoPreview extends ConsumerWidget {
  const _QuotedVideoPreview({
    required this.quotedVideoRef,
    required this.isSent,
    this.dmReplyContext,
  });

  final DmSharedVideoRef quotedVideoRef;
  final bool isSent;
  final DmReplyContext? dmReplyContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = _videoTargetFromRef(quotedVideoRef);
    if (target == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (_) => VideoLinkPreviewCubit(
        videoStableId: target.stableId,
        videoEventService: ref.read(videoEventServiceProvider),
        nostrClient: ref.read(nostrServiceProvider),
        authorPubkey: target.authorPubkey,
        videoKind: target.videoKind,
      ),
      child: BlocBuilder<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        builder: (context, state) => switch (state) {
          VideoLinkPreviewLoading() => _QuotedVideoLoading(isSent: isSent),
          VideoLinkPreviewNotFound() => _QuotedVideoUnavailable(isSent: isSent),
          VideoLinkPreviewResolved(:final video) => _QuotedVideoCard(
            video: video,
            isSent: isSent,
            dmReplyContext: dmReplyContext,
          ),
        },
      ),
    );
  }
}

/// Accent-bar framed container that gives the quoted preview its WhatsApp-style
/// "reply" affordance, readable on both sent and received bubble colors.
class _QuotedVideoFrame extends StatelessWidget {
  const _QuotedVideoFrame({
    required this.isSent,
    required this.child,
    this.onTap,
    this.semanticLabel,
  });

  final bool isSent;
  final Widget child;
  final VoidCallback? onTap;

  /// Screen-reader label for the tappable affordance. Only used when [onTap]
  /// is non-null (the resolved, openable card).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final accent = isSent ? VineTheme.whiteText : VineTheme.primary;
    final frame = SizedBox(
      width: _quotedPreviewWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.whiteText.withValues(alpha: isSent ? 0.14 : 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Padding(padding: const EdgeInsets.all(6), child: child),
      ),
    );
    if (onTap == null) return frame;
    // Co-locate the button semantics with the tap target so every tappable
    // frame is announced as a button — callers can't forget to wrap it.
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(onTap: onTap, child: frame),
    );
  }
}

/// Loading skeleton for the compact quoted preview. Mirrors the resolved
/// card's thumbnail + two-line label layout so the fixed-width frame reads as
/// content rather than an empty box while the cited reel resolves.
class _QuotedVideoLoading extends StatelessWidget {
  const _QuotedVideoLoading({required this.isSent});

  final bool isSent;

  @override
  Widget build(BuildContext context) {
    return _QuotedVideoFrame(
      isSent: isSent,
      child: const Row(
        spacing: 8,
        children: [
          _QuotedThumbPlaceholder(),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuotedSkeletonBar(widthFactor: 0.85),
                SizedBox(height: 6),
                _QuotedSkeletonBar(widthFactor: 0.5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder sized to the compact thumbnail.
class _QuotedThumbPlaceholder extends StatelessWidget {
  const _QuotedThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _quotedThumbWidth,
      height: _quotedThumbHeight,
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(_quotedThumbRadius),
      ),
    );
  }
}

/// A single rounded skeleton bar for the quoted-preview loading state. The
/// translucent white fill reads on both the sent and received bubble colors.
class _QuotedSkeletonBar extends StatelessWidget {
  const _QuotedSkeletonBar({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: VineTheme.whiteText.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Resolved compact quoted preview: thumbnail + title/author, tappable to open
/// the referenced video.
class _QuotedVideoCard extends ConsumerWidget {
  const _QuotedVideoCard({
    required this.video,
    required this.isSent,
    this.dmReplyContext,
  });

  final VideoEvent video;
  final bool isSent;
  final DmReplyContext? dmReplyContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = video.title;
    final hasTitle = title != null && title.isNotEmpty;
    final profileAsync = ref.watch(userProfileReactiveProvider(video.pubkey));
    final authorName = switch (profileAsync) {
      AsyncData(:final value) when value != null => value.bestDisplayName,
      AsyncData() ||
      AsyncError() => UserProfile.defaultDisplayNameFor(video.pubkey),
      AsyncLoading() => null,
    };
    final primaryColor = isSent ? VineTheme.whiteText : VineTheme.onSurface;
    final secondaryColor = isSent
        ? VineTheme.whiteText.withValues(alpha: 0.7)
        : VineTheme.onSurfaceMuted;
    final primaryLabel = hasTitle ? title : (authorName ?? '');
    final showSecondary =
        hasTitle && authorName != null && authorName.isNotEmpty;

    return _QuotedVideoFrame(
      isSent: isSent,
      semanticLabel: context.l10n.dmMessageBubbleVideoReplyHint,
      onTap: () => context.push(
        VideoDetailScreen.pathForId(video.id),
        extra: VideoDetailRouteExtra(
          initialVideo: video,
          dmReplyContext: dmReplyContext,
        ),
      ),
      child: Row(
        spacing: 8,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_quotedThumbRadius),
            // VideoThumbnailWidget renders an AspectRatio internally, so it
            // must be externally bounded (like the full _VideoCard's SizedBox)
            // — its own width/height params only size the inner image. The
            // compact play badge is overlaid here (rather than via
            // showPlayIcon) so it stays visible on dark thumbnails.
            child: SizedBox(
              width: _quotedThumbWidth,
              height: _quotedThumbHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoThumbnailWidget(video: video),
                  const Center(child: _QuotedPlayBadge()),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.labelSmallFont(color: primaryColor),
                ),
                if (showSecondary)
                  Text(
                    authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.bodySmallFont(color: secondaryColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact play badge centered on the quoted-reply thumbnail. The translucent
/// dark disc reads on light thumbnails; the hairline light ring keeps the chip
/// visible on dark thumbnails, where a translucent-black disc would otherwise
/// vanish into the content.
class _QuotedPlayBadge extends StatelessWidget {
  const _QuotedPlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _quotedPlayBadgeSize,
      height: _quotedPlayBadgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor.withValues(alpha: 0.6),
        shape: BoxShape.circle,
        border: Border.all(
          color: VineTheme.whiteText.withValues(alpha: 0.9),
          width: 1.5,
        ),
      ),
      child: const DivineIcon(
        icon: DivineIconName.play,
        color: VineTheme.whiteText,
        size: _quotedPlayGlyphSize,
      ),
    );
  }
}

/// Compact non-tappable chip shown when the referenced video can't be resolved.
class _QuotedVideoUnavailable extends StatelessWidget {
  const _QuotedVideoUnavailable({required this.isSent});

  final bool isSent;

  @override
  Widget build(BuildContext context) {
    final color = isSent ? VineTheme.whiteText : VineTheme.onSurfaceMuted;
    return _QuotedVideoFrame(
      isSent: isSent,
      child: Row(
        spacing: 8,
        children: [
          DivineIcon(
            icon: DivineIconName.warningCircle,
            color: color,
            size: 16,
          ),
          Expanded(
            child: Text(
              context.l10n.notificationsVideoUnavailable,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.bodySmallFont(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Non-tappable placeholder shown when a shared video can't be resolved
/// (deleted, blocked, or unreachable). Deliberately has no tap target so a
/// dead reel can never open the player or a reply bar.
class _VideoUnavailableCard extends StatelessWidget {
  const _VideoUnavailableCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_videoCardRadius),
      child: Container(
        width: _videoCardWidth,
        height: _videoCardHeight,
        color: VineTheme.cardBackground,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DivineIcon(
              icon: DivineIconName.warningCircle,
              color: VineTheme.onSurfaceMuted,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.notificationsVideoUnavailable,
              style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable 248×350 card showing a video thumbnail with the title and loop
/// count rendered inside a gradient overlay footer. Mirrors the
/// `part/video thumbnail` Figma component used elsewhere in the app.
class _VideoCard extends ConsumerWidget {
  const _VideoCard({required this.video, this.dmReplyContext});

  final VideoEvent video;
  final DmReplyContext? dmReplyContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = video.title;
    final loops = video.totalLoops;
    final hasTitle = title != null && title.isNotEmpty;
    final hasLoops = loops > 0;
    final profileAsync = ref.watch(userProfileReactiveProvider(video.pubkey));
    final authorName = switch (profileAsync) {
      AsyncData(:final value) when value != null => value.bestDisplayName,
      AsyncData() ||
      AsyncError() => UserProfile.defaultDisplayNameFor(video.pubkey),
      AsyncLoading() => null,
    };
    final hasAuthor = authorName != null && authorName.isNotEmpty;
    return GestureDetector(
      onTap: () => context.push(
        VideoDetailScreen.pathForId(video.id),
        extra: VideoDetailRouteExtra(
          initialVideo: video,
          dmReplyContext: dmReplyContext,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_videoCardRadius),
        child: SizedBox(
          width: _videoCardWidth,
          height: _videoCardHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoThumbnailWidget(video: video),
              if (hasAuthor || hasTitle || hasLoops)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    // Soft bottom-of-thumbnail fade matching the home
                    // feed video overlay: transparent → 50 %
                    // VineTheme.backgroundColor. Top padding is
                    // intentionally large so the gradient has room to
                    // ease in over the thumbnail before reaching the
                    // text — without it the fade would only span the
                    // single line of label height and look abrupt.
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          VineTheme.backgroundColor.withValues(alpha: 0),
                          VineTheme.backgroundColor.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasAuthor)
                            Text(
                              authorName,
                              // Mirrors the Explore > New grid creator
                              // style: titleTinyFont (Bricolage Grotesque
                              // 12 px / w800) with a subtle legibility
                              // shadow, no underline.
                              style: VineTheme.titleTinyFont().copyWith(
                                decoration: TextDecoration.none,
                                shadows: const [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                    color: VineTheme.scrim15,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (hasTitle) ...[
                            if (hasAuthor) const SizedBox(height: 4),
                            Text(
                              title,
                              style: VineTheme.labelMediumFont(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (hasLoops) ...[
                            if (hasAuthor || hasTitle)
                              const SizedBox(height: 4),
                            Text(
                              context.l10n.videoFeedLoopCountLine(
                                StringUtils.formatCompactNumber(loops),
                                loops,
                              ),
                              style: VineTheme.bodySmallFont(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small trailing icon at the bottom of a sent bubble that surfaces
/// the row's outgoing-queue status. Rendered only when the row is in a
/// non-delivered state — a fully delivered bubble shows no indicator
/// to keep the chat-typical visual rhythm.
class _DeliveryStatusIndicator extends StatelessWidget {
  const _DeliveryStatusIndicator({required this.status});

  final DmDeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      DmDeliveryStatus.pending => (
        Icons.access_time,
        VineTheme.whiteText.withValues(alpha: 0.7),
        context.l10n.dmStatusPending,
      ),
      DmDeliveryStatus.deliveredSelfFailed => (
        Icons.warning_amber_rounded,
        VineTheme.warning,
        context.l10n.dmStatusDeliveredSelfFailed,
      ),
      DmDeliveryStatus.failed => (
        Icons.error_outline,
        VineTheme.error,
        context.l10n.dmStatusFailed,
      ),
      // Filtered out at the bubble level — included for exhaustiveness.
      DmDeliveryStatus.delivered => (
        Icons.check,
        VineTheme.whiteText.withValues(alpha: 0.7),
        '',
      ),
    };
    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
