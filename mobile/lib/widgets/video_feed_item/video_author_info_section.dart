// ABOUTME: Shared bottom-left author info / caption / description block.
// ABOUTME: Used by the home feed and the fullscreen video screens.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_follow_button.dart';
import 'package:openvine/widgets/video_reply_parent_link.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// The bottom-left video metadata block: optional inline caption pill,
/// author avatar + name + loop count, optional title and description.
///
/// Visually matches the home feed overlay's Figma spec; reused on the
/// fullscreen video feed (Explore / profile / list deep links) so the
/// metadata container is identical wherever a video plays.
class VideoAuthorInfoSection extends ConsumerWidget {
  const VideoAuthorInfoSection({
    required this.video,
    required this.hasTextContent,
    this.player,
    this.onInteracted,
    super.key,
  });

  final VideoEvent video;
  final bool hasTextContent;

  /// When provided and [VideoEvent.hasSubtitles] is true, the inline
  /// caption pill streams the current cue from the player and renders
  /// it 16 px above the author row.
  final Player? player;

  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileReactiveProvider(video.pubkey)).value;
    final avatarUrl = profile?.picture ?? video.authorAvatar;
    final displayName =
        profile?.bestDisplayName ??
        video.authorName ??
        UserProfile.generatedNameFor(video.pubkey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Caption pill — sits 16 px above the author row, matching Figma
        if (video.hasSubtitles && player != null) ...[
          _InlineCaptionPill(video: video, player: player!),
          const SizedBox(height: 16),
        ],
        if (video.isVideoReply) ...[
          VideoReplyParentLink(
            video: video,
            variant: VideoReplyParentLinkVariant.overlay,
            onInteracted: onInteracted,
          ),
          const SizedBox(height: 8),
        ],
        // Avatar and name row
        Row(
          children: [
            _AuthorAvatar(
              pubkey: video.pubkey,
              avatarUrl: avatarUrl,
              onInteracted: onInteracted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  onInteracted?.call();
                  final npub = normalizeToNpub(video.pubkey);
                  if (npub != null) {
                    context.pushWithVideoPause(
                      OtherProfileScreen.pathForNpub(npub),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      identifier: 'video_author_name',
                      container: true,
                      explicitChildNodes: true,
                      label: context.l10n.videoAuthorSemanticLabel(displayName),
                      child: Text(
                        displayName,
                        style: VineTheme.titleSmallFont(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      context.l10n.videoFeedLoopCountLine(
                        StringUtils.formatCompactNumber(video.totalLoops),
                        video.totalLoops,
                      ),
                      style: VineTheme.labelSmallFont(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Video title and description (caption block)
        if (hasTextContent) ...[
          const SizedBox(height: 2),
          // Title (when present)
          if (video.title != null && video.title!.trim().isNotEmpty)
            Semantics(
              identifier: 'video_title',
              container: true,
              explicitChildNodes: true,
              button: true,
              label: context.l10n.videoOverlayOpenMetadataFromTitle,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  onInteracted?.call();
                  MetadataExpandedSheet.show(context, video);
                },
                child: Text(
                  video.displayTitle!.trim(),
                  style: VineTheme.labelMediumFont().copyWith(
                    shadows: VineTheme.buttonShadows,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          // 4 px gap between title and description when both are present
          // (matches the Figma caption block spacing).
          if (video.title != null &&
              video.title!.trim().isNotEmpty &&
              video.content.trim().isNotEmpty)
            const SizedBox(height: 4),
          // Description (only when actual content exists — no title fallback,
          // the title has its own row above).
          if (video.content.trim().isNotEmpty)
            Semantics(
              identifier: 'video_description',
              container: true,
              explicitChildNodes: true,
              button: true,
              label: context.l10n.videoOverlayOpenMetadataFromDescription,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  onInteracted?.call();
                  MetadataExpandedSheet.show(context, video);
                },
                child: ClickableHashtagText(
                  text: video.displayContent.trim(),
                  style: VineTheme.bodySmallFont().copyWith(
                    shadows: VineTheme.buttonShadows,
                  ),
                  hashtagStyle: VineTheme.bodySmallFont().copyWith(
                    shadows: VineTheme.buttonShadows,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.pubkey,
    this.avatarUrl,
    this.onInteracted,
  });

  final String pubkey;
  final String? avatarUrl;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(
            imageUrl: avatarUrl,
            placeholderSeed: pubkey,
            size: 48,
            semanticLabel: context.l10n.videoAuthorAvatarSemanticLabel,
            onTap: () {
              onInteracted?.call();
              final npub = normalizeToNpub(pubkey);
              if (npub != null) {
                context.pushWithVideoPause(
                  OtherProfileScreen.pathForNpub(npub),
                );
              }
            },
          ),
          PositionedDirectional(
            start: 31,
            top: 31,
            child: VideoFollowButton(pubkey: pubkey),
          ),
        ],
      ),
    );
  }
}

/// Streams the player position and renders [SubtitleCuePill] when a cue is
/// active and captions are enabled. Returns [SizedBox.shrink] otherwise.
class _InlineCaptionPill extends ConsumerWidget {
  const _InlineCaptionPill({required this.video, required this.player});

  final VideoEvent video;
  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(subtitleVisibilityProvider);
    if (!visible) return const SizedBox.shrink();

    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, snapshot) {
        final positionMs = snapshot.data?.inMilliseconds ?? 0;
        return SubtitleCuePill(video: video, positionMs: positionMs);
      },
    );
  }
}
