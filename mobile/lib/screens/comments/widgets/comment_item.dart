// ABOUTME: Individual comment widget for flat list display
// ABOUTME: Renders a single comment with author info, content, like button,
// ABOUTME: and reply indicator. Long-press shows options (delete/report/block).

import 'dart:math';

import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/comments/widgets/comment_options_modal.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

/// Widget that renders a single comment in a flat list.
///
/// Replies are distinguished by a 16px left padding and "Re: npub..." indicator.
/// Shows author avatar, name, timestamp, and content.
/// Includes a reply button and like button in the actions row.
/// Long press opens options menu for any comment:
/// - Own comments: Delete
/// - Other users' comments: Flag Content, Block User
///
/// Uses [Comment] from the comments_repository package,
/// following clean architecture separation of UI and repository layers.
class CommentItem extends ConsumerStatefulWidget {
  const CommentItem({required this.comment, this.depth = 0, super.key});

  /// The comment to display.
  final Comment comment;

  /// Nesting depth (0 = top-level, 1+ = reply).
  final int depth;

  @override
  ConsumerState<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends ConsumerState<CommentItem> {
  bool _isHeld = false;

  @override
  Widget build(BuildContext context) {
    // Check if this comment is from the current user
    final nostrService = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrService.publicKey;
    final isCurrentUser =
        currentUserPubkey.isNotEmpty &&
        currentUserPubkey == widget.comment.authorPubkey;

    return GestureDetector(
      onLongPressStart: (_) {
        setState(() {
          _isHeld = true;
        });
      },
      onLongPressEnd: (_) async {
        setState(() {
          _isHeld = false;
        });
        await _showOptionsModal(context, isCurrentUser: isCurrentUser);
      },
      onLongPressCancel: () {
        setState(() {
          _isHeld = false;
        });
      },
      child: ColoredBox(
        color: _isHeld ? VineTheme.containerLow : Colors.transparent,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thread lines for nested comments
              if (widget.depth > 0)
                ...List.generate(
                  min(widget.depth, 4),
                  (i) => Container(
                    width: 24,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: VineTheme.containerLow,
                          width: i == min(widget.depth, 4) - 1 ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              // Comment content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: widget.depth > 0 ? 8 : 16,
                    right: 16,
                    top: widget.depth > 0 ? 10 : 16,
                    bottom: widget.depth > 0 ? 12 : 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CommentHeader(
                        authorPubkey: widget.comment.authorPubkey,
                        relativeTime: widget.comment.relativeTime,
                        avatarSize: widget.depth >= 2 ? 28.0 : 36.0,
                      ),
                      const SizedBox(height: 12),
                      // Show reply indicator only for orphaned
                      // replies at depth 0
                      if (widget.depth == 0 &&
                          widget.comment.replyToAuthorPubkey != null)
                        _ReplyIndicator(
                          parentAuthorPubkey:
                              widget.comment.replyToAuthorPubkey!,
                        ),
                      Padding(
                        padding: EdgeInsets.only(
                          top:
                              widget.depth == 0 &&
                                  widget.comment.replyToAuthorPubkey != null
                              ? 4
                              : 0,
                        ),
                        child: _CommentContent(
                          commentId: widget.comment.id,
                          content: widget.comment.content,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ActionsRow(
                        commentId: widget.comment.id,
                        authorPubkey: widget.comment.authorPubkey,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOptionsModal(
    BuildContext context, {
    required bool isCurrentUser,
  }) async {
    if (!mounted) return;

    // Capture BLoC reference before async gap to avoid using context
    // after the widget may have been unmounted
    final bloc = context.read<CommentsBloc>();

    final CommentOptionResult? result;

    if (isCurrentUser) {
      result = await CommentOptionsModal.showForOwnComment(context);
    } else {
      result = await CommentOptionsModal.showForOtherUserIntegrated(
        context,
        authorPubkey: widget.comment.authorPubkey,
      );
    }

    if (result == null || !mounted) return;

    switch (result) {
      case CommentDeleteResult():
        bloc.add(CommentDeleteRequested(widget.comment.id));
      case CommentReportResult(:final reason, :final details):
        bloc.add(
          CommentReportRequested(
            commentId: widget.comment.id,
            authorPubkey: widget.comment.authorPubkey,
            reason: reason,
            details: details,
          ),
        );
      case CommentBlockUserResult(:final authorPubkey):
        bloc.add(CommentBlockUserRequested(authorPubkey));
    }
  }
}

/// Header for a comment showing avatar, user info, timestamp, and "You" indicator.
///
/// Fetches author profile and determines if the comment is from the current user.
class _CommentHeader extends ConsumerWidget {
  const _CommentHeader({
    required this.authorPubkey,
    required this.relativeTime,
    this.avatarSize = 36,
  });

  /// Public key of the comment author
  final String authorPubkey;

  /// Relative time string (e.g., "2h ago")
  final String relativeTime;

  /// Avatar size (smaller for deeply nested comments)
  final double avatarSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch profile for this comment author
    final userProfileService = ref.watch(userProfileServiceProvider);
    final profile = userProfileService.getCachedProfile(authorPubkey);

    // If profile not cached and not known missing, fetch it
    if (profile == null &&
        !userProfileService.shouldSkipProfileFetch(authorPubkey)) {
      Future.microtask(() {
        ref.read(userProfileProvider.notifier).fetchProfile(authorPubkey);
      });
    }

    // Check if this comment is from the current user
    final nostrService = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrService.publicKey;
    final isCurrentUser =
        currentUserPubkey.isNotEmpty && currentUserPubkey == authorPubkey;

    return Row(
      children: [
        UserAvatar(size: avatarSize, imageUrl: profile?.picture),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    relativeTime,
                    style: VineTheme.bodyFont(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isCurrentUser) ...[
                    Text(
                      ' • ',
                      style: VineTheme.bodyFont(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'You',
                      style: VineTheme.bodyFont(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              GestureDetector(
                onTap: () {
                  final npub = NostrKeyUtils.encodePubKey(authorPubkey);
                  context.push(OtherProfileScreen.pathForNpub(npub));
                },
                child: profile == null
                    ? Text(
                        NostrKeyUtils.encodePubKey(authorPubkey),
                        style: const TextStyle(
                          color: Color(0xF2FFFFFF), // rgba(255,255,255,0.95)
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : UserName.fromUserProfile(
                        profile,
                        style: const TextStyle(
                          color: Color(0xF2FFFFFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Content section of a comment showing text with parsed @mentions.
class _CommentContent extends StatelessWidget {
  const _CommentContent({required this.commentId, required this.content});

  /// ID of the comment (for reply targeting)
  final String commentId;

  /// Text content of the comment
  final String content;

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      child: Text.rich(
        _buildContentSpans(context),
        style: const TextStyle(color: VineTheme.onSurface),
      ),
    );
  }

  TextSpan _buildContentSpans(BuildContext context) {
    // Match nostr:npub1... pattern
    final mentionPattern = RegExp('nostr:(npub1[a-zA-Z0-9]{58,})');
    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in mentionPattern.allMatches(content)) {
      // Text before mention
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }

      // Mention span
      final npub = match.group(1)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _MentionLink(npub: npub),
        ),
      );
      lastEnd = match.end;
    }

    // Remaining text
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    if (spans.isEmpty) {
      return TextSpan(text: content);
    }

    return TextSpan(children: spans);
  }
}

/// Inline mention link that resolves profile name and navigates to profile.
class _MentionLink extends ConsumerWidget {
  const _MentionLink({required this.npub});

  final String npub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String displayText;
    try {
      final hexPubkey = NostrKeyUtils.decode(npub);
      final userProfileService = ref.watch(userProfileServiceProvider);
      final profile = userProfileService.getCachedProfile(hexPubkey);

      if (profile == null &&
          !userProfileService.shouldSkipProfileFetch(hexPubkey)) {
        Future.microtask(() {
          ref.read(userProfileProvider.notifier).fetchProfile(hexPubkey);
        });
      }

      displayText = profile?.displayName ?? profile?.name ?? npub;
    } catch (_) {
      displayText = npub;
    }

    return GestureDetector(
      onTap: () => context.push(OtherProfileScreen.pathForNpub(npub)),
      child: Text(
        '@$displayText',
        style: VineTheme.bodyFont(
          fontSize: 14,
          color: VineTheme.tabIndicatorGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.commentId, required this.authorPubkey});

  /// ID of the comment (for reply targeting and like toggling)
  final String commentId;

  /// Pubkey of the comment author (for like toggling)
  final String authorPubkey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          identifier: 'reply_button',
          button: true,
          label: 'Reply to comment',
          child: InkWell(
            onTap: () {
              context.read<CommentsBloc>().add(CommentReplyToggled(commentId));
            },
            child: SizedBox(
              height: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icon/arrow_bend_down_right.svg',
                    height: 11,
                    colorFilter: const ColorFilter.mode(
                      VineTheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reply',
                    style: VineTheme.bodyFont(
                      fontSize: 14,
                      color: VineTheme.onSurfaceMuted,
                      fontWeight: FontWeight.w600,
                      height: 14 / 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        _CommentLikeButton(commentId: commentId, authorPubkey: authorPubkey),
      ],
    );
  }
}

/// Like button for a comment, using BlocSelector for efficient rebuilds.
class _CommentLikeButton extends StatelessWidget {
  const _CommentLikeButton({
    required this.commentId,
    required this.authorPubkey,
  });

  final String commentId;
  final String authorPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      CommentsBloc,
      CommentsState,
      ({bool isLiked, int count})
    >(
      selector: (state) => (
        isLiked: state.likedCommentIds.contains(commentId),
        count: state.commentLikeCounts[commentId] ?? 0,
      ),
      builder: (context, likeState) {
        final isLiked = likeState.isLiked;
        final count = likeState.count;

        return Semantics(
          identifier: 'like_button',
          button: true,
          label: isLiked ? 'Unlike comment' : 'Like comment',
          child: InkWell(
            onTap: () {
              context.read<CommentsBloc>().add(
                CommentLikeToggled(
                  commentId: commentId,
                  authorPubkey: authorPubkey,
                ),
              );
            },
            child: SizedBox(
              height: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    isLiked
                        ? 'assets/icon/heart_fill.svg'
                        : 'assets/icon/heart.svg',
                    height: 12,
                    colorFilter: ColorFilter.mode(
                      isLiked ? VineTheme.likeRed : VineTheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: VineTheme.bodyFont(
                        fontSize: 12,
                        color: isLiked
                            ? VineTheme.likeRed
                            : VineTheme.onSurfaceMuted,
                        fontWeight: FontWeight.w600,
                        height: 12 / 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shows "Re: {display_name}" indicator for replies
/// Fetches parent author profile and displays their name
class _ReplyIndicator extends ConsumerWidget {
  const _ReplyIndicator({required this.parentAuthorPubkey});

  final String parentAuthorPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch parent author profile
    final userProfileService = ref.watch(userProfileServiceProvider);
    final profile = userProfileService.getCachedProfile(parentAuthorPubkey);

    // Trigger fetch if needed
    if (profile == null &&
        !userProfileService.shouldSkipProfileFetch(parentAuthorPubkey)) {
      Future.microtask(() {
        ref.read(userProfileProvider.notifier).fetchProfile(parentAuthorPubkey);
      });
    }

    // Get display name with fallback chain
    final displayName =
        profile?.displayName ??
        profile?.name ??
        NostrKeyUtils.encodePubKey(parentAuthorPubkey);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 20,
          padding: const EdgeInsets.symmetric(vertical: 2),
          alignment: Alignment.center,
          child: Text(
            'Re:',
            style: VineTheme.bodyFont(
              fontSize: 14,
              color: VineTheme.tabIndicatorGreen,
              height: 14 / 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: VineTheme.containerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Text(
              displayName,
              style: VineTheme.bodyFont(
                fontSize: 14,
                color: VineTheme.tabIndicatorGreen,
                height: 14 / 20,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
