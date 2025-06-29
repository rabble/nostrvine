// ABOUTME: Provider for managing comment state including fetching, caching, and real-time updates
// ABOUTME: Handles comment threads, reply chains, and optimistic UI updates for video comments

import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import '../models/comment.dart';
import '../utils/unified_logger.dart';


/// Comment tree node for organizing threaded comments
class CommentNode {
  final Comment comment;
  final List<CommentNode> replies;
  bool isExpanded;
  
  CommentNode({
    required this.comment,
    List<CommentNode>? replies,
    this.isExpanded = true,
  }) : replies = replies ?? [];
  
  /// Get total reply count including nested replies
  int get totalReplyCount {
    int count = replies.length;
    for (final reply in replies) {
      count += reply.totalReplyCount;
    }
    return count;
  }
}

/// State class for managing comments for a specific video
class CommentsState {
  final String rootEventId;
  final List<CommentNode> topLevelComments;
  final bool isLoading;
  final String? error;
  final int totalCommentCount;
  final Map<String, Comment> commentCache;
  
  const CommentsState({
    required this.rootEventId,
    this.topLevelComments = const [],
    this.isLoading = false,
    this.error,
    this.totalCommentCount = 0,
    this.commentCache = const {},
  });
  
  CommentsState copyWith({
    List<CommentNode>? topLevelComments,
    bool? isLoading,
    String? error,
    int? totalCommentCount,
    Map<String, Comment>? commentCache,
  }) {
    return CommentsState(
      rootEventId: rootEventId,
      topLevelComments: topLevelComments ?? this.topLevelComments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      totalCommentCount: totalCommentCount ?? this.totalCommentCount,
      commentCache: commentCache ?? this.commentCache,
    );
  }
}

/// Provider for managing comments for a specific video
class CommentsProvider extends ChangeNotifier {
  final SocialService _socialService;
  final AuthService _authService;
  final String rootEventId;
  final String rootAuthorPubkey;
  
  CommentsState _state;
  
  CommentsProvider({
    required SocialService socialService,
    required AuthService authService,
    required this.rootEventId,
    required this.rootAuthorPubkey,
  }) : _socialService = socialService,
       _authService = authService,
       _state = CommentsState(rootEventId: rootEventId) {
    _loadComments();
  }
  
  CommentsState get state => _state;
  
  void _updateState(CommentsState newState) {
    _state = newState;
    notifyListeners();
  }
  
