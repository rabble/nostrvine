// ABOUTME: Video overlay for the new home feed (video_feed_page).
// ABOUTME: Displays author info, video description, and action buttons
// ABOUTME: matching the new design: Like, Comment, Repost, Share, More.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/utils/scroll_driven_opacity.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/badge_explanation_modal.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';
import 'package:openvine/widgets/proofmode_badge_row.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_row.dart';
import 'package:openvine/widgets/video_feed_item/collaborator_avatar_row.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/inspired_by_attribution_row.dart';
import 'package:openvine/widgets/video_feed_item/list_attribution_chip.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_play_overlay.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_feed_item/video_follow_button.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// Video overlay for the home feed matching the new design.
///
/// Layout:
/// - Bottom-left: author avatar, name, timestamp, description, audio
/// - Bottom-right: Like, Comment, Repost, Share, More ("...") buttons
/// - Full-screen blur overlay when video has content warnings (warn labels)
class FeedVideoOverlay extends ConsumerStatefulWidget {
  const FeedVideoOverlay({
    required this.video,
    required this.isActive,
    required this.pagePosition,
    required this.index,
    this.player,
    this.firstFrameFuture,
    this.listSources,
    super.key,
  });

  final VideoEvent video;
  final bool isActive;

  /// Fractional page position from [PooledVideoFeed.onScrollOffsetChanged].
  /// Used to compute scroll-driven overlay opacity matching the fullscreen feed.
  final ValueNotifier<double> pagePosition;

  /// The index of this item in the feed, used with [pagePosition] to compute
  /// the scroll distance for opacity.
  final int index;
  final Player? player;
  final Future<void>? firstFrameFuture;
  final Set<String>? listSources;

  @override
  ConsumerState<FeedVideoOverlay> createState() => _FeedVideoOverlayState();
}

class _FeedVideoOverlayState extends ConsumerState<FeedVideoOverlay> {
  bool _contentWarningRevealed = false;

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final overlayLabels = contentWarningOverlayLabels(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: video.warnLabels,
    );
    final showContentWarningOverlay = shouldShowContentWarningOverlay(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: video.warnLabels,
    );

    Log.debug(
      'Feed overlay build: eventId=${video.id}, pubkey=${video.pubkey}, '
      'isActive=${widget.isActive}, hasPlayer=${widget.player != null}, '
      'hasFirstFrameFuture=${widget.firstFrameFuture != null}, '
      'hasSubtitles=${video.hasSubtitles}, '
      'hasWarning=$showContentWarningOverlay, '
      'videoUrl=${video.videoUrl}, thumbnailUrl=${video.thumbnailUrl}',
      name: 'FeedVideoOverlay',
      category: LogCategory.video,
    );

    // Content warning blur overlay takes priority over normal overlay
    if (showContentWarningOverlay && !_contentWarningRevealed) {
      return ContentWarningBlurOverlay(
        labels: overlayLabels,
        onReveal: () => setState(() {
          _contentWarningRevealed = true;
        }),
        onHideSimilar: () {
          hideContentWarningsLikeThese(
            context: context,
            ref: ref,
            labels: overlayLabels,
          );
        },
      );
    }

    final hasTextContent =
        video.content.isNotEmpty ||
        (video.title != null && video.title!.isNotEmpty);

    final safeAreaBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      children: [
        // Bottom gradient overlay (not scroll-faded — keeps the gradient
        // visible so the video edge is always readable).
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
                      VineTheme.backgroundColor.withValues(alpha: 0.0),
                      VineTheme.backgroundColor.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.player != null)
          PausedVideoPlayOverlay(
            player: widget.player!,
            firstFrameFuture: widget.firstFrameFuture,
            isVisible: widget.isActive,
          ),
        // Subtitle overlay — Positioned.fill gives the inner Stack a size
        // so SubtitleOverlay's Positioned can resolve correctly.
        if (video.hasSubtitles && widget.player != null)
          Positioned.fill(
            child: _SubtitleLayer(video: video, player: widget.player!),
          ),
        // Scroll-faded overlay: author info, badges, and action buttons all
        // fade together as the user swipes to the next video.
        ValueListenableBuilder<double>(
          valueListenable: widget.pagePosition,
          builder: (context, page, child) {
            final distance = (page - widget.index).abs().clamp(0.0, 1.0);
            final opacity = scrollDrivenOpacity(distance);
            return Opacity(
              opacity: opacity,
              child: IgnorePointer(
                ignoring: opacity < 0.01,
                child: child,
              ),
            );
          },
          child: Stack(
            children: [
              // ProofMode and Vine badges (top-right)
              Positioned(
                top: MediaQuery.viewPaddingOf(context).top + 64,
                right: 16,
                child: GestureDetector(
                  onTap: () => context.showVideoPausingDialog<void>(
                    builder: (context) => BadgeExplanationModal(video: video),
                  ),
                  child: ProofModeBadgeRow(video: video),
                ),
              ),
              // Author info and description (bottom-left)
              Positioned(
                bottom: 14 + safeAreaBottom,
                left: 16,
                right: 80,
                child: _AuthorInfoSection(
                  video: video,
                  hasTextContent: hasTextContent,
                  listSources: widget.listSources,
                ),
              ),
              // Action buttons column (bottom-right)
              Positioned(
                bottom: 14 + safeAreaBottom,
                right: 16,
                child: _ActionButtons(video: video),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthorInfoSection extends ConsumerWidget {
  const _AuthorInfoSection({
    required this.video,
    required this.hasTextContent,
    this.listSources,
  });

  final VideoEvent video;
  final bool hasTextContent;
  final Set<String>? listSources;

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
        // Repost banner
        if (video.isRepost && video.reposterPubkey != null) ...[
          VideoRepostHeader(reposterPubkey: video.reposterPubkey!),
          const SizedBox(height: 8),
        ],
        // Avatar and name row
        Row(
          children: [
            _AuthorAvatar(pubkey: video.pubkey, avatarUrl: avatarUrl),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () {
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
                              style: VineTheme.titleSmallFont(),
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
          // List attribution (curated lists)
          if (listSources != null && listSources!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _ListAttribution(listSources: listSources!),
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
          UserAvatar(
            imageUrl: avatarUrl,
            size: 48,
            semanticLabel: 'Author avatar',
            onTap: () {
              final npub = normalizeToNpub(pubkey);
              if (npub != null) {
                context.pushWithVideoPause(
                  OtherProfileScreen.pathForNpub(npub),
                );
              }
            },
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
  Widget build(BuildContext context) => VideoOverlayActionColumn(video: video);
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
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Displays curated list attribution chips and handles navigation.
class _ListAttribution extends ConsumerWidget {
  const _ListAttribution({required this.listSources});

  final Set<String> listSources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curatedListRepository = ref.watch(curatedListRepositoryProvider);

    return ListAttributionChip(
      listIds: listSources,
      listLookup: curatedListRepository.getListById,
      onListTap: (listId, listName) {
        final list = curatedListRepository.getListById(listId);
        context.pushWithVideoPause(
          CuratedListFeedScreen.pathForId(listId),
          extra: CuratedListRouteExtra(
            listName: listName,
            videoIds: list?.videoEventIds,
          ),
        );
      },
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
