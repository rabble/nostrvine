// ABOUTME: Threaded comment widget with nested replies
// ABOUTME: Renders a comment with author info, content, and recursively renders replies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/comments_provider.dart';
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
  const CommentThread({
    required this.node,
    required this.replyingToCommentId,
    required this.replyControllers,
    required this.isPosting,
    required this.onReplyToggle,
    required this.onReplySubmit,
    this.depth = 0,
    super.key,
  });

  /// The comment node containing the comment and its replies.
  final CommentNode node;

  /// Current nesting depth for indentation (0 = top level).
  final int depth;

  /// ID of the comment currently being replied to, or null if none.
  final String? replyingToCommentId;

  /// Map of comment IDs to their reply text controllers.
  final Map<String, TextEditingController> replyControllers;

  /// Whether a comment/reply is currently being posted.
  final bool isPosting;

  /// Callback when the reply button is toggled for a comment.
  final void Function(String commentId) onReplyToggle;

  /// Callback when a reply should be submitted.
  final void Function(String parentId) onReplySubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comment = node.comment;
    final isReplying = replyingToCommentId == comment.id;

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
                          onPressed: () => onReplyToggle(comment.id),
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
                CommentsReplyInput(
                  controller: replyControllers[comment.id]!,
                  isPosting: isPosting,
                  onSubmit: () => onReplySubmit(comment.id),
                ),
            ],
          ),
        ),
        // Recursively render replies
        ...node.replies.map(
          (reply) => CommentThread(
            node: reply,
            depth: depth + 1,
            replyingToCommentId: replyingToCommentId,
            replyControllers: replyControllers,
            isPosting: isPosting,
            onReplyToggle: onReplyToggle,
            onReplySubmit: onReplySubmit,
          ),
        ),
      ],
    );
  }
}
