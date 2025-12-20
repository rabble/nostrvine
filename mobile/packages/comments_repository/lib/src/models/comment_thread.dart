// ABOUTME: Thread structure models for organizing comments hierarchically.
// ABOUTME: CommentThread contains top-level comments, CommentNode wraps each
// ABOUTME: comment with its replies for tree traversal.

import 'package:comments_repository/src/models/comment.dart';
import 'package:equatable/equatable.dart';

/// A node in the comment tree containing a comment and its replies.
///
/// Used to represent hierarchical comment threading where each comment
/// can have nested replies.
class CommentNode extends Equatable {
  /// Creates a new comment node.
  const CommentNode({
    required this.comment,
    this.replies = const [],
  });

  /// The comment at this node.
  final Comment comment;

  /// Direct replies to this comment.
  final List<CommentNode> replies;

  /// Total count of all replies including nested replies.
  int get totalReplyCount {
    var count = replies.length;
    for (final reply in replies) {
      count += reply.totalReplyCount;
    }
    return count;
  }

  /// Creates a copy with updated fields.
  CommentNode copyWith({
    Comment? comment,
    List<CommentNode>? replies,
  }) => CommentNode(
    comment: comment ?? this.comment,
    replies: replies ?? this.replies,
  );

  @override
  List<Object?> get props => [comment, replies];
}

/// A complete comment thread containing all comments for an event.
///
/// Comments are organized into a tree structure:
/// - `topLevelComments`: Root comments that directly reply to the main event
/// - Each `CommentNode` contains nested replies
class CommentThread extends Equatable {
  /// Creates a new comment thread.
  const CommentThread({
    required this.rootEventId,
    this.topLevelComments = const [],
    this.totalCount = 0,
    this.commentCache = const {},
  });

  /// Creates an empty thread for a given root event.
  const CommentThread.empty(this.rootEventId)
    : topLevelComments = const [],
      totalCount = 0,
      commentCache = const {};

  /// The ID of the root event these comments belong to.
  final String rootEventId;

  /// Top-level comments (direct replies to the root event).
  final List<CommentNode> topLevelComments;

  /// Total number of comments in the thread (including replies).
  final int totalCount;

  /// Cache of all comments by ID for quick lookup.
  final Map<String, Comment> commentCache;

  /// Whether the thread has any comments.
  bool get isEmpty => totalCount == 0;

  /// Whether the thread has comments.
  bool get isNotEmpty => totalCount > 0;

  /// Gets a comment by ID from the cache.
  Comment? getComment(String id) => commentCache[id];

  /// Creates a copy with updated fields.
  CommentThread copyWith({
    String? rootEventId,
    List<CommentNode>? topLevelComments,
    int? totalCount,
    Map<String, Comment>? commentCache,
  }) => CommentThread(
    rootEventId: rootEventId ?? this.rootEventId,
    topLevelComments: topLevelComments ?? this.topLevelComments,
    totalCount: totalCount ?? this.totalCount,
    commentCache: commentCache ?? this.commentCache,
  );

  @override
  List<Object?> get props => [
    rootEventId,
    topLevelComments,
    totalCount,
    commentCache,
  ];
}
