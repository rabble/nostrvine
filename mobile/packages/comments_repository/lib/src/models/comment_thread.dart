// ABOUTME: Thread structure model for organizing comments in a flat list.
// ABOUTME: CommentThread contains all comments chronologically ordered with
// ABOUTME: reply relationships maintained via replyToEventId fields.

import 'package:comments_repository/src/models/comment.dart';
import 'package:equatable/equatable.dart';

/// A complete comment thread containing all comments for an event.
///
/// Comments are organized in a flat list, chronologically ordered
/// (newest first).
/// Reply relationships are maintained through the Comment model's
/// replyToEventId field.
class CommentThread extends Equatable {
  /// Creates a new comment thread.
  const CommentThread({
    required this.rootEventId,
    this.comments = const [],
    this.totalCount = 0,
    this.commentCache = const {},
  });

  /// Creates an empty thread for a given root event.
  const CommentThread.empty(this.rootEventId)
    : comments = const [],
      totalCount = 0,
      commentCache = const {};

  /// The ID of the root event these comments belong to.
  final String rootEventId;

  /// All comments in chronological order (newest first).
  final List<Comment> comments;

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
    List<Comment>? comments,
    int? totalCount,
    Map<String, Comment>? commentCache,
  }) => CommentThread(
    rootEventId: rootEventId ?? this.rootEventId,
    comments: comments ?? this.comments,
    totalCount: totalCount ?? this.totalCount,
    commentCache: commentCache ?? this.commentCache,
  );

  @override
  List<Object?> get props => [
    rootEventId,
    comments,
    totalCount,
    commentCache,
  ];
}
