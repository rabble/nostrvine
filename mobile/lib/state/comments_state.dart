// ABOUTME: Equatable state models for comments feature
// ABOUTME: Immutable CommentNode and CommentsState for proper state management

import 'package:equatable/equatable.dart';
import 'package:openvine/models/comment.dart';

/// Immutable comment tree node for organizing threaded comments
class CommentNode extends Equatable {
  const CommentNode({
    required this.comment,
    this.replies = const [],
    this.isExpanded = true,
  });

  final Comment comment;
  final List<CommentNode> replies;
  final bool isExpanded;

  /// Get total reply count including nested replies
  int get totalReplyCount {
    var count = replies.length;
    for (final reply in replies) {
      count += reply.totalReplyCount;
    }
    return count;
  }

  /// Create a copy with updated fields
  CommentNode copyWith({
    Comment? comment,
    List<CommentNode>? replies,
    bool? isExpanded,
  }) => CommentNode(
    comment: comment ?? this.comment,
    replies: replies ?? this.replies,
    isExpanded: isExpanded ?? this.isExpanded,
  );

  @override
  List<Object?> get props => [comment, replies, isExpanded];
}

/// Immutable state class for managing comments for a specific video
class CommentsState extends Equatable {
  const CommentsState({
    required this.rootEventId,
    this.topLevelComments = const [],
    this.isLoading = false,
    this.error,
    this.totalCommentCount = 0,
    this.commentCache = const {},
  });

  /// Initial state factory
  factory CommentsState.initial(String rootEventId) =>
      CommentsState(rootEventId: rootEventId);

  final String rootEventId;
  final List<CommentNode> topLevelComments;
  final bool isLoading;
  final String? error;
  final int totalCommentCount;
  final Map<String, Comment> commentCache;

  /// Create a copy with updated fields
  CommentsState copyWith({
    List<CommentNode>? topLevelComments,
    bool? isLoading,
    String? error,
    int? totalCommentCount,
    Map<String, Comment>? commentCache,
  }) => CommentsState(
    rootEventId: rootEventId,
    topLevelComments: topLevelComments ?? this.topLevelComments,
    isLoading: isLoading ?? this.isLoading,
    error: error,
    totalCommentCount: totalCommentCount ?? this.totalCommentCount,
    commentCache: commentCache ?? this.commentCache,
  );

  @override
  List<Object?> get props => [
    rootEventId,
    topLevelComments,
    isLoading,
    error,
    totalCommentCount,
    commentCache,
  ];
}
