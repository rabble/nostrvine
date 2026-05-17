// ABOUTME: Chat message bubble widget for sent and received messages.
// ABOUTME: Supports message grouping with variable border radius,
// ABOUTME: conditional timestamp display, clickable URLs, long-press actions,
// ABOUTME: and inline video preview cards for divine.video links.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide AspectRatio, LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:openvine/screens/inbox/conversation/widgets/video_link_preview_cubit.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/utils/divine_video_url.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:url_launcher/url_launcher.dart';

final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

/// Matches a single line whose entire content is a straight-quoted
/// string — the shape `VideoSharingService` uses to embed the title in
/// the share-message body (`"<title>"`). The bubble drops this line so
/// the title isn't duplicated alongside the overlay-footer rendering.
final _quotedTitleRegex = RegExp(r'^".*"$');

/// Width of the video share card thumbnail (also used to cap the
/// surrounding bubble's max width so the bubble doesn't grow wider
/// than the card when a personal note wraps below it).
const double _videoCardWidth = 248;

/// Height of the video share card thumbnail.
const double _videoCardHeight = 350;

/// A single chat message bubble.
///
/// Sent messages (right-aligned): primaryAccessible background.
/// Received messages (left-aligned): surfaceContainer background.
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

  @override
  Widget build(BuildContext context) {
    // NIP-17 rumor bodies (and any sender-controlled text reaching the
    // app via JSON `\uXXXX` escapes) can carry unpaired UTF-16
    // surrogates that crash Flutter's text renderer. Sanitize once at
    // the top so every downstream substring / split / Text widget sees
    // well-formed input.
    final safeMessage = StringUtils.sanitizeUtf16(message);
    final videoMatch = divineVideoUrlRegex.firstMatch(safeMessage);
    final videoStableId = videoMatch?.group(1);

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
      final after = safeMessage.substring(videoMatch.end).trim();
      textAfterUrl = after.isEmpty ? null : after;

      final beforeLines = safeMessage
          .substring(0, videoMatch.start)
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .where((line) => !_quotedTitleRegex.hasMatch(line))
          .toList();
      personalMessage = beforeLines.isEmpty ? null : beforeLines.join('\n');
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
              // Video bubbles use symmetric 16 px padding so the thumbnail
              // sits in an even frame; text bubbles keep the tighter
              // vertical rhythm (12) for compact reading flow.
              padding: hasVideo
                  ? const EdgeInsets.all(16)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSent
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
                      isSent: isSent,
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
                        ),
                      ),
                    if (textAfterUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _MessageText(
                          message: textAfterUrl,
                          isSent: isSent,
                        ),
                      ),
                  ] else
                    _MessageText(message: safeMessage, isSent: isSent),
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

/// Renders message text with clickable URLs and Nostr references.
class _MessageText extends StatelessWidget {
  const _MessageText({required this.message, required this.isSent});

  final String message;
  final bool isSent;

  @override
  Widget build(BuildContext context) {
    final defaultStyle = VineTheme.bodyMediumFont();
    // Sent bubbles have a primaryAccessible background → use white for
    // contrast. Received bubbles use surfaceContainer → primary green
    // reads cleanly there.
    final linkColor = isSent ? VineTheme.whiteText : VineTheme.primary;
    final referenceStyle = defaultStyle.copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );
    return LinkifiedText(
      text: message,
      style: defaultStyle,
      linkStyle: referenceStyle,
      mentionStyle: referenceStyle,
      onUrlTap: (link) => _openLink(context, link),
    );
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
  const _VideoLinkPreview({required this.videoStableId, required this.isSent});

  final String videoStableId;
  final bool isSent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider(
      create: (_) => VideoLinkPreviewCubit(
        videoStableId: videoStableId,
        videoEventService: ref.read(videoEventServiceProvider),
        nostrClient: ref.read(nostrServiceProvider),
      ),
      child: BlocBuilder<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        builder: (context, state) => switch (state) {
          VideoLinkPreviewLoading() => _buildLoadingPlaceholder(),
          VideoLinkPreviewNotFound() => _MessageText(
            message: 'https://divine.video/video/$videoStableId',
            isSent: isSent,
          ),
          VideoLinkPreviewResolved(:final video) => _VideoCard(video: video),
        },
      ),
    );
  }

  static Widget _buildLoadingPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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

/// Tappable 248×350 card showing a video thumbnail with the title and loop
/// count rendered inside a gradient overlay footer. Mirrors the
/// `part/video thumbnail` Figma component used elsewhere in the app.
class _VideoCard extends ConsumerWidget {
  const _VideoCard({required this.video});

  final VideoEvent video;

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
      onTap: () => context.push(VideoDetailScreen.pathForId(video.id)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
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
