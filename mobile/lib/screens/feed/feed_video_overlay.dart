// ABOUTME: Video overlay for the new home feed (video_feed_page).
// ABOUTME: Displays author info, video description, and action buttons
// ABOUTME: matching the new design: Like, Comment, Repost, Share, More.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/widgets/badge_explanation_modal.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';
import 'package:openvine/widgets/proofmode_badge.dart';
import 'package:openvine/widgets/proofmode_badge_row.dart';
import 'package:openvine/widgets/video_feed_item/actions/cc_action_button.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_edit_button.dart';
import 'package:openvine/widgets/video_feed_item/actions/comment_action_button.dart';
import 'package:openvine/widgets/video_feed_item/actions/like_action_button.dart';
import 'package:openvine/widgets/video_feed_item/actions/more_action_button.dart';
import 'package:openvine/widgets/video_feed_item/actions/repost_action_button.dart';
import 'package:openvine/widgets/video_feed_item/actions/share_action_button.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_row.dart';
import 'package:openvine/widgets/video_feed_item/collaborator_avatar_row.dart';
import 'package:openvine/widgets/video_feed_item/inspired_by_attribution_row.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_feed_item/video_follow_button.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// Video overlay for the home feed matching the new design.
///
/// Layout:
/// - Bottom-left: author avatar, name, timestamp, description, audio
/// - Bottom-right: Like, Comment, Repost, Share, More ("...") buttons
class FeedVideoOverlay extends ConsumerWidget {
  const FeedVideoOverlay({
    required this.video,
    required this.isActive,
    required this.player,
    super.key,
  });

  final VideoEvent video;
  final bool isActive;
  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isActive) return const SizedBox();

    final hasTextContent =
        video.content.isNotEmpty ||
        (video.title != null && video.title!.isNotEmpty);

    return Stack(
      children: [
        // Bottom gradient overlay
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: SizedBox(
              height: MediaQuery.of(context).size.height / 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Subtitle overlay — Positioned.fill gives the inner Stack a size
        // so SubtitleOverlay's Positioned can resolve correctly.
        if (video.hasSubtitles)
          Positioned.fill(
            child: _SubtitleLayer(video: video, player: player),
          ),
        // ProofMode and Vine badges (top-right)
        Positioned(
          top: MediaQuery.viewPaddingOf(context).top + 8,
          right: 16,
          child: GestureDetector(
            onTap: () => context.showVideoPausingDialog<void>(
              barrierDismissible: true,
              builder: (context) => BadgeExplanationModal(video: video),
            ),
            child: ProofModeBadgeRow(video: video, size: BadgeSize.small),
          ),
        ),
        // Author info and description (bottom-left)
        Positioned(
          bottom: 14,
          left: 16,
          right: 80,
          child: _AuthorInfoSection(
            video: video,
            hasTextContent: hasTextContent,
          ),
        ),
        // Action buttons column (bottom-right)
        Positioned(
          bottom: 14,
          right: 16,
          child: SafeArea(child: _ActionButtons(video: video)),
        ),
      ],
    );
  }
}

class _AuthorInfoSection extends ConsumerWidget {
  const _AuthorInfoSection({required this.video, required this.hasTextContent});

