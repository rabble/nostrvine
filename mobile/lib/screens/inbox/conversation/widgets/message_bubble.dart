// ABOUTME: Chat message bubble widget for sent and received messages.
// ABOUTME: Supports message grouping with variable border radius,
// ABOUTME: conditional timestamp display, clickable URLs, long-press actions,
// ABOUTME: and inline video preview cards for divine.video links.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide AspectRatio, LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:openvine/screens/inbox/conversation/widgets/video_link_preview_cubit.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:url_launcher/url_launcher.dart';

/// Regex to detect linkifiable text in messages.
///
/// Matches (in priority order):
/// 1. Email addresses like `user@example.com`
/// 2. Explicit URLs starting with http:// or https://
/// 3. Bare domains like `google.com` or `sub.example.co.uk/path`
///
/// Bare domains must contain a dot followed by a valid TLD (2+ alpha chars).
/// Matching stops at whitespace or end of string.
final _linkRegex = RegExp(
  r'(?:[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})'
  r'|(?:https?://[^\s]+)'
  r'|(?:(?<![/@\w])(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}(?:[/][^\s]*)?)',
  caseSensitive: false,
);

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

/// Renders message text with clickable URLs and email addresses.
///
/// Links matching [_linkRegex] are styled as underlined links. URLs open in
/// an external browser; email addresses open the default mail client.
/// External (non-Divine) URLs show a confirmation before opening.
/// Non-link text is rendered with the default body medium style.
///
/// Span building and gesture recognisers are created in [initState] (and
/// updated in [didUpdateWidget]) so that they are not re-allocated on every
/// rebuild.
class _MessageText extends StatefulWidget {
  const _MessageText({required this.message});

  final String message;

  @override
  State<_MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends State<_MessageText> {
  final List<TapGestureRecognizer> _recognizers = [];
  bool _hasLinks = false;
  List<TextSpan> _spans = const [];

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(covariant _MessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _rebuild();
    }
  }

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

  void _rebuild() {
    _disposeRecognizers();
    _hasLinks = _linkRegex.hasMatch(widget.message);
    if (_hasLinks) {
      _spans = _buildSpans();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasLinks) {
      return Text(widget.message, style: VineTheme.bodyMediumFont());
    }
    return Text.rich(TextSpan(children: _spans));
  }

  List<TextSpan> _buildSpans() {
    final spans = <TextSpan>[];
    final defaultStyle = VineTheme.bodyMediumFont();
    final linkStyle = defaultStyle.copyWith(
      color: VineTheme.info,
      decoration: TextDecoration.underline,
      decorationColor: VineTheme.info,
    );

    var lastEnd = 0;
    for (final match in _linkRegex.allMatches(widget.message)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: widget.message.substring(lastEnd, match.start),
            style: defaultStyle,
          ),
        );
      }

      final link = match.group(0)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _openLink(link);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: link, style: linkStyle, recognizer: recognizer));

      lastEnd = match.end;
    }

    if (lastEnd < widget.message.length) {
      spans.add(
        TextSpan(text: widget.message.substring(lastEnd), style: defaultStyle),
      );
    }

    return spans;
  }

  Future<void> _openLink(String link) async {
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
            'Open external link?',
            style: VineTheme.titleMediumFont(),
          ),
          content: Text(
            'This link goes to an external site and may not be safe:\n\n'
            '$uri',
            style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: VineTheme.bodyMediumFont(color: VineTheme.onSurface),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Open',
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
