// ABOUTME: Comments list widget with loading, error, and empty states
// ABOUTME: Renders threaded comments using CommentThread widget

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/comments_provider.dart';
import 'package:openvine/screens/comments/widgets/comment_thread.dart';
import 'package:openvine/screens/comments/widgets/comments_empty_state.dart';

class CommentsList extends ConsumerWidget {
  const CommentsList({
    required this.videoEventId,
    required this.videoEventPubkey,
    required this.isOriginalVine,
    required this.scrollController,
    required this.replyingToCommentId,
    required this.replyControllers,
    required this.isPosting,
    required this.onReplyToggle,
    required this.onReplySubmit,
    super.key,
  });

  final String videoEventId;
  final String videoEventPubkey;
  final bool isOriginalVine;
  final ScrollController scrollController;
  final String? replyingToCommentId;
  final Map<String, TextEditingController> replyControllers;
  final bool isPosting;
  final void Function(String commentId) onReplyToggle;
  final void Function(String parentId) onReplySubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(commentsProvider(videoEventId, videoEventPubkey));

    if (state.isLoading) {
      return const _LoadingState();
    }

    if (state.error != null) {
      return _ErrorState(error: state.error!);
    }

    if (state.topLevelComments.isEmpty) {
      return CommentsEmptyState(isClassicVine: isOriginalVine);
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: state.topLevelComments.length,
      itemBuilder: (context, index) => CommentThread(
        node: state.topLevelComments[index],
        replyingToCommentId: replyingToCommentId,
        replyControllers: replyControllers,
        isPosting: isPosting,
        onReplyToggle: onReplyToggle,
        onReplySubmit: onReplySubmit,
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: Colors.white));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Error loading comments: $error',
      style: const TextStyle(color: Colors.red),
    ),
  );
}
