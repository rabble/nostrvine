// ABOUTME: Threaded comment widget with nested replies
// ABOUTME: Renders a comment with author info, content, and recursively renders replies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/comments/comments.dart';
import 'package:openvine/providers/comments/comments_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/comments/widgets/comments_reply_input.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

/// Widget that renders a single comment with all its nested replies.
///
/// Supports thread nesting with visual indentation based on [depth].
/// Shows author avatar, name, timestamp, and content.
/// Includes a reply button that toggles an inline reply input.
class CommentThread extends ConsumerWidget {
  const CommentThread({required this.node, this.depth = 0, super.key});

  /// The comment node containing the comment and its replies.
  final CommentNode node;

  /// Current nesting depth for indentation (0 = top level).
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comment = node.comment;
    final inputState = ref.watch(currentCommentInputProvider);
    final isReplying = inputState.activeReplyCommentId == comment.id;
    final isPostingReply = inputState.isReplyPosting(comment.id);

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
                        TextButton(
                          onPressed: () {
                            ref
                                .read(currentCommentInputProvider.notifier)
                                .toggleReply(comment.id);
                          },
                          child: Text(
                            isReplying ? 'Cancel' : 'Reply',
                            style: const TextStyle(color: Colors.white70),
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
  }
}

/// Wrapper for reply input that manages its own TextEditingController
class _ReplyInputWrapper extends ConsumerStatefulWidget {
  const _ReplyInputWrapper({
    required this.parentCommentId,
    required this.parentAuthorPubkey,
    required this.isPosting,
  });

  final String parentCommentId;
  final String parentAuthorPubkey;
  final bool isPosting;

  @override
  ConsumerState<_ReplyInputWrapper> createState() => _ReplyInputWrapperState();
}

class _ReplyInputWrapperState extends ConsumerState<_ReplyInputWrapper> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final inputState = ref.read(currentCommentInputProvider);
    _controller = TextEditingController(
      text: inputState.getReplyText(widget.parentCommentId),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputState = ref.watch(currentCommentInputProvider);
    final currentText = inputState.getReplyText(widget.parentCommentId);

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
        ref
            .read(currentCommentInputProvider.notifier)
            .updateReplyText(widget.parentCommentId, text);
      },
      onSubmit: () {
        ref
            .read(currentCommentInputProvider.notifier)
            .postReply(widget.parentCommentId, widget.parentAuthorPubkey);
      },
    );
  }
}
