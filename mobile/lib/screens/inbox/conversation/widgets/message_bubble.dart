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
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:url_launcher/url_launcher.dart';

final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

/// Matches `divine.video/video/{stableId}` URLs in message text.
///
/// The stableId capture group accepts hex event IDs (64 chars) and d-tags
/// (UUIDs, alphanumeric strings). Only word characters and hyphens are
/// matched so trailing punctuation (`.`, `,`, `)`) and query strings
/// (`?q=1`) are excluded.
final divineVideoUrlRegex = RegExp(
  r'https?://(?:www\.)?divine\.video/video/([\w-]+)',
  caseSensitive: false,
);

/// Returns the full divine.video URL contained in [content], or null if
/// the message body doesn't include one. Used by the conversation
/// long-press handler to surface a "Copy video URL" action.
String? tryExtractDivineVideoUrl(String content) =>
    divineVideoUrlRegex.firstMatch(content)?.group(0);

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
    final videoMatch = divineVideoUrlRegex.firstMatch(message);
    final videoStableId = videoMatch?.group(1);

    // Text following the video URL, if any. Anything BEFORE the URL is
    // intentionally dropped — the shared-video title from the message
    // body now lives inside the video card's overlay footer instead.
    final String? textAfterUrl;
    if (videoMatch != null) {
      final after = message.substring(videoMatch.end).trim();
      textAfterUrl = after.isEmpty ? null : after;
    } else {
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
          hint: isSent ? 'Sent message' : 'Received message',
          onLongPressHint: onLongPress != null ? 'Message actions' : null,
          child: GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.75,
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
                    // Title that travels in the share message body is
                    // suppressed — the video card now renders it inside
                    // an overlay footer on the thumbnail itself.
                    _VideoLinkPreview(
                      videoStableId: videoStableId,
                      isSent: isSent,
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
                    _MessageText(message: message, isSent: isSent),
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
    return ClickableHashtagText(
      text: message,
      style: defaultStyle,
      hashtagStyle: referenceStyle,
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
  const _VideoLinkPreview({
    required this.videoStableId,
    required this.isSent,
  });

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
        width: 248,
        height: 350,
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
          width: 248,
          height: 350,
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
                              '${StringUtils.formatCompactNumber(loops)} loops',
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
