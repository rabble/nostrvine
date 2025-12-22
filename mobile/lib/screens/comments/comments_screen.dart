// ABOUTME: Screen for displaying and posting comments on videos with threaded reply support
// ABOUTME: Uses Nostr Kind 1 events for comments with proper e/p tags for threading

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/comments_provider.dart';
import 'package:openvine/screens/comments/widgets/comments.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({required this.videoEvent, super.key});
  final VideoEvent videoEvent;

  /// Route path for go_router.
  static const String routePath = '/comments';

  /// Route name for go_router.
  static const String routeName = 'comments';

  /// Creates a GoRoute for this screen.
  static GoRoute routeBuilder() => GoRoute(
    path: routePath,
    name: routeName,
    builder: (ctx, st) {
      final video = st.extra as VideoEvent?;
      if (video == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: const Center(child: Text('No video selected')),
        );
      }
      return CommentsScreen(videoEvent: video);
    },
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        // Video in background (paused - autoplay disabled)
        VideoFeedItem(
          video: widget.videoEvent,
          index: 0,
          disableAutoplay: true,
        ),

        // Comments overlay
        DraggableScrollableSheet(
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
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Comments header
                CommentsHeader(onClose: () => Navigator.pop(context)),

                const Divider(color: Colors.white24, height: 1),

                // Comments list
                Expanded(child: _buildCommentsList(scrollController)),

                // Comment input
                CommentInput(
                  controller: _commentController,
                  isPosting: _isPosting,
                  onSubmit: _postComment,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildCommentsList(ScrollController scrollController) {
    final state = ref.watch(
      commentsProvider(widget.videoEvent.id, widget.videoEvent.pubkey),
    );

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (state.error != null) {
      return Center(
        child: Text(
          'Error loading comments: ${state.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (state.topLevelComments.isEmpty) {
      return CommentsEmptyState(
        isClassicVine: widget.videoEvent.isOriginalVine,
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: state.topLevelComments.length,
      itemBuilder: (context, index) => CommentThread(
        node: state.topLevelComments[index],
        replyingToCommentId: _replyingToCommentId,
        replyControllers: _replyControllers,
        isPosting: _isPosting,
        onReplyToggle: _handleReplyToggle,
        onReplySubmit: (parentId) => _postComment(replyToId: parentId),
      ),
    );
  }
}
