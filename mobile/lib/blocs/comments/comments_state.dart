// ABOUTME: State class for the CommentsBloc
// ABOUTME: Represents all possible states of the comments display and input

part of 'comments_bloc.dart';

/// A node in the comment tree, used for threaded display.
/// Not part of BLoC state (computed view model).
class CommentNode {
  const CommentNode({
    required this.comment,
    this.replies = const [],
    this.depth = 0,
  });

  /// The comment this node represents.
  final Comment comment;

  /// Child replies to this comment.
  final List<CommentNode> replies;

  /// Nesting depth (0 = root, 1 = reply, etc.).
  final int depth;
}

/// A mention suggestion for autocomplete.
class MentionSuggestion extends Equatable {
  const MentionSuggestion({
    required this.pubkey,
    this.displayName,
    this.picture,
  });

  /// The hex public key of the suggested user.
  final String pubkey;

  /// Optional display name (from cached profile).
  final String? displayName;

  /// Optional profile picture URL.
  final String? picture;

  @override
  List<Object?> get props => [pubkey, displayName, picture];
}

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

  /// Failed to toggle vote on a comment
  voteFailed,

  /// Failed to report a comment
  reportFailed,

  /// Failed to block a user
  blockFailed,
}

/// Sort mode for the comments list.
enum CommentsSortMode {
  /// Newest comments first (default)
  newest,

  /// Oldest comments first
  oldest,

  /// Top engagement: scored by likes + replies with time decay
  topEngagement,
}

/// State class for the CommentsBloc
///
/// Uses [repo.Comment] from the comments_repository package
/// to represent comments. This follows clean architecture
/// by keeping models in the repository layer.
final class CommentsState extends Equatable {
  const CommentsState({
    this.status = CommentsStatus.initial,
    this.rootEventId = '',
    this.rootEventKind = 0,
    this.rootAuthorPubkey = '',
    this.rootAddressableId,
    this.commentsById = const {},
    this.error,
    this.mainInputText = '',
    this.replyInputText = '',
    this.activeReplyCommentId,
    this.isLoadingMore = false,
    this.hasMoreContent = true,
    this.commentUpvoteCounts = const {},
    this.commentDownvoteCounts = const {},
    this.upvotedCommentIds = const {},
    this.downvotedCommentIds = const {},
    this.sortMode = CommentsSortMode.newest,
    this.replyCountsByCommentId = const {},
    this.mentionQuery = '',
    this.mentionSuggestions = const [],
    this.activeMentions = const {},
    this.activeEditCommentId,
    this.editInputText = '',
    this.newCommentCount = 0,
  });

  /// The current status of the comments
  final CommentsStatus status;

  /// The root event ID (video) for these comments
  final String rootEventId;

  /// The kind of the root event (e.g., 34236 for videos)
  final int rootEventKind;

  /// The author pubkey of the root event (video)
  final String rootAuthorPubkey;

  /// Optional addressable identifier for the root event (format: `kind:pubkey:d-tag`).
  /// Used for Kind 34236 addressable events to ensure comments can be found/created
  /// using both E and A tags.
  final String? rootAddressableId;

  /// Comments indexed by ID for O(1) deduplication.
  /// Uses [Comment] from the repository layer.
  final Map<String, Comment> commentsById;

  /// Upvote counts per comment ID.
  final Map<String, int> commentUpvoteCounts;

  /// Downvote counts per comment ID.
  final Map<String, int> commentDownvoteCounts;

  /// Set of comment IDs the current user has upvoted.
  final Set<String> upvotedCommentIds;

  /// Set of comment IDs the current user has downvoted.
  final Set<String> downvotedCommentIds;

  /// Current sort mode for the comments list.
  final CommentsSortMode sortMode;

  /// Pre-computed reply counts per comment ID.
  /// Updated whenever [commentsById] changes to avoid O(n^2) in getter.
  final Map<String, int> replyCountsByCommentId;

  /// Current @mention query text (after the @ symbol).
  final String mentionQuery;

  /// Mention suggestions for autocomplete overlay.
  final List<MentionSuggestion> mentionSuggestions;

  /// Active mention mappings: displayName -> npub.
  /// Populated when user selects a mention suggestion; consumed on submit
  /// to convert `@displayName` back to `nostr:npub` in the posted text.
  final Map<String, String> activeMentions;