  /// Load comments for the video
  Future<void> _loadComments() async {
    if (state.isLoading) return;
    
    _updateState(_state.copyWith(isLoading: true, error: null));
    
    try {
      final commentsStream = _socialService.fetchCommentsForEvent(rootEventId);
      final Map<String, Comment> commentMap = {};
      final Map<String, List<String>> replyMap = {}; // parentId -> [childIds]
      
      await for (final event in commentsStream.take(100)) { // Limit to first 100 comments
        // Convert Nostr event to Comment model
        final comment = _eventToComment(event);
        if (comment != null) {
          commentMap[comment.id] = comment;
          
          // Track parent-child relationships
          if (comment.replyToEventId != null) {
            replyMap[comment.replyToEventId!] = 
                (replyMap[comment.replyToEventId!] ?? [])..add(comment.id);
          }
        }
      }
      
      // Build comment tree
      final topLevelComments = _buildCommentTree(commentMap, replyMap);
      
      _updateState(_state.copyWith(
        topLevelComments: topLevelComments,
        isLoading: false,
        totalCommentCount: commentMap.length,
        commentCache: commentMap,
      ));
      
    } catch (e) {
      Log.error('Error loading comments: $e', name: 'CommentsProvider', category: LogCategory.ui);
      _updateState(_state.copyWith(
        isLoading: false,
        error: 'Failed to load comments',
      ));
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
        rootEventId: rootEventId ?? this.rootEventId,
        replyToEventId: replyToEventId,
        rootAuthorPubkey: rootAuthorPubkey ?? '',
        replyToAuthorPubkey: replyToAuthorPubkey,
      );
    } catch (e) {
      Log.error('Error parsing comment event: $e', name: 'CommentsProvider', category: LogCategory.ui);
      return null;
    }
  }
  
  /// Build hierarchical comment tree from flat comment list
  List<CommentNode> _buildCommentTree(
    Map<String, Comment> commentMap,
    Map<String, List<String>> replyMap,
  ) {
    final List<CommentNode> topLevel = [];
    final Map<String, CommentNode> nodeMap = {};
    
    // Create nodes for all comments
    for (final comment in commentMap.values) {
      nodeMap[comment.id] = CommentNode(comment: comment);
    }
    
    // Build tree structure
    for (final comment in commentMap.values) {
      if (comment.replyToEventId == null || comment.replyToEventId == rootEventId) {
        // Top-level comment
        topLevel.add(nodeMap[comment.id]!);
      } else if (nodeMap.containsKey(comment.replyToEventId)) {
        // Add as reply to parent comment
        nodeMap[comment.replyToEventId]!.replies.add(nodeMap[comment.id]!);
      } else {
        // Parent comment not found, treat as top-level
        topLevel.add(nodeMap[comment.id]!);
      }
    }
    
    // Sort by creation time (newest first)
    topLevel.sort((a, b) => b.comment.createdAt.compareTo(a.comment.createdAt));
    
    // Sort replies recursively
    void sortReplies(CommentNode node) {
      node.replies.sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));
      for (final reply in node.replies) {
        sortReplies(reply);
      }
    }
    
    for (final node in topLevel) {
      sortReplies(node);
    }
    
    return topLevel;
  }
  
  /// Post a new comment
  Future<void> postComment({
    required String content,
    String? replyToEventId,
    String? replyToAuthorPubkey,
  }) async {
    if (!_authService.isAuthenticated) {
      _updateState(_state.copyWith(error: 'Please sign in to comment'));
      return;
    }
    
    if (content.trim().isEmpty) {
      _updateState(_state.copyWith(error: 'Comment cannot be empty'));
      return;
    }
    
    try {
      _updateState(_state.copyWith(error: null));
      
      // Get current user's public key for optimistic update
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey == null) {
        throw Exception('User public key not found');
      }
      
      // Create optimistic comment
      final optimisticComment = Comment(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        content: content,
        authorPubkey: currentUserPubkey,
        createdAt: DateTime.now(),
        rootEventId: rootEventId,
        replyToEventId: replyToEventId,
        rootAuthorPubkey: '', // Will be updated when event is broadcast
        replyToAuthorPubkey: replyToAuthorPubkey,
      );
      
      // Add optimistic comment to state
      final updatedCache = Map<String, Comment>.from(_state.commentCache);
      updatedCache[optimisticComment.id] = optimisticComment;
      
      // Add to tree structure
      List<CommentNode> updatedTopLevel;
      if (replyToEventId == null) {
        // Top-level comment
        updatedTopLevel = [
          CommentNode(comment: optimisticComment),
          ..._state.topLevelComments,
        ];
      } else {
        // Reply to existing comment
        updatedTopLevel = _addReplyToTree(
          _state.topLevelComments,
          optimisticComment,
          replyToEventId,
        );
      }
      
      _updateState(_state.copyWith(
        topLevelComments: updatedTopLevel,
        totalCommentCount: _state.totalCommentCount + 1,
        commentCache: updatedCache,
      ));
      
      // Use the root author pubkey passed to the provider
      
      // Post the actual comment
      await _socialService.postComment(
        content: content,
        rootEventId: rootEventId,
        rootEventAuthorPubkey: rootAuthorPubkey,
        replyToEventId: replyToEventId,
        replyToAuthorPubkey: replyToAuthorPubkey,
      );
      
      // Reload comments to get the real event ID
      await _loadComments();
      
    } catch (e) {
      Log.error('Error posting comment: $e', name: 'CommentsProvider', category: LogCategory.ui);
      _updateState(_state.copyWith(error: 'Failed to post comment'));
      
      // Remove optimistic comment on error
      await _loadComments();
    }
  }
  
  /// Add a reply to the comment tree
  List<CommentNode> _addReplyToTree(
    List<CommentNode> nodes,
    Comment reply,
    String parentId,
  ) {
    return nodes.map((node) {
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
  }
  
  /// Toggle expansion state of a comment node
  void toggleCommentExpansion(String commentId) {
    List<CommentNode> toggleInTree(List<CommentNode> nodes) {
      return nodes.map((node) {
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
    }
    
    _updateState(_state.copyWith(
      topLevelComments: toggleInTree(_state.topLevelComments),
    ));
  }
  
  /// Refresh comments
  Future<void> refresh() async {
    await _loadComments();
  }
  
  /// Get comment count for UI display
  int get commentCount => _state.totalCommentCount;
}