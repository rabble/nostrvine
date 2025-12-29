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

  /// The kind of the root event (e.g., 34236 for videos)
  final int rootEventKind;

  /// The author pubkey of the root event (video)
  final String rootAuthorPubkey;

  /// Top-level comments organized as a tree.
  /// Uses [CommentNode] from the repository layer.
  final List<CommentNode> topLevelComments;

  /// Total count of all comments (including replies)
  final int totalCommentCount;

  /// Error type for l10n-friendly error handling.
  /// UI layer maps this to localized string via BlocListener.
  final CommentsError? error;

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
    int? rootEventKind,
    String? rootAuthorPubkey,
    List<CommentNode>? topLevelComments,
    int? totalCommentCount,
    CommentsError? error,
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
      rootEventKind: rootEventKind ?? this.rootEventKind,
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
    rootEventKind,
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
