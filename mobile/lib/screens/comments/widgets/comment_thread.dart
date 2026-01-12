// ABOUTME: Threaded comment widget with nested replies
// ABOUTME: Renders a comment with author info, content, and recursively renders replies

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/comments/widgets/widgets.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

/// Widget that renders a single comment with all its nested replies.
///
/// All comments render at the same indentation level (flattened).
/// Reply relationships are shown via the "Re: npub..." indicator.
/// Shows author avatar, name, timestamp, and content.
/// Includes a reply button that toggles an inline reply input.
///
/// Uses [CommentNode] from the comments_repository package,
/// following clean architecture separation of UI and repository layers.
class CommentThread extends StatelessWidget {
  const CommentThread({required this.node, this.depth = 0, super.key});

  /// The comment node containing the comment and its replies.
  final CommentNode node;

  /// Current nesting depth for indentation (0 = top level).
  final int depth;

  @override
  Widget build(BuildContext context) {
    // Show placeholder for missing/deleted comments (only if they have replies)
    if (node.isNotFound) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Text(
              '[Comment not found]',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ...node.replies.map((reply) => CommentThread(node: reply, depth: 0)),
        ],
      );
    }

    final comment = node.comment;

    return BlocBuilder<CommentsBloc, CommentsState>(
      buildWhen: (prev, next) =>
          prev.activeReplyCommentId != next.activeReplyCommentId ||
          prev.isReplyPosting(comment.id) != next.isReplyPosting(comment.id),
      builder: (context, state) {
        final isReplying = state.activeReplyCommentId == comment.id;
        final isPostingReply = state.isReplyPosting(comment.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      // Fetch profile for this comment author
                      final userProfileService = ref.watch(
                        userProfileServiceProvider,
                      );
                      final profile = userProfileService.getCachedProfile(
                        comment.authorPubkey,
                      );

                      // If profile not cached and not known missing, fetch it
                      if (profile == null &&
                          !userProfileService.shouldSkipProfileFetch(
                            comment.authorPubkey,
                          )) {
                        Future.microtask(() {
                          ref
                              .read(userProfileProvider.notifier)
                              .fetchProfile(comment.authorPubkey);
                        });
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Avatar + Time + "You" indicator (all on same line)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              UserAvatar(size: 36, imageUrl: profile?.picture),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final nostrService = ref.watch(
                                      nostrServiceProvider,
                                    );
                                    final currentUserPubkey =
                                        nostrService.publicKey;
                                    final isCurrentUser =
                                        currentUserPubkey.isNotEmpty &&
                                        currentUserPubkey ==
                                            comment.authorPubkey;

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              comment.relativeTime,
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
                                            context.goProfileGrid(
                                              comment.authorPubkey,
                                            );
                                          },
                                          child: profile == null
                                              ? Text(
                                                  NostrKeyUtils.encodePubKey(
                                                    comment.authorPubkey,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Color(
                                                      0xF2FFFFFF,
                                                    ), // rgba(255,255,255,0.95)
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.1,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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

                                        // // 3-dot options menu (only visible for own comments)
                                        // Consumer(
                                        //   builder: (context, ref, _) {
                                        //     final nostrService = ref.watch(
                                        //       nostrServiceProvider,
                                        //     );
                                        //     final currentUserPubkey =
                                        //         nostrService.publicKey;
                                        //     final isOwnComment =
                                        //         currentUserPubkey.isNotEmpty &&
                                        //         currentUserPubkey ==
                                        //             comment.authorPubkey;

                                        //     if (!isOwnComment) {
                                        //       return const SizedBox.shrink();
                                        //     }

                                        //     return Semantics(
                                        //       identifier:
                                        //           'comment_options_button',
                                        //       button: true,
                                        //       label: 'Comment options',
                                        //       child: IconButton(
                                        //         icon: const Icon(
                                        //           Icons.more_vert,
                                        //           color: Colors.white54,
                                        //           size: 20,
                                        //         ),
                                        //         padding: EdgeInsets.zero,
                                        //         constraints:
                                        //             const BoxConstraints(),
                                        //         onPressed: () async {
                                        //           final shouldDelete =
                                        //               await CommentOptionsModal.show(
                                        //                 context,
                                        //               );
                                        //           if (shouldDelete == true &&
                                        //               context.mounted) {
                                        //             context
                                        //                 .read<CommentsBloc>()
                                        //                 .add(
                                        //                   CommentDeleteRequested(
                                        //                     comment.id,
                                        //                   ),
                                        //                 );
                                        //           }
                                        //         },
                                        //       ),
                                        //     );
                                        //   },
                                        // ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // Show reply indicator if this is a reply
                  if (comment.replyToAuthorPubkey != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 48, bottom: 4),
                      child: _ReplyIndicator(
                        parentAuthorPubkey: comment.replyToAuthorPubkey!,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          comment.content,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Semantics(
                              identifier: isReplying
                                  ? 'cancel_reply_button'
                                  : 'reply_button',
                              button: true,
                              label: isReplying
                                  ? 'Cancel reply'
                                  : 'Reply to comment',
                              child: TextButton(
                                onPressed: () {
                                  context.read<CommentsBloc>().add(
                                    CommentReplyToggled(comment.id),
                                  );
                                },
                                child: Text(
                                  isReplying ? 'Cancel' : 'Reply',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isReplying)
                    _ReplyInputWrapper(
                      parentCommentId: comment.id,
                      parentAuthorPubkey: comment.authorPubkey,
                      isPosting: isPostingReply,
                    ),
                ],
              ),
            ),
            // Recursively render replies
            ...node.replies.map(
              (reply) => CommentThread(node: reply, depth: 0),
            ),
          ],
        );
      },
    );
  }
}

