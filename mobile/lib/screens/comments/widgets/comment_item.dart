// ABOUTME: Individual comment widget for flat list display
// ABOUTME: Renders a single comment with author info, content, and reply indicator

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/comments/widgets/comment_options_modal.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

/// Widget that renders a single comment in a flat list.
///
/// Replies are distinguished by a 16px left padding and "Re: npub..." indicator.
/// Shows author avatar, name, timestamp, and content.
/// Includes a reply button that focuses the main bottom input for replies.
/// Long press opens options menu (delete) if comment is from current user.
///
/// Uses [Comment] from the comments_repository package,
/// following clean architecture separation of UI and repository layers.
class CommentItem extends ConsumerStatefulWidget {
  const CommentItem({required this.comment, super.key});

  /// The comment to display.
  final Comment comment;

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
      onLongPressStart: isCurrentUser
          ? (_) {
              setState(() {
                _isHeld = true;
              });
            }
          : null,
      onLongPressEnd: isCurrentUser
          ? (_) async {
              setState(() {
                _isHeld = false;
              });
              final result = await CommentOptionsModal.show(context);
              if (result == true && mounted) {
                context.read<CommentsBloc>().add(
                  CommentDeleteRequested(widget.comment.id),
                );
              }
            }
          : null,
      onLongPressCancel: isCurrentUser
          ? () {
              setState(() {
                _isHeld = false;
              });
            }
          : null,
      child: Container(
        color: _isHeld ? VineTheme.containerLow : Colors.transparent,
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentHeader(
              authorPubkey: widget.comment.authorPubkey,
              relativeTime: widget.comment.relativeTime,
            ),
            const SizedBox(height: 12),
            if (widget.comment.replyToAuthorPubkey != null)
              _ReplyIndicator(
                parentAuthorPubkey: widget.comment.replyToAuthorPubkey!,
              ),
            Padding(
              padding: EdgeInsets.only(
                top: widget.comment.replyToAuthorPubkey != null ? 4 : 0,
              ),
              child: _CommentContent(
                commentId: widget.comment.id,
                content: widget.comment.content,
              ),
            ),
            const SizedBox(height: 12),
            _ActionsRow(commentId: widget.comment.id),
          ],
        ),
      ),
    );
  }
}

/// Header for a comment showing avatar, user info, timestamp, and "You" indicator.
///
/// Fetches author profile and determines if the comment is from the current user.
class _CommentHeader extends ConsumerWidget {
  const _CommentHeader({
    required this.authorPubkey,
    required this.relativeTime,
  });

  /// Public key of the comment author
  final String authorPubkey;

  /// Relative time string (e.g., "2h ago")
  final String relativeTime;

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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        UserAvatar(size: 36, imageUrl: profile?.picture),
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
                  context.goProfileGrid(authorPubkey);
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

/// Content section of a comment showing text and reply button.
class _CommentContent extends StatelessWidget {
  const _CommentContent({required this.commentId, required this.content});

  /// ID of the comment (for reply targeting)
  final String commentId;

  /// Text content of the comment
  final String content;

  @override
  Widget build(BuildContext context) {
    return SelectableText(content, style: const TextStyle(color: Colors.white));
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.commentId});

  /// ID of the comment (for reply targeting)
  final String commentId;

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
            child: Container(
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
                  SizedBox(width: 8),
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
      ],
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
          padding: EdgeInsets.symmetric(vertical: 2),
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
        SizedBox(width: 8),
        Flexible(
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: VineTheme.containerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Text(
              '$displayName',
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
