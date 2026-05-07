// ABOUTME: Shared UI for showing that a NIP-71 video is a reply.
// ABOUTME: Fetches parent video context and links back to the parent route.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/video_reply_parent_provider.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

enum VideoReplyParentLinkVariant { overlay, metadata }

class VideoReplyParentLink extends ConsumerWidget {
  const VideoReplyParentLink({
    required this.video,
    required this.variant,
    this.onInteracted,
    super.key,
  });

  final VideoEvent video;
  final VideoReplyParentLinkVariant variant;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeId = video.replyRootRouteId;
    if (routeId == null) return const SizedBox.shrink();

    final parent = ref.watch(videoReplyParentProvider(routeId));
    final label = _labelFor(
      parent.when(
        data: (video) => video,
        error: (_, _) => null,
        loading: () => null,
      ),
    );

    return Semantics(
      button: true,
      label: 'Open video this replies to',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onInteracted?.call();
          context.pushWithVideoPause(VideoDetailScreen.pathForId(routeId));
        },
        child: variant == VideoReplyParentLinkVariant.overlay
            ? _OverlayReplyLink(label: label)
            : _MetadataReplyLink(label: label),
      ),
    );
  }

  String _labelFor(VideoEvent? parent) {
    final title = parent?.displayTitle?.trim();
    if (title != null && title.isNotEmpty) return 'Reply to $title';

    final authorName = parent?.authorName?.trim();
    if (authorName != null && authorName.isNotEmpty) {
      return 'Reply to $authorName';
    }

    final content = parent?.displayContent.trim();
    if (content != null && content.isNotEmpty) return 'Reply to $content';

    return 'Reply to video';
  }
}

class _OverlayReplyLink extends StatelessWidget {
  const _OverlayReplyLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.backgroundColor.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: VineTheme.vineGreen.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.reply_rounded,
                color: VineTheme.vineGreen,
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: VineTheme.labelSmallFont().copyWith(
                    shadows: VineTheme.buttonShadows,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetadataReplyLink extends StatelessWidget {
  const _MetadataReplyLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VineTheme.outlineDisabled)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(
              Icons.reply_rounded,
              color: VineTheme.vineGreen,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'In reply to',
                    style: VineTheme.labelMediumFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: VineTheme.titleSmallFont(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right_rounded,
              color: VineTheme.onSurfaceVariant,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
