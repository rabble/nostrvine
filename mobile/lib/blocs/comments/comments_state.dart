// ABOUTME: State class for the CommentsBloc
// ABOUTME: Represents all possible states of the comments display and input

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

/// Immutable comment tree node for organizing threaded comments.
///
/// Wraps a repository Comment with its replies for tree traversal.
class CommentNode extends Equatable {
  const CommentNode({required this.comment, this.replies = const []});

  final repo.Comment comment;
  final List<CommentNode> replies;

  /// Get total reply count including nested replies
  int get totalReplyCount {
    var count = replies.length;
    for (final reply in replies) {
      count += reply.totalReplyCount;
    }
    return count;
  }

  /// Create a copy with updated fields
  CommentNode copyWith({repo.Comment? comment, List<CommentNode>? replies}) =>
      CommentNode(
        comment: comment ?? this.comment,
        replies: replies ?? this.replies,
      );

  @override
  List<Object?> get props => [comment, replies];
}

/// State class for the CommentsBloc
final class CommentsState extends Equatable {
  const CommentsState({
    this.status = CommentsStatus.initial,
    this.rootEventId = '',
    this.rootAuthorPubkey = '',
    this.topLevelComments = const [],
    this.totalCommentCount = 0,
    this.error,
    this.mainInputText = '',
    this.replyInputTexts = const {},
    this.activeReplyCommentId,
    this.isPosting = false,
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

  /// Error message if status is failure
  final String? error;

  /// Text content of the main comment input
  final String mainInputText;

  /// Map of comment ID -> reply text for each active reply
  final Map<String, String> replyInputTexts;

  /// ID of the comment currently being replied to (shows reply input)
  final String? activeReplyCommentId;

  /// Whether a comment is currently being posted (main or reply)
  final bool isPosting;

  /// Check if we're posting a reply to a specific comment
  bool isReplyPosting(String commentId) =>
      isPosting && activeReplyCommentId == commentId;

  /// Get the reply text for a specific comment
  String getReplyText(String commentId) => replyInputTexts[commentId] ?? '';

  /// Create a copy with updated values
  CommentsState copyWith({
    CommentsStatus? status,
    String? rootEventId,
    String? rootAuthorPubkey,
    List<CommentNode>? topLevelComments,
    int? totalCommentCount,
    String? error,
    bool clearError = false,
    String? mainInputText,
    Map<String, String>? replyInputTexts,
    String? activeReplyCommentId,
    bool clearActiveReply = false,
    bool? isPosting,
  }) {
    return CommentsState(
      status: status ?? this.status,
      rootEventId: rootEventId ?? this.rootEventId,
      rootAuthorPubkey: rootAuthorPubkey ?? this.rootAuthorPubkey,
      topLevelComments: topLevelComments ?? this.topLevelComments,
      totalCommentCount: totalCommentCount ?? this.totalCommentCount,
      error: clearError ? null : error,
      mainInputText: mainInputText ?? this.mainInputText,
      replyInputTexts: replyInputTexts ?? this.replyInputTexts,
      activeReplyCommentId: clearActiveReply
          ? null
          : (activeReplyCommentId ?? this.activeReplyCommentId),
      isPosting: isPosting ?? this.isPosting,
    );
  }

  @override
  List<Object?> get props => [
    status,
    rootEventId,
    rootAuthorPubkey,
    topLevelComments,
    totalCommentCount,
    error,
    mainInputText,
    replyInputTexts,
    activeReplyCommentId,
    isPosting,
  ];
}