/// Wrapper for reply input that manages its own TextEditingController
class _ReplyInputWrapper extends StatefulWidget {
  const _ReplyInputWrapper({
    required this.parentCommentId,
    required this.parentAuthorPubkey,
    required this.isPosting,
  });

  final String parentCommentId;
  final String parentAuthorPubkey;
  final bool isPosting;

  @override
  State<_ReplyInputWrapper> createState() => _ReplyInputWrapperState();
}

class _ReplyInputWrapperState extends State<_ReplyInputWrapper> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final state = context.read<CommentsBloc>().state;
    _controller = TextEditingController(text: state.replyInputText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommentsBloc, CommentsState>(
      buildWhen: (prev, next) => prev.replyInputText != next.replyInputText,
      builder: (context, state) {
        final currentText = state.replyInputText;

        // Sync controller with state (for when state changes externally,
        // e.g., after post clears the text)
        if (_controller.text != currentText) {
          _controller.text = currentText;
          _controller.selection = TextSelection.collapsed(
            offset: currentText.length,
          );
        }

        return CommentsReplyInput(
          controller: _controller,
          isPosting: widget.isPosting,
          onChanged: (text) {
            context.read<CommentsBloc>().add(
              CommentTextChanged(text, commentId: widget.parentCommentId),
            );
          },
          onSubmit: () {
            context.read<CommentsBloc>().add(
              CommentSubmitted(
                parentCommentId: widget.parentCommentId,
                parentAuthorPubkey: widget.parentAuthorPubkey,
              ),
            );
          },
        );
      },
    );
  }
}

/// Shows "Re: npub..." indicator for replies
/// Non-interactive, purely informational display
class _ReplyIndicator extends ConsumerWidget {
  const _ReplyIndicator({required this.parentAuthorPubkey});

  final String parentAuthorPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Encode to npub format
    final npub = NostrKeyUtils.encodePubKey(parentAuthorPubkey);

    // Truncate npub for display (first 15 chars + ellipsis)
    // Example: "npub1m6cxcq0..."
    final displayNpub = npub.length > 15 ? '${npub.substring(0, 15)}...' : npub;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Re: ',
          style: const TextStyle(
            color: Color(0xFF27C58B), // VineTheme.tabIndicatorGreen
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.4,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0e2b21), // Dark green background
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            displayNpub,
            style: const TextStyle(
              color: Color(0xFF27C58B), // Green text
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}
