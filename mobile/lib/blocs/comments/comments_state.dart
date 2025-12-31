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

/// Error types for l10n-friendly error handling.
///
/// The UI layer should map these to localized strings via BlocListener.
enum CommentsError {
  /// Failed to load comments from relays
  loadFailed,

  /// User must sign in to post comments
  notAuthenticated,

  /// Failed to post a new top-level comment
  postCommentFailed,

  /// Failed to post a reply to a comment
  postReplyFailed,

  /// Failed to delete a comment
  deleteCommentFailed,
}

/// State class for the CommentsBloc
///
/// Uses [repo.CommentNode] from the comments_repository package
/// to represent threaded comments. This follows clean architecture
/// by keeping models in the repository layer.
final class CommentsState extends Equatable {
  const CommentsState({
    this.status = CommentsStatus.initial,
    this.rootEventId = '',
    this.rootEventKind = 0,
    this.rootAuthorPubkey = '',
    this.topLevelComments = const [],
    this.error,
    this.mainInputText = '',
    this.replyInputText = '',
    this.activeReplyCommentId,
    this.isPosting = false,
  });

  /// The current status of the comments
  final CommentsStatus status;

  /// The root event ID (video) for these comments
  final String rootEventId;

  /// The kind of the root event (e.g., 34236 for videos)
  final int rootEventKind;

  /// The author pubkey of the root event (video)
  final String rootAuthorPubkey;

  /// Top-level comments organized as a tree.
  /// Uses [CommentNode] from the repository layer.
  final List<CommentNode> topLevelComments;

  /// Error type for l10n-friendly error handling.
  /// UI layer maps this to localized string via BlocListener.
  final CommentsError? error;

  /// Text content of the main comment input
  final String mainInputText;

  /// Text content of the active reply input
  final String replyInputText;

  /// ID of the comment currently being replied to (shows reply input)
  final String? activeReplyCommentId;

  /// Whether a comment is currently being posted (main or reply)
  final bool isPosting;

  /// Check if we're posting a reply to a specific comment
  bool isReplyPosting(String commentId) =>
      isPosting && activeReplyCommentId == commentId;

  /// Create a copy with updated values.
  CommentsState copyWith({
    CommentsStatus? status,
    String? rootEventId,
    int? rootEventKind,
    String? rootAuthorPubkey,
    List<CommentNode>? topLevelComments,
    CommentsError? error,
    String? mainInputText,
    String? replyInputText,
    String? activeReplyCommentId,
    bool? isPosting,
  }) {
    return CommentsState(
      status: status ?? this.status,
      rootEventId: rootEventId ?? this.rootEventId,
      rootEventKind: rootEventKind ?? this.rootEventKind,
      rootAuthorPubkey: rootAuthorPubkey ?? this.rootAuthorPubkey,
      topLevelComments: topLevelComments ?? this.topLevelComments,
      error: error,
      mainInputText: mainInputText ?? this.mainInputText,
      replyInputText: replyInputText ?? this.replyInputText,
      activeReplyCommentId: activeReplyCommentId ?? this.activeReplyCommentId,
      isPosting: isPosting ?? this.isPosting,
    );
  }

  /// Creates a copy with the active reply cleared.
  CommentsState clearActiveReply({
    CommentsStatus? status,
    List<CommentNode>? topLevelComments,
    bool? isPosting,
  }) {
    return CommentsState(
      status: status ?? this.status,
      rootEventId: rootEventId,
      rootEventKind: rootEventKind,
      rootAuthorPubkey: rootAuthorPubkey,
      topLevelComments: topLevelComments ?? this.topLevelComments,
      mainInputText: mainInputText,
      replyInputText: '',
      isPosting: isPosting ?? this.isPosting,
    );
  }

  @override
  List<Object?> get props => [
    status,
    rootEventId,
    rootEventKind,
    rootAuthorPubkey,
    topLevelComments,
    error,
    mainInputText,
    replyInputText,
    activeReplyCommentId,
    isPosting,
  ];
}
