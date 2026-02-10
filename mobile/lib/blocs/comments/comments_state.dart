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

  /// Failed to toggle like on a comment
  likeFailed,

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
    this.isPosting = false,
    this.isLoadingMore = false,
    this.hasMoreContent = true,
    this.commentLikeCounts = const {},
    this.likedCommentIds = const {},
    this.likeInProgressCommentId,
    this.sortMode = CommentsSortMode.newest,
    this.replyCountsByCommentId = const {},
    this.mentionQuery = '',
    this.mentionSuggestions = const [],
    this.activeMentions = const {},
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

  /// Like counts per comment ID.
  final Map<String, int> commentLikeCounts;

  /// Set of comment IDs the current user has liked.
  final Set<String> likedCommentIds;

  /// Comment ID currently undergoing a like toggle (prevents double-tap).
  final String? likeInProgressCommentId;

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

  /// All comments sorted according to [sortMode].
  List<Comment> get comments {
    final list = commentsById.values.toList();
    switch (sortMode) {
      case CommentsSortMode.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case CommentsSortMode.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case CommentsSortMode.topEngagement:
        final now = DateTime.now();
        list.sort((a, b) {
          final scoreA = CommentsBloc.engagementScore(
            comment: a,
            now: now,
            likeCounts: commentLikeCounts,
            replyCounts: replyCountsByCommentId,
          );
          final scoreB = CommentsBloc.engagementScore(
            comment: b,
            now: now,
            likeCounts: commentLikeCounts,
            replyCounts: replyCountsByCommentId,
          );
          return scoreB.compareTo(scoreA);
        });
    }
    return list;
  }

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

    // Sort function based on current sortMode
    int Function(Comment, Comment) sorter() {
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
              likeCounts: commentLikeCounts,
              replyCounts: replyCountsByCommentId,
            );
            final scoreB = CommentsBloc.engagementScore(
              comment: b,
              now: now,
              likeCounts: commentLikeCounts,
              replyCounts: replyCountsByCommentId,
            );
            return scoreB.compareTo(scoreA);
          };
      }
    }

    // Build tree recursively
    List<CommentNode> buildNodes(List<Comment> comments, int depth) {
      final sorted = List<Comment>.from(comments)..sort(sorter());
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

  /// Whether a comment is currently being posted (main or reply)
  final bool isPosting;

  /// Whether more comments are being loaded (pagination)
  final bool isLoadingMore;

  /// Whether there are more comments to load
  final bool hasMoreContent;

  /// Check if we're posting a reply to a specific comment
  bool isReplyPosting(String commentId) =>
      isPosting && activeReplyCommentId == commentId;

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
    bool? isPosting,
    bool? isLoadingMore,
    bool? hasMoreContent,
    Map<String, int>? commentLikeCounts,
    Set<String>? likedCommentIds,
    String? likeInProgressCommentId,
    CommentsSortMode? sortMode,
    Map<String, int>? replyCountsByCommentId,
    String? mentionQuery,
    List<MentionSuggestion>? mentionSuggestions,
    Map<String, String>? activeMentions,
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
      isPosting: isPosting ?? this.isPosting,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      commentLikeCounts: commentLikeCounts ?? this.commentLikeCounts,
      likedCommentIds: likedCommentIds ?? this.likedCommentIds,
      likeInProgressCommentId: likeInProgressCommentId,
      sortMode: sortMode ?? this.sortMode,
      replyCountsByCommentId:
          replyCountsByCommentId ?? this.replyCountsByCommentId,
      mentionQuery: mentionQuery ?? this.mentionQuery,
      mentionSuggestions: mentionSuggestions ?? this.mentionSuggestions,
      activeMentions: activeMentions ?? this.activeMentions,
    );
  }

  /// Creates a copy with the active reply cleared.
  /// Preserves like data, sort mode, and reply counts.
  CommentsState clearActiveReply({
    CommentsStatus? status,
    Map<String, Comment>? commentsById,
    bool? isPosting,
  }) {
    return CommentsState(
      status: status ?? this.status,
      rootEventId: rootEventId,
      rootEventKind: rootEventKind,
      rootAuthorPubkey: rootAuthorPubkey,
      rootAddressableId: rootAddressableId,
      commentsById: commentsById ?? this.commentsById,
      mainInputText: mainInputText,
      replyInputText: '',
      isPosting: isPosting ?? this.isPosting,
      isLoadingMore: isLoadingMore,
      hasMoreContent: hasMoreContent,
      commentLikeCounts: commentLikeCounts,
      likedCommentIds: likedCommentIds,
      sortMode: sortMode,
      replyCountsByCommentId: replyCountsByCommentId,
      mentionQuery: '',
      mentionSuggestions: const [],
      activeMentions: const {},
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
    isPosting,
    isLoadingMore,
    hasMoreContent,
    commentLikeCounts,
    likedCommentIds,
    likeInProgressCommentId,
    sortMode,
    replyCountsByCommentId,
    mentionQuery,
    mentionSuggestions,
    activeMentions,
  ];
}
