// ABOUTME: State class for the CommentInputCubit
// ABOUTME: Manages UI state for comment text input and reply mode

part of 'comment_input_cubit.dart';

/// State class for comment input UI
final class CommentInputState extends Equatable {
  const CommentInputState({
    this.mainInputText = '',
    this.replyInputTexts = const {},
    this.activeReplyCommentId,
    this.isMainPosting = false,
    this.postingReplyIds = const {},
    this.error,
  });

  /// Text content of the main comment input
  final String mainInputText;

  /// Map of comment ID -> reply text for each active reply
  final Map<String, String> replyInputTexts;

  /// ID of the comment currently being replied to (shows reply input)
  final String? activeReplyCommentId;

  /// Whether the main comment is currently being posted
  final bool isMainPosting;

  /// Set of comment IDs with replies currently being posted
  final Set<String> postingReplyIds;

  /// Last error that occurred, cleared on next action
  final String? error;

  /// Initial state
  static const CommentInputState initial = CommentInputState();

  /// Check if a specific reply is being posted
  bool isReplyPosting(String commentId) => postingReplyIds.contains(commentId);

  /// Check if any posting operation is in progress
  bool get isAnyPosting => isMainPosting || postingReplyIds.isNotEmpty;

  /// Get the reply text for a specific comment
  String getReplyText(String commentId) => replyInputTexts[commentId] ?? '';

  /// Create a copy with updated values
  CommentInputState copyWith({
    String? mainInputText,
    Map<String, String>? replyInputTexts,
    String? activeReplyCommentId,
    bool clearActiveReply = false,
    bool? isMainPosting,
    Set<String>? postingReplyIds,
    String? error,
    bool clearError = false,
  }) {
    return CommentInputState(
      mainInputText: mainInputText ?? this.mainInputText,
      replyInputTexts: replyInputTexts ?? this.replyInputTexts,
      activeReplyCommentId: clearActiveReply
          ? null
          : (activeReplyCommentId ?? this.activeReplyCommentId),
      isMainPosting: isMainPosting ?? this.isMainPosting,
      postingReplyIds: postingReplyIds ?? this.postingReplyIds,
      error: clearError ? null : error,
    );
  }

  @override
  List<Object?> get props => [
    mainInputText,
    replyInputTexts,
    activeReplyCommentId,
    isMainPosting,
    postingReplyIds,
    error,
  ];
}
