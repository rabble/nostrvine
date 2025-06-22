// ABOUTME: Screen for displaying and posting comments on videos with threaded reply support
// ABOUTME: Uses Nostr Kind 1 events for comments with proper e/p tags for threading

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_event.dart';
import '../providers/comments_provider.dart';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import '../widgets/user_avatar.dart';

class CommentsScreen extends StatefulWidget {
  final VideoEvent videoEvent;

  const CommentsScreen({
    super.key,
    required this.videoEvent,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _commentController = TextEditingController();
  final _replyControllers = <String, TextEditingController>{};
  String? _replyingToCommentId;
  bool _isPosting = false;
  late CommentsProvider _commentsProvider;
  late SocialService _socialService;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _socialService = context.read<SocialService>();
    _authService = context.read<AuthService>();
    _commentsProvider = CommentsProvider(
      socialService: _socialService,
      authService: _authService,
      rootEventId: widget.videoEvent.id,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    _commentsProvider.dispose();
    super.dispose();
  }

  Future<void> _postComment({String? replyToId}) async {
    final controller = replyToId != null 
        ? _replyControllers[replyToId] 
        : _commentController;
    
    if (controller == null || controller.text.trim().isEmpty) return;
    
    setState(() => _isPosting = true);
    
    try {
      await _socialService.postComment(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: ChangeNotifierProvider.value(
              value: _commentsProvider,
              child: Consumer<CommentsProvider>(
                builder: (context, provider, child) {
                  if (provider.state.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  
                  if (provider.state.error != null) {
                    return Center(
                      child: Text(
                        'Error loading comments: ${provider.state.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  
                  if (provider.state.topLevelComments.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet.\nBe the first to comment!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: provider.state.topLevelComments.length,
                    itemBuilder: (context, index) {
                      return _buildCommentThread(provider.state.topLevelComments[index]);
                    },
                  );
                },
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentThread(CommentNode node, {int depth = 0}) {
    final comment = node.comment;
    final isReplying = _replyingToCommentId == comment.id;
    
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
                  UserAvatar(
                    name: comment.shortAuthorPubkey,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.shortAuthorPubkey,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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
                    Text(
                      comment.content,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_replyingToCommentId == comment.id) {
                                _replyingToCommentId = null;
                              } else {
                                _replyingToCommentId = comment.id;
                                _replyControllers[comment.id] ??= TextEditingController();
                              }
                            });
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
              if (isReplying) _buildReplyInput(comment.id),
            ],
          ),
        ),
        ...node.replies.map((reply) => _buildCommentThread(reply, depth: depth + 1)),
      ],
    );
  }

  Widget _buildReplyInput(String parentId) {
    final controller = _replyControllers[parentId]!;
    
    return Container(
      margin: const EdgeInsets.only(left: 44, top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Write a reply...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
          ),
          IconButton(
            onPressed: _isPosting ? null : () => _postComment(replyToId: parentId),
            icon: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
          ),
          IconButton(
            onPressed: _isPosting ? null : () => _postComment(),
            icon: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}