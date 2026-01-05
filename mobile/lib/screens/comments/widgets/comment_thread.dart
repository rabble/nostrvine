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
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

/// Widget that renders a single comment with all its nested replies.
///
/// Supports thread nesting with visual indentation based on [depth].
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
            margin: EdgeInsets.only(left: depth * 24.0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Text(
              '[Comment not found]',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ...node.replies.map(
            (reply) => CommentThread(node: reply, depth: depth + 1),
          ),
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
              margin: EdgeInsets.only(left: depth * 24.0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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

                          return UserAvatar(size: 32);
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) {
                            // Fetch profile for display name
                            final userProfileService = ref.watch(
                              userProfileServiceProvider,
                            );
                            final profile = userProfileService.getCachedProfile(
                              comment.authorPubkey,
                            );

                            const style = TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white54,
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    // Navigate to profile screen
                                    context.goProfileGrid(comment.authorPubkey);
                                  },
                                  child: profile == null
                                      ? const Text('Unknown', style: style)
                                      : UserName.fromUserProfile(
                                          profile,
                                          style: style,
                                        ),
                                ),
                                Text(
                                  comment.relativeTime,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      // 3-dot options menu (only visible for own comments)
                      Consumer(
                        builder: (context, ref, _) {
                          final nostrService = ref.watch(nostrServiceProvider);
                          final currentUserPubkey = nostrService.publicKey;
                          final isOwnComment =
                              currentUserPubkey.isNotEmpty &&
                              currentUserPubkey == comment.authorPubkey;

                          if (!isOwnComment) {
                            return const SizedBox.shrink();
                          }

                          return Semantics(
                            identifier: 'comment_options_button',
                            button: true,
                            label: 'Comment options',
                            child: IconButton(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white54,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                final shouldDelete =
                                    await CommentOptionsModal.show(context);
                                if (shouldDelete == true && context.mounted) {
                                  context.read<CommentsBloc>().add(
                                    CommentDeleteRequested(comment.id),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
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
              (reply) => CommentThread(node: reply, depth: depth + 1),
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
