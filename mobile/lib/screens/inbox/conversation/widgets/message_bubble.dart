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
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:openvine/screens/inbox/conversation/widgets/video_link_preview_cubit.dart';
import 'package:openvine/screens/video_detail_screen.dart';
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
final _divineVideoUrlRegex = RegExp(
  r'https?://(?:www\.)?divine\.video/video/([\w-]+)',
  caseSensitive: false,
);

/// A single chat message bubble.
///
/// Sent messages (right-aligned): surfaceContainer background.
/// Received messages (left-aligned): neutral10 background.
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
    final videoMatch = _divineVideoUrlRegex.firstMatch(message);
    final videoStableId = videoMatch?.group(1);

    // Text surrounding the video URL (before / after), if any.
    final String? textBeforeUrl;
    final String? textAfterUrl;
    if (videoMatch != null) {
      final before = message.substring(0, videoMatch.start).trim();
      final after = message.substring(videoMatch.end).trim();
      textBeforeUrl = before.isEmpty ? null : before;
      textAfterUrl = after.isEmpty ? null : after;
    } else {
      textBeforeUrl = null;
      textAfterUrl = null;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: isFirstInGroup ? 8 : 2,
        bottom: isLastInGroup ? 8 : 2,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSent
                    ? VineTheme.surfaceContainer
                    : VineTheme.neutral10,
                borderRadius: _borderRadius,
              ),
              child: Column(
                crossAxisAlignment: isSent
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (isFirstInGroup)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        timestamp,
                        style: VineTheme.labelSmallFont(
                          color: VineTheme.onSurfaceMuted,
                        ),
                      ),
                    ),
                  if (videoStableId != null) ...[
                    if (textBeforeUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MessageText(message: textBeforeUrl),
                      ),
                    _VideoLinkPreview(videoStableId: videoStableId),
                    if (textAfterUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _MessageText(message: textAfterUrl),
                      ),
                  ] else
                    _MessageText(message: message),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BorderRadius get _borderRadius {
    if (!isLastInGroup) {
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
  const _MessageText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final defaultStyle = VineTheme.bodyMediumFont();
    final referenceStyle = defaultStyle.copyWith(
      color: VineTheme.info,
      decoration: TextDecoration.underline,
      decorationColor: VineTheme.info,
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
  const _VideoLinkPreview({required this.videoStableId});

  final String videoStableId;

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
        height: 180,
        width: double.infinity,
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

/// Tappable card showing a video thumbnail and title.
class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(VideoDetailScreen.pathForId(video.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: VideoThumbnailWidget(video: video),
            ),
          ),
          if (video.title != null && video.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                video.title!,
                style: VineTheme.labelLargeFont(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