  /// ID of the comment currently being edited (null = not editing).
  final String? activeEditCommentId;

  /// Text content of the edit input buffer.
  final String editInputText;

  /// Number of new comments received from the real-time subscription
  /// that the user has not yet acknowledged (scrolled to top / tapped pill).
  final int newCommentCount;

  /// Returns a comparator for sorting comments based on [sortMode].
  Comparator<Comment> get _commentComparator {
    switch (sortMode) {
      case CommentsSortMode.newest:
        return (a, b) => b.createdAt.compareTo(a.createdAt);
      case CommentsSortMode.oldest:
        return (a, b) => a.createdAt.compareTo(b.createdAt);
      case CommentsSortMode.topEngagement:
        final now = DateTime.now();
        return (a, b) {
          final scoreA = CommentsBloc.engagementScore(
            comment: a,
            now: now,
            likeCounts: commentUpvoteCounts,
            replyCounts: replyCountsByCommentId,
          );
          final scoreB = CommentsBloc.engagementScore(
            comment: b,
            now: now,
            likeCounts: commentUpvoteCounts,
            replyCounts: replyCountsByCommentId,
          );
          return scoreB.compareTo(scoreA);
        };
    }
  }

  /// All comments sorted according to [sortMode].
  List<Comment> get comments =>
      commentsById.values.toList()..sort(_commentComparator);

  /// Threaded comments as a flat display list with depth info.
  /// Root comments and orphaned replies appear at depth 0.
  List<CommentNode> get threadedComments {
    // Build children map: parentId -> list of child comments
    final childrenMap = <String, List<Comment>>{};
    final rootComments = <Comment>[];

    for (final comment in commentsById.values) {
      final parentId = comment.replyToEventId;
      if (parentId == null ||
          parentId.isEmpty ||
          !commentsById.containsKey(parentId)) {
        rootComments.add(comment);
      } else {
        childrenMap.putIfAbsent(parentId, () => []).add(comment);
      }
    }

    final sorter = _commentComparator;

    // Build tree recursively
    List<CommentNode> buildNodes(List<Comment> comments, int depth) {
      final sorted = List<Comment>.from(comments)..sort(sorter);
      return sorted.map((comment) {
        final children = childrenMap[comment.id] ?? [];
        return CommentNode(
          comment: comment,
          depth: depth,
          replies: buildNodes(children, depth + 1),
        );
      }).toList();
    }

    final roots = buildNodes(rootComments, 0);

    // Flatten tree using DFS
    final result = <CommentNode>[];
    void flatten(List<CommentNode> nodes) {
      for (final node in nodes) {
        result.add(node);
        flatten(node.replies);
      }
    }

    flatten(roots);
    return result;
  }

  /// Error type for l10n-friendly error handling.
  /// UI layer maps this to localized string via BlocListener.
  final CommentsError? error;

  /// Text content of the main comment input
  final String mainInputText;

  /// Text content of the active reply input
  final String replyInputText;

  /// ID of the comment currently being replied to (shows reply input)
  final String? activeReplyCommentId;

  /// Whether more comments are being loaded (pagination)
  final bool isLoadingMore;

  /// Whether there are more comments to load
  final bool hasMoreContent;

