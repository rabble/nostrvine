// ABOUTME: Screen for displaying and posting comments on videos with threaded reply support
// ABOUTME: Uses Nostr Kind 1 events for comments with proper e/p tags for threading

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/comments/widgets/comments.dart';

class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({
    required this.videoEvent,
    required this.sheetScrollController,
    super.key,
  });

  final VideoEvent videoEvent;
  final ScrollController sheetScrollController;

  /// Shows comments as a modal bottom sheet overlay
  static Future<void> show(BuildContext context, VideoEvent video) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) => DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: CommentsScreen(
              videoEvent: video,
              sheetScrollController: scrollController,
            ),
          ),
        ),
      );

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _commentController = TextEditingController();
  final _replyControllers = <String, TextEditingController>{};
  String? _replyingToCommentId;
  bool _isPosting = false;

  @override
  void dispose() {
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _postComment({String? replyToId}) async {
    final controller = replyToId != null
        ? _replyControllers[replyToId]
        : _commentController;

    if (controller == null || controller.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final socialService = ref.read(socialServiceProvider);
      await socialService.postComment(
        content: controller.text.trim(),
        rootEventId: widget.videoEvent.id,
        rootEventAuthorPubkey: widget.videoEvent.pubkey,
        replyToEventId: replyToId,
      );

      controller.clear();
      if (replyToId != null) {
        setState(() => _replyingToCommentId = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  void _handleReplyToggle(String commentId) {
    setState(() {
      if (_replyingToCommentId == commentId) {
        _replyingToCommentId = null;
      } else {
        _replyingToCommentId = commentId;
        _replyControllers[commentId] ??= TextEditingController();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const CommentsDragHandle(),
      CommentsHeader(onClose: () => Navigator.pop(context)),
      const Divider(color: Colors.white24, height: 1),
      Expanded(
        child: CommentsList(
          videoEventId: widget.videoEvent.id,
          videoEventPubkey: widget.videoEvent.pubkey,
          isOriginalVine: widget.videoEvent.isOriginalVine,
          scrollController: widget.sheetScrollController,
          replyingToCommentId: _replyingToCommentId,
          replyControllers: _replyControllers,
          isPosting: _isPosting,
          onReplyToggle: _handleReplyToggle,
          onReplySubmit: (parentId) => _postComment(replyToId: parentId),
        ),
      ),
      CommentInput(
        controller: _commentController,
        isPosting: _isPosting,
        onSubmit: _postComment,
      ),
    ],
  );
}