  final VideoEvent video;
  final bool hasTextContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileService = ref.watch(userProfileServiceProvider);
    final profile = userProfileService.getCachedProfile(video.pubkey);
    final avatarUrl = profile?.picture ?? video.authorAvatar;
    final displayName =
        profile?.bestDisplayName ??
        video.authorName ??
        NostrKeyUtils.truncateNpub(video.pubkey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Repost banner
        if (video.isRepost && video.reposterPubkey != null) ...[
          VideoRepostHeader(reposterPubkey: video.reposterPubkey!),
          const SizedBox(height: 8),
        ],
        // Avatar and name row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AuthorAvatar(pubkey: video.pubkey, avatarUrl: avatarUrl),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final npub = normalizeToNpub(video.pubkey);
                  if (npub != null) {
                    context.push(OtherProfileScreen.pathForNpub(npub));
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Semantics(
                            identifier: 'video_author_name',
                            container: true,
                            explicitChildNodes: true,
                            label: 'Video author: $displayName',
                            child: Text(
                              displayName,
                              style: VineTheme.titleSmallFont(
                                color: VineTheme.whiteText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        _Nip05Badge(pubkey: video.pubkey),
                      ],
                    ),
                    Text(video.relativeTime, style: VineTheme.labelSmallFont()),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Video description
        if (hasTextContent) ...[
          const SizedBox(height: 2),
          Semantics(
            identifier: 'video_description',
            container: true,
            explicitChildNodes: true,
            label:
                'Video description: ${(video.content.isNotEmpty ? video.content : video.title ?? '').trim()}',
            child: ClickableHashtagText(
              text:
                  (video.content.isNotEmpty ? video.content : video.title ?? '')
                      .trim(),
              style: VineTheme.bodyMediumFont(),
              hashtagStyle: VineTheme.bodySmallFont(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Collaborator avatars
          if (video.hasCollaborators) ...[
            const SizedBox(height: 4),
            CollaboratorAvatarRow(video: video),
          ],
          // Inspired-by attribution
          if (video.hasInspiredBy) ...[
            const SizedBox(height: 4),
            InspiredByAttributionRow(video: video, isActive: true),
          ],
          // Audio attribution
          if (video.hasAudioReference) ...[
            const SizedBox(height: 4),
            AudioAttributionRow(video: video),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.pubkey, this.avatarUrl});

  final String pubkey;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: VineTheme.whiteText, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => ColoredBox(
                        color: VineTheme.cardBackground,
                        child: const Icon(
                          Icons.person,
                          color: VineTheme.onSurfaceMuted,
                          size: 24,
                        ),
                      ),
                      errorWidget: (context, url, error) => ColoredBox(
                        color: VineTheme.cardBackground,
                        child: const Icon(
                          Icons.person,
                          color: VineTheme.onSurfaceMuted,
                          size: 24,
                        ),
                      ),
                    )
                  : Container(
                      color: VineTheme.cardBackground,
                      child: const Icon(
                        Icons.person,
                        color: VineTheme.onSurfaceMuted,
                        size: 24,
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 31,
            top: 31,
            child: VideoFollowButton(pubkey: pubkey, hideIfFollowing: true),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    const gap = 24.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit button self-hides via SizedBox.shrink() when not
        // applicable, so it sits outside the uniform spacing to
        // avoid a phantom gap.
        VideoEditButton(video: video),
        Column(
          spacing: gap,
          mainAxisSize: MainAxisSize.min,
          children: [
            LikeActionButton(video: video),
            CommentActionButton(video: video),
            CcActionButton(video: video),
            RepostActionButton(video: video),
            ShareActionButton(video: video),
            MoreActionButton(video: video),
          ],
        ),
      ],
    );
  }
}

/// NIP-05 verification badge.
class _Nip05Badge extends ConsumerWidget {
  const _Nip05Badge({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verificationAsync = ref.watch(nip05VerificationProvider(pubkey));

    return verificationAsync.when(
      data: (status) {
        if (status != Nip05VerificationStatus.verified) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: SvgPicture.asset(
            'assets/icon/seal_check.svg',
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              VineTheme.vineGreen,
              BlendMode.srcIn,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Streams the player position and renders subtitle text.
///
/// Uses [Positioned.fill] + inner [Stack] so the [SubtitleOverlay]'s
/// own [Positioned] resolves against a proper [Stack] ancestor.
class _SubtitleLayer extends ConsumerWidget {
  const _SubtitleLayer({required this.video, required this.player});

  final VideoEvent video;
  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitlesVisible = ref.watch(subtitleVisibilityProvider);

    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, snapshot) {
        final positionMs = snapshot.data?.inMilliseconds ?? 0;
        return Stack(
          children: [
            SubtitleOverlay(
              video: video,
              positionMs: positionMs,
              visible: subtitlesVisible,
              bottomOffset: 180,
            ),
          ],
        );
      },
    );
  }
}