  /// Create a copy with updated values.
  CommentsState copyWith({
    CommentsStatus? status,
    String? rootEventId,
    int? rootEventKind,
    String? rootAuthorPubkey,
    String? rootAddressableId,
    Map<String, Comment>? commentsById,
    CommentsError? error,
    String? mainInputText,
    String? replyInputText,
    String? activeReplyCommentId,
    bool? isLoadingMore,
    bool? hasMoreContent,
    Map<String, int>? commentUpvoteCounts,
    Map<String, int>? commentDownvoteCounts,
    Set<String>? upvotedCommentIds,
    Set<String>? downvotedCommentIds,
    CommentsSortMode? sortMode,
    Map<String, int>? replyCountsByCommentId,
    String? mentionQuery,
    List<MentionSuggestion>? mentionSuggestions,
    Map<String, String>? activeMentions,
    String? activeEditCommentId,
    String? editInputText,
    int? newCommentCount,
  }) {
    return CommentsState(
      status: status ?? this.status,
      rootEventId: rootEventId ?? this.rootEventId,
      rootEventKind: rootEventKind ?? this.rootEventKind,
      rootAuthorPubkey: rootAuthorPubkey ?? this.rootAuthorPubkey,
      rootAddressableId: rootAddressableId ?? this.rootAddressableId,
      commentsById: commentsById ?? this.commentsById,
      error: error,
      mainInputText: mainInputText ?? this.mainInputText,
      replyInputText: replyInputText ?? this.replyInputText,
      activeReplyCommentId: activeReplyCommentId ?? this.activeReplyCommentId,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      commentUpvoteCounts: commentUpvoteCounts ?? this.commentUpvoteCounts,
      commentDownvoteCounts:
          commentDownvoteCounts ?? this.commentDownvoteCounts,
      upvotedCommentIds: upvotedCommentIds ?? this.upvotedCommentIds,
      downvotedCommentIds: downvotedCommentIds ?? this.downvotedCommentIds,
      sortMode: sortMode ?? this.sortMode,
      replyCountsByCommentId:
          replyCountsByCommentId ?? this.replyCountsByCommentId,
      mentionQuery: mentionQuery ?? this.mentionQuery,
      mentionSuggestions: mentionSuggestions ?? this.mentionSuggestions,
      activeMentions: activeMentions ?? this.activeMentions,
      activeEditCommentId: activeEditCommentId ?? this.activeEditCommentId,
      editInputText: editInputText ?? this.editInputText,
      newCommentCount: newCommentCount ?? this.newCommentCount,
    );
  }

  /// Creates a copy with the active reply cleared.
  /// Preserves vote data, sort mode, reply counts, and new comment count.
  CommentsState clearActiveReply({
    CommentsStatus? status,
    Map<String, Comment>? commentsById,
  }) {
    return CommentsState(
      status: status ?? this.status,
      rootEventId: rootEventId,
      rootEventKind: rootEventKind,
      rootAuthorPubkey: rootAuthorPubkey,
      rootAddressableId: rootAddressableId,
      commentsById: commentsById ?? this.commentsById,
      mainInputText: mainInputText,
      isLoadingMore: isLoadingMore,
      hasMoreContent: hasMoreContent,
      commentUpvoteCounts: commentUpvoteCounts,
      commentDownvoteCounts: commentDownvoteCounts,
      upvotedCommentIds: upvotedCommentIds,
      downvotedCommentIds: downvotedCommentIds,
      sortMode: sortMode,
      replyCountsByCommentId: replyCountsByCommentId,
      activeEditCommentId: activeEditCommentId,
      editInputText: editInputText,
      newCommentCount: newCommentCount,
    );
  }

  /// Creates a copy with edit mode cleared.
  /// Preserves all other state including vote data and reply state.
  CommentsState clearEditMode({
    CommentsStatus? status,
    Map<String, Comment>? commentsById,
    Map<String, int>? replyCountsByCommentId,
  }) {
    return CommentsState(
      status: status ?? this.status,
      rootEventId: rootEventId,
      rootEventKind: rootEventKind,
      rootAuthorPubkey: rootAuthorPubkey,
      rootAddressableId: rootAddressableId,
      commentsById: commentsById ?? this.commentsById,
      mainInputText: mainInputText,
      replyInputText: replyInputText,
      activeReplyCommentId: activeReplyCommentId,
      isLoadingMore: isLoadingMore,
      hasMoreContent: hasMoreContent,
      commentUpvoteCounts: commentUpvoteCounts,
      commentDownvoteCounts: commentDownvoteCounts,
      upvotedCommentIds: upvotedCommentIds,
      downvotedCommentIds: downvotedCommentIds,
      sortMode: sortMode,
      replyCountsByCommentId:
          replyCountsByCommentId ?? this.replyCountsByCommentId,
      mentionQuery: mentionQuery,
      mentionSuggestions: mentionSuggestions,
      activeMentions: activeMentions,
      newCommentCount: newCommentCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    rootEventId,
    rootEventKind,
    rootAuthorPubkey,
    rootAddressableId,
    commentsById,
    error,
    mainInputText,
    replyInputText,
    activeReplyCommentId,
    isLoadingMore,
    hasMoreContent,
    commentUpvoteCounts,
    commentDownvoteCounts,
    upvotedCommentIds,
    downvotedCommentIds,
    sortMode,
    replyCountsByCommentId,
    mentionQuery,
    mentionSuggestions,
    activeMentions,
    activeEditCommentId,
    editInputText,
    newCommentCount,
  ];
}
