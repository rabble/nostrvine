// ABOUTME: Grid widget displaying a user's comments on their profile.
// ABOUTME: Shows video replies as a 3-column thumbnail grid at top,
// ABOUTME: followed by text comments as a list below.

import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/profile_comments/profile_comments_bloc.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Grid widget displaying a user's comments (video replies + text).
///
/// Requires [ProfileCommentsBloc] to be provided in the widget tree.
class ProfileCommentsGrid extends StatefulWidget {
  const ProfileCommentsGrid({required this.isOwnProfile, super.key});

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  @override
  State<ProfileCommentsGrid> createState() => _ProfileCommentsGridState();
}

class _ProfileCommentsGridState extends State<ProfileCommentsGrid>
    with ScrollPaginationMixin {
  /// Resolved from [PrimaryScrollController] provided by [NestedScrollView].
  ScrollController? _primaryScrollController;

  @override
  ScrollController get paginationScrollController => _primaryScrollController!;

  @override
  bool canLoadMore() {
    final bloc = context.read<ProfileCommentsBloc>();
    return bloc.state.hasMoreContent && !bloc.state.isLoadingMore;
  }

  @override
  FutureOr<void> onLoadMore() {
    context.read<ProfileCommentsBloc>().add(
      const ProfileCommentsLoadMoreRequested(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final primary = PrimaryScrollController.of(context);
    if (_primaryScrollController != primary) {
      if (_primaryScrollController != null) disposePagination();
      _primaryScrollController = primary;
      initPagination();
    }
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCommentsBloc, ProfileCommentsState>(
      builder: (context, state) {
        if (state.status == ProfileCommentsStatus.initial ||
            state.status == ProfileCommentsStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          );
        }

        if (state.status == ProfileCommentsStatus.failure) {
          return const Center(
            child: Text(
              'Error loading comments',
              style: TextStyle(color: VineTheme.whiteText),
            ),
          );
        }

        if (state.videoReplies.isEmpty && state.textComments.isEmpty) {
          return _CommentsEmptyState(isOwnProfile: widget.isOwnProfile);
        }

        return CustomScrollView(
          slivers: [
            if (state.videoReplies.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'Video Replies'),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= state.videoReplies.length) {
                      return const SizedBox.shrink();
                    }
                    return _VideoReplyTile(
                      comment: state.videoReplies[index],
                    );
                  }, childCount: state.videoReplies.length),
                ),
              ),
            ],
            if (state.textComments.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'Comments'),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index >= state.textComments.length) {
                    return const SizedBox.shrink();
                  }
                  return _ProfileCommentCard(
                    comment: state.textComments[index],
                  );
                }, childCount: state.textComments.length),
              ),
            ],
            if (state.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Section header label for video replies and text comments.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: VineTheme.secondaryText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Empty state shown when user has no comments.
class _CommentsEmptyState extends StatelessWidget {
  const _CommentsEmptyState({required this.isOwnProfile});

  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  color: VineTheme.onSurfaceMuted,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  isOwnProfile ? 'No Comments Yet' : 'No Comments',
                  textAlign: .center,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isOwnProfile
                      ? 'Your comments and replies will '
                            'appear here'
                      : 'Their comments and replies will '
                            'appear here',
                  textAlign: .center,
                  style: const TextStyle(
                    color: VineTheme.onSurfaceMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

/// Thumbnail tile for a video reply in the grid.
class _VideoReplyTile extends StatelessWidget {
  const _VideoReplyTile({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.push(VideoDetailScreen.pathForId(comment.rootEventId)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: VineTheme.cardBackground),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _VideoReplyThumbnail(thumbnailUrl: comment.thumbnailUrl),
              // Play icon overlay
              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: VineTheme.whiteText,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thumbnail image for a video reply.
class _VideoReplyThumbnail extends StatelessWidget {
  const _VideoReplyThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return VineCachedImage(
        imageUrl: thumbnailUrl!,
        placeholder: (context, url) => const _ThumbnailPlaceholder(),
        errorWidget: (context, url, error) => const _ThumbnailPlaceholder(),
      );
    }
    return const _ThumbnailPlaceholder();
  }
}

/// Placeholder for video reply thumbnails.
class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      color: VineTheme.surfaceContainer,
    ),
  );
}

/// Card widget for a text comment in the list.
class _ProfileCommentCard extends StatelessWidget {
  const _ProfileCommentCard({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.push(VideoDetailScreen.pathForId(comment.rootEventId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VineTheme.whiteText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.relativeTime,
                    style: const TextStyle(
                      color: VineTheme.onSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: VineTheme.onSurfaceMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
