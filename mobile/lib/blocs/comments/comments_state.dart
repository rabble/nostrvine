// ABOUTME: State class for the CommentsBloc
// ABOUTME: Represents all possible states of the comments display

part of 'comments_bloc.dart';

/// Enum representing the status of the comments loading
enum CommentsStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently loading comments
  loading,

  /// Comments loaded successfully
  success,

  /// An error occurred while loading comments
  failure,
}

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

/// State class for the CommentsBloc
final class CommentsState extends Equatable {
  const CommentsState({
    this.status = CommentsStatus.initial,
    this.rootEventId = '',
    this.rootAuthorPubkey = '',
    this.topLevelComments = const [],
    this.totalCommentCount = 0,
    this.commentCache = const {},
    this.error,
  });

  /// The current status of the comments
  final CommentsStatus status;

  /// The root event ID (video) for these comments
  final String rootEventId;

  /// The author pubkey of the root event (video)
  final String rootAuthorPubkey;

  /// Top-level comments organized as a tree
  final List<CommentNode> topLevelComments;

  /// Total count of all comments (including replies)
  final int totalCommentCount;

  /// Cache of all comments by ID for quick lookup
  final Map<String, Comment> commentCache;

  /// Error message if status is failure
  final String? error;

  /// Create a copy with updated values
  CommentsState copyWith({
    CommentsStatus? status,
    String? rootEventId,
    String? rootAuthorPubkey,
    List<CommentNode>? topLevelComments,
    int? totalCommentCount,
    Map<String, Comment>? commentCache,
    String? error,
  }) {
    return CommentsState(
      status: status ?? this.status,
      rootEventId: rootEventId ?? this.rootEventId,
      rootAuthorPubkey: rootAuthorPubkey ?? this.rootAuthorPubkey,
      topLevelComments: topLevelComments ?? this.topLevelComments,
      totalCommentCount: totalCommentCount ?? this.totalCommentCount,
      commentCache: commentCache ?? this.commentCache,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    rootEventId,
    rootAuthorPubkey,
    topLevelComments,
    totalCommentCount,
    commentCache,
    error,
  ];
}
