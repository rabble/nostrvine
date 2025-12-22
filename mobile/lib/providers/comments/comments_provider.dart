// ABOUTME: Riverpod providers for managing comment state with reactive updates
// ABOUTME: Handles comment threads, reply chains, and optimistic UI updates using pure @riverpod functions

import 'dart:async';

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/comment.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/state/comments_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'comments_provider.g.dart';

/// Notifier for managing comments for a specific video
@riverpod
class CommentsNotifier extends _$CommentsNotifier {
  late String _rootEventId;
  late String _rootAuthorPubkey;

  @override
  CommentsState build(String rootEventId, String rootAuthorPubkey) {
    _rootEventId = rootEventId;
    _rootAuthorPubkey = rootAuthorPubkey;

    Log.debug(
      '💬 CommentsNotifier.build() called for event: $rootEventId',
      name: 'CommentsNotifier',
      category: LogCategory.ui,
    );

    // Load comments on initialization
    Future.microtask(() {
      Log.debug(
        '💬 Microtask executing _loadComments for event: $rootEventId',
        name: 'CommentsNotifier',
        category: LogCategory.ui,
      );
      _loadComments();
    });

    return CommentsState(rootEventId: rootEventId);
  }

  /// Load comments for the video
  Future<void> _loadComments() async {
    Log.debug(
      '💬 _loadComments() called for $_rootEventId, isLoading=${state.isLoading}',
      name: 'CommentsNotifier',
      category: LogCategory.ui,
    );

    if (state.isLoading) {
      Log.debug(
        '💬 _loadComments() returning early - already loading',
        name: 'CommentsNotifier',
        category: LogCategory.ui,
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    // Use Completer to track stream completion while updating UI reactively
    final completer = Completer<void>();

    try {
      Log.debug(
        '💬 About to get socialService and create subscription for $_rootEventId',
        name: 'CommentsNotifier',
        category: LogCategory.ui,
      );
      final socialService = ref.read(socialServiceProvider);
      final commentsStream = socialService.fetchCommentsForEvent(_rootEventId);
      final commentMap = <String, Comment>{};
      final replyMap = <String, List<String>>{}; // parentId -> [childIds]
      var hasReceivedFirstEvent = false;

      // Use listen() instead of await for to avoid blocking on stream completion
      // Nostr relays may not send EOSE, causing long waits with await for
      // Don't use .take() - let stream stay open for real-time comments
      Log.debug(
        '💬 Created comment subscription stream, listening...',
        name: 'CommentsNotifier',
        category: LogCategory.ui,
      );

      final subscription = commentsStream.listen(
        (event) {
          Log.debug(
            '💬 Received comment event: ${event.id}',
            name: 'CommentsNotifier',
            category: LogCategory.ui,
          );
          // Convert Nostr event to Comment model
          final comment = _eventToComment(event);
          if (comment != null) {
            commentMap[comment.id] = comment;

            // Track parent-child relationships
            if (comment.replyToEventId != null) {
              replyMap[comment.replyToEventId!] =
                  (replyMap[comment.replyToEventId!] ?? [])..add(comment.id);
            }

            // Update UI reactively as events arrive
            final topLevelComments = _buildCommentTree(commentMap, replyMap);
            state = state.copyWith(
              topLevelComments: topLevelComments,
              isLoading: false, // Stop loading after first event
              totalCommentCount: commentMap.length,
              commentCache: commentMap,
            );
            hasReceivedFirstEvent = true;
          }
        },
        onError: (e) {
          Log.error(
            'Error in comment stream: $e',
            name: 'CommentsNotifier',
            category: LogCategory.ui,
          );
          if (!hasReceivedFirstEvent) {
            state = state.copyWith(
              isLoading: false,
              error: 'Failed to load comments',
            );
          }
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        onDone: () {
          // Stream completed (timeout, error, or cancellation)
          Log.debug(
            'Comment stream completed for $_rootEventId',
            name: 'CommentsNotifier',
            category: LogCategory.ui,
          );
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Clean up subscription when provider is disposed
      ref.onDispose(() {
        subscription.cancel();
      });

      // Wait briefly for initial comments to arrive, then complete
      // This prevents waiting forever for stream completion while still
      // allowing real-time comments to arrive after initial load
      Future.delayed(const Duration(seconds: 3), () {
        Log.debug(
          '💬 3-second timeout fired. hasReceivedFirstEvent=$hasReceivedFirstEvent, completer.isCompleted=${completer.isCompleted}',
          name: 'CommentsNotifier',
          category: LogCategory.ui,
        );
        if (!hasReceivedFirstEvent && !completer.isCompleted) {
          // No comments received after waiting - show empty state
          Log.debug(
            '💬 No comments received after 3s, showing empty state for $_rootEventId',
            name: 'CommentsNotifier',
            category: LogCategory.ui,
          );
          state = state.copyWith(
            topLevelComments: [],
            isLoading: false,
            totalCommentCount: 0,
          );
          completer.complete();
        } else if (!completer.isCompleted) {
          // Comments received - complete to unblock function
          // Subscription continues listening for real-time updates
          completer.complete();
        }
      });

      await completer.future;
    } catch (e) {
      Log.error(
        'Error loading comments: $e',
        name: 'CommentsNotifier',
        category: LogCategory.ui,
      );
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load comments',
      );
    }
  }

  /// Convert Nostr event to Comment model
  Comment? _eventToComment(Event event) {
    try {
      String? rootEventId;
      String? replyToEventId;
      String? rootAuthorPubkey;
      String? replyToAuthorPubkey;

      // Parse tags to determine comment relationships
      for (final tag in event.tags) {
        if (tag.length < 2) continue;

        if (tag[0] == 'e') {
          // Event reference tag
          if (tag.length >= 4 && tag[3] == 'root') {
            rootEventId = tag[1];
          } else if (tag.length >= 4 && tag[3] == 'reply') {
            replyToEventId = tag[1];
          } else {
            // First e tag without marker is assumed to be root
            rootEventId ??= tag[1];
          }
        } else if (tag[0] == 'p') {
          // Pubkey reference tag
          if (rootAuthorPubkey == null) {
            rootAuthorPubkey = tag[1];
          } else {
            replyToAuthorPubkey = tag[1];
          }
        }
      }

      return Comment(
        id: event.id,
        content: event.content,
        authorPubkey: event.pubkey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
        rootEventId: rootEventId ?? _rootEventId,
        replyToEventId: replyToEventId,
        rootAuthorPubkey: rootAuthorPubkey ?? '',
        replyToAuthorPubkey: replyToAuthorPubkey,
      );
    } catch (e) {
      Log.error(
        'Error parsing comment event: $e',
        name: 'CommentsNotifier',
        category: LogCategory.ui,
      );
      return null;
    }
  }

  /// Build hierarchical comment tree from flat comment list
  List<CommentNode> _buildCommentTree(
    Map<String, Comment> commentMap,
    Map<String, List<String>> replyMap,
  ) {
    // Build child->parent and parent->children maps
    final childrenMap = <String, List<String>>{}; // parentId -> [childIds]
    final topLevelIds = <String>[];

    for (final comment in commentMap.values) {
      if (comment.replyToEventId == null ||
          comment.replyToEventId == _rootEventId ||
          !commentMap.containsKey(comment.replyToEventId)) {
        // Top-level comment (or orphaned reply)
        topLevelIds.add(comment.id);
      } else {
        // Child comment
        childrenMap[comment.replyToEventId!] =
            (childrenMap[comment.replyToEventId!] ?? [])..add(comment.id);
      }
    }

    // Recursively build immutable nodes from bottom up
    CommentNode buildNode(String commentId) {
      final comment = commentMap[commentId]!;
      final childIds = childrenMap[commentId] ?? [];

      // Build child nodes first, then sort by creation time (oldest first)
      final childNodes = childIds.map(buildNode).toList()
        ..sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));

      return CommentNode(comment: comment, replies: childNodes);
    }

    // Build top-level nodes and sort by creation time (newest first)
    return topLevelIds.map(buildNode).toList()
      ..sort((a, b) => b.comment.createdAt.compareTo(a.comment.createdAt));
  }

  /// Post a new comment
  Future<void> postComment({
    required String content,
    String? replyToEventId,
    String? replyToAuthorPubkey,
  }) async {
    final authService = ref.read(authServiceProvider);
    if (!authService.isAuthenticated) {
      state = state.copyWith(error: 'Please sign in to comment');
      return;
    }

    if (content.trim().isEmpty) {
      state = state.copyWith(error: 'Comment cannot be empty');
      return;
    }

    try {
      state = state.copyWith(error: null);

      // Get current user's public key for optimistic update
      final currentUserPubkey = authService.currentPublicKeyHex;
      if (currentUserPubkey == null) {
        throw Exception('User public key not found');
      }

      // Create optimistic comment
      final optimisticComment = Comment(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        content: content,
        authorPubkey: currentUserPubkey,
        createdAt: DateTime.now(),
        rootEventId: _rootEventId,
        replyToEventId: replyToEventId,
        rootAuthorPubkey: '', // Will be updated when event is broadcast
        replyToAuthorPubkey: replyToAuthorPubkey,
      );

      // Add optimistic comment to state
      final updatedCache = Map<String, Comment>.from(state.commentCache);
      updatedCache[optimisticComment.id] = optimisticComment;

      // Add to tree structure
      List<CommentNode> updatedTopLevel;
      if (replyToEventId == null) {
        // Top-level comment
        updatedTopLevel = [
          CommentNode(comment: optimisticComment),
          ...state.topLevelComments,
        ];
      } else {
        // Reply to existing comment
        updatedTopLevel = _addReplyToTree(
          state.topLevelComments,
          optimisticComment,
          replyToEventId,
        );
      }

      state = state.copyWith(
        topLevelComments: updatedTopLevel,
        totalCommentCount: state.totalCommentCount + 1,
        commentCache: updatedCache,
      );

      // Use the root author pubkey passed to the provider
      final socialService = ref.read(socialServiceProvider);

      // Post the actual comment
      await socialService.postComment(
        content: content,
        rootEventId: _rootEventId,
        rootEventAuthorPubkey: _rootAuthorPubkey,
        replyToEventId: replyToEventId,
        replyToAuthorPubkey: replyToAuthorPubkey,
      );

      // Check if provider is still mounted after async operation
      if (!ref.mounted) return;

      // Reload comments to get the real event ID
      await _loadComments();
    } catch (e) {
      Log.error(
        'Error posting comment: $e',
        name: 'CommentsNotifier',
        category: LogCategory.ui,
      );
      state = state.copyWith(error: 'Failed to post comment');

      // Remove optimistic comment on error
      await _loadComments();
    }
  }

  /// Add a reply to the comment tree
  List<CommentNode> _addReplyToTree(
    List<CommentNode> nodes,
    Comment reply,
    String parentId,
  ) => nodes.map((node) {
    if (node.comment.id == parentId) {
      // Found parent, add reply
      return CommentNode(
        comment: node.comment,
        replies: [
          CommentNode(comment: reply),
          ...node.replies,
        ],
        isExpanded: node.isExpanded,
      );
    } else if (node.replies.isNotEmpty) {
      // Recursively search in replies
      return CommentNode(
        comment: node.comment,
        replies: _addReplyToTree(node.replies, reply, parentId),
        isExpanded: node.isExpanded,
      );
    }
    return node;
  }).toList();

  /// Toggle expansion state of a comment node
  void toggleCommentExpansion(String commentId) {
    List<CommentNode> toggleInTree(List<CommentNode> nodes) =>
        nodes.map((node) {
          if (node.comment.id == commentId) {
            return CommentNode(
              comment: node.comment,
              replies: node.replies,
              isExpanded: !node.isExpanded,
            );
          } else if (node.replies.isNotEmpty) {
            return CommentNode(
              comment: node.comment,
              replies: toggleInTree(node.replies),
              isExpanded: node.isExpanded,
            );
          }
          return node;
        }).toList();

    state = state.copyWith(
      topLevelComments: toggleInTree(state.topLevelComments),
    );
  }

  /// Refresh comments
  Future<void> refresh() async {
    await _loadComments();
  }

  /// Get comment count for UI display
  int get commentCount => state.totalCommentCount;
}
