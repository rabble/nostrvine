// ABOUTME: BLoC for managing comments on videos with threaded replies
// ABOUTME: Handles loading, posting, likes, reporting, blocking, and sorting

import 'dart:math';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'comments_event.dart';
part 'comments_state.dart';

/// BLoC for managing comments on a video.
///
/// Handles:
/// - Loading comments from Nostr relays
/// - Organizing comments chronologically
/// - Managing input state for main comment and replies
/// - Posting new comments
/// - Liking/unliking comments
/// - Reporting comments and blocking users
/// - Sorting by newest, oldest, or top engagement
class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  CommentsBloc({
    required CommentsRepository commentsRepository,
    required AuthService authService,
    required LikesRepository likesRepository,
    required Future<ContentReportingService> contentReportingServiceFuture,
    required Future<MuteService> muteServiceFuture,
    required ContentBlocklistService contentBlocklistService,
    required String rootEventId,
    required int rootEventKind,
    required String rootAuthorPubkey,
    String? rootAddressableId,
    int? initialTotalCount,
    UserProfileService? userProfileService,
    FollowRepository? followRepository,
  }) : _commentsRepository = commentsRepository,
       _authService = authService,
       _likesRepository = likesRepository,
       _contentReportingServiceFuture = contentReportingServiceFuture,
       _muteServiceFuture = muteServiceFuture,
       _contentBlocklistService = contentBlocklistService,
       _initialTotalCount = initialTotalCount,
       _userProfileService = userProfileService,
       _followRepository = followRepository,
       super(
         CommentsState(
           rootEventId: rootEventId,
           rootEventKind: rootEventKind,
           rootAuthorPubkey: rootAuthorPubkey,
           rootAddressableId: rootAddressableId,
         ),
       ) {
    on<CommentsLoadRequested>(_onLoadRequested);
    on<CommentsLoadMoreRequested>(_onLoadMoreRequested);
    on<CommentTextChanged>(_onTextChanged);
    on<CommentReplyToggled>(_onReplyToggled);
    on<CommentSubmitted>(_onSubmitted);
    on<CommentErrorCleared>(_onErrorCleared);
    on<CommentDeleteRequested>(_onDeleteRequested);
    // droppable() prevents concurrent processing of the SAME event type,
    // but the manual likeInProgressCommentId guard (line 384) prevents
    // rapid toggles on DIFFERENT comment IDs from racing each other.
    on<CommentLikeToggled>(_onLikeToggled, transformer: droppable());
    on<CommentLikeCountsFetchRequested>(_onLikeCountsFetchRequested);
    on<CommentsSortModeChanged>(_onSortModeChanged);
    on<CommentReportRequested>(_onReportRequested, transformer: droppable());
    on<CommentBlockUserRequested>(
      _onBlockUserRequested,
      transformer: droppable(),
    );
    on<MentionSearchRequested>(
      _onMentionSearchRequested,
      transformer: restartable(),
    );
    on<MentionRegistered>(_onMentionRegistered);
    on<MentionSuggestionsCleared>(_onMentionSuggestionsCleared);
  }

  /// Page size for comment loading.
  static const _pageSize = 50;

  /// Optional initial total count from video metadata or interactions state.
  /// Used to accurately determine hasMoreContent instead of page size heuristic.
  final int? _initialTotalCount;

  final CommentsRepository _commentsRepository;
  final AuthService _authService;
  final LikesRepository _likesRepository;
  final Future<ContentReportingService> _contentReportingServiceFuture;
  final Future<MuteService> _muteServiceFuture;
  final ContentBlocklistService _contentBlocklistService;
  final UserProfileService? _userProfileService;
  final FollowRepository? _followRepository;

  Future<void> _onLoadRequested(
    CommentsLoadRequested event,
    Emitter<CommentsState> emit,
  ) async {
    if (state.status == CommentsStatus.loading) return;

    emit(state.copyWith(status: CommentsStatus.loading));

    try {
      final thread = await _commentsRepository.loadComments(
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
        rootAddressableId: state.rootAddressableId,
        limit: _pageSize,
      );

      // Convert to Map for O(1) deduplication on pagination
      final commentsById = {for (final c in thread.comments) c.id: c};

      // Determine if there are more comments to load:
      // 1. If we have a known total count, compare loaded count to it
      // 2. Otherwise, use page size heuristic (if we got a full page, there might be more)
      final hasMore = _initialTotalCount != null
          ? thread.comments.length < _initialTotalCount
          : thread.comments.length >= _pageSize;

      emit(
        state.copyWith(
          status: CommentsStatus.success,
          commentsById: commentsById,
          hasMoreContent: hasMore,
          replyCountsByCommentId: _computeReplyCounts(commentsById),
        ),
      );

      add(const CommentLikeCountsFetchRequested());
    } catch (e) {
      Log.error(
        'Error loading comments: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          status: CommentsStatus.failure,
          error: CommentsError.loadFailed,
        ),
      );
    }
  }

  Future<void> _onLoadMoreRequested(
    CommentsLoadMoreRequested event,
    Emitter<CommentsState> emit,
  ) async {
    // Skip if not in success state, already loading more, or no more content
    if (state.status != CommentsStatus.success ||
        state.isLoadingMore ||
        !state.hasMoreContent ||
        state.commentsById.isEmpty) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      // Get the oldest comment's timestamp as cursor for pagination
      // Note: Nostr `until` filter is inclusive, so we may get duplicates
      // which are automatically deduplicated by the Map
      final oldestComment = state.comments.last;
      final cursor = oldestComment.createdAt;

      Log.info(
        'Loading more comments before $cursor',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );

      final thread = await _commentsRepository.loadComments(
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
        rootAddressableId: state.rootAddressableId,
        limit: _pageSize,
        before: cursor,
      );

      // Merge new comments into the Map - duplicates are automatically replaced
      // This handles the edge case where multiple comments have the same timestamp
      final allCommentsById = {
        ...state.commentsById,
        for (final c in thread.comments) c.id: c,
      };

      // Determine if there are more comments to load:
      // 1. If we have a known total count, compare loaded count to it
      // 2. Otherwise, use page size heuristic (if we got a full page, there might be more)
      final hasMore = _initialTotalCount != null
          ? allCommentsById.length < _initialTotalCount
          : thread.comments.length >= _pageSize;

      emit(
        state.copyWith(
          commentsById: allCommentsById,
          isLoadingMore: false,
          hasMoreContent: hasMore,
          replyCountsByCommentId: _computeReplyCounts(allCommentsById),
        ),
      );

      add(const CommentLikeCountsFetchRequested());

      Log.info(
        'Loaded ${thread.comments.length} more comments '
        '(total: ${allCommentsById.length}, hasMore: $hasMore)',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );
    } catch (e) {
      Log.error(
        'Error loading more comments: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  void _onTextChanged(CommentTextChanged event, Emitter<CommentsState> emit) {
    if (event.commentId == null) {
      emit(state.copyWith(mainInputText: event.text));
    } else {
      emit(state.copyWith(replyInputText: event.text));
    }
  }

  void _onReplyToggled(CommentReplyToggled event, Emitter<CommentsState> emit) {
    if (state.activeReplyCommentId == event.commentId) {
      emit(state.clearActiveReply());
    } else {
      emit(
        state.copyWith(
          activeReplyCommentId: event.commentId,
          replyInputText: '',
        ),
      );
    }
  }

  Future<void> _onSubmitted(
    CommentSubmitted event,
    Emitter<CommentsState> emit,
  ) async {
    final isReply = event.parentCommentId != null;
    var text = isReply
        ? state.replyInputText.trim()
        : state.mainInputText.trim();

    if (text.isEmpty) return;

    if (!_authService.isAuthenticated) {
      emit(state.copyWith(error: CommentsError.notAuthenticated));
      return;
    }

    // Convert @displayName mentions to nostr:npub format
    if (state.activeMentions.isNotEmpty) {
      // Sort by display name length descending to prevent partial replacements
      final sortedEntries = state.activeMentions.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));
      for (final entry in sortedEntries) {
        text = text.replaceAll('@${entry.key}', 'nostr:${entry.value}');
      }
    }

    emit(state.copyWith(isPosting: true));

    try {
      final postedComment = await _commentsRepository.postComment(
        content: text,
        rootEventId: state.rootEventId,
        rootEventKind: state.rootEventKind,
        rootEventAuthorPubkey: state.rootAuthorPubkey,
        rootAddressableId: state.rootAddressableId,
        replyToEventId: event.parentCommentId,
        replyToAuthorPubkey: event.parentAuthorPubkey,
      );

      // Add new comment to the Map
      final updatedCommentsById = {
        ...state.commentsById,
        postedComment.id: postedComment,
      };

      if (isReply) {
        emit(
          state.clearActiveReply(
            commentsById: updatedCommentsById,
            isPosting: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            commentsById: updatedCommentsById,
            mainInputText: '',
            isPosting: false,
            activeMentions: const {},
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Error posting comment: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );

      emit(
        state.copyWith(
          isPosting: false,
          error: isReply
              ? CommentsError.postReplyFailed
              : CommentsError.postCommentFailed,
        ),
      );
    }
  }

  void _onErrorCleared(CommentErrorCleared event, Emitter<CommentsState> emit) {
    emit(state.copyWith());
  }

  Future<void> _onDeleteRequested(
    CommentDeleteRequested event,
    Emitter<CommentsState> emit,
  ) async {
    if (!_authService.isAuthenticated) {
      emit(state.copyWith(error: CommentsError.notAuthenticated));
      return;
    }

    try {
      await _commentsRepository.deleteComment(commentId: event.commentId);

      // Remove the comment from the Map
      final updatedCommentsById = Map<String, Comment>.from(state.commentsById)
        ..remove(event.commentId);

      emit(
        state.copyWith(
          commentsById: updatedCommentsById,
          replyCountsByCommentId: _computeReplyCounts(updatedCommentsById),
        ),
      );
    } catch (e) {
      Log.error(
        'Error deleting comment: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );

      emit(state.copyWith(error: CommentsError.deleteCommentFailed));
    }
  }

  Future<void> _onLikeCountsFetchRequested(
    CommentLikeCountsFetchRequested event,
    Emitter<CommentsState> emit,
  ) async {
    if (state.commentsById.isEmpty) return;

    try {
      final commentIds = state.commentsById.keys.toList();
      final counts = await _likesRepository.getLikeCounts(commentIds);

      // Check which comments the current user has liked (parallelized)
      final likedResults = await Future.wait(
        commentIds.map(
          (id) async => (id: id, liked: await _likesRepository.isLiked(id)),
        ),
      );
      final likedIds = <String>{};
      for (final result in likedResults) {
        if (result.liked) likedIds.add(result.id);
      }

      emit(
        state.copyWith(commentLikeCounts: counts, likedCommentIds: likedIds),
      );
    } catch (e) {
      Log.error(
        'Error fetching comment like counts: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );
    }
  }

  Future<void> _onLikeToggled(
    CommentLikeToggled event,
    Emitter<CommentsState> emit,
  ) async {
    if (!_authService.isAuthenticated) {
      emit(state.copyWith(error: CommentsError.notAuthenticated));
      return;
    }

    // Prevent double-tap on the same comment
    if (state.likeInProgressCommentId == event.commentId) return;

    final wasLiked = state.likedCommentIds.contains(event.commentId);
    final previousCount = state.commentLikeCounts[event.commentId] ?? 0;

    // Optimistic update
    final optimisticLikedIds = Set<String>.from(state.likedCommentIds);
    final optimisticCounts = Map<String, int>.from(state.commentLikeCounts);

    if (wasLiked) {
      optimisticLikedIds.remove(event.commentId);
      optimisticCounts[event.commentId] = max(0, previousCount - 1);
    } else {
      optimisticLikedIds.add(event.commentId);
      optimisticCounts[event.commentId] = previousCount + 1;
    }

    emit(
      state.copyWith(
        likedCommentIds: optimisticLikedIds,
        commentLikeCounts: optimisticCounts,
        likeInProgressCommentId: event.commentId,
      ),
    );

    try {
      await _likesRepository.toggleLike(
        eventId: event.commentId,
        authorPubkey: event.authorPubkey,
        targetKind: EventKind.comment,
      );

      // Clear in-progress guard: copyWith() without likeInProgressCommentId
      // passes null, intentionally resetting the guard.
      emit(state.copyWith());
    } catch (e) {
      Log.error(
        'Error toggling comment like: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );

      // Revert optimistic update
      final revertedLikedIds = Set<String>.from(state.likedCommentIds);
      final revertedCounts = Map<String, int>.from(state.commentLikeCounts);

      if (wasLiked) {
        revertedLikedIds.add(event.commentId);
        revertedCounts[event.commentId] = previousCount;
      } else {
        revertedLikedIds.remove(event.commentId);
        revertedCounts[event.commentId] = previousCount;
      }

      emit(
        state.copyWith(
          likedCommentIds: revertedLikedIds,
          commentLikeCounts: revertedCounts,
          error: CommentsError.likeFailed,
        ),
      );
    }
  }

  void _onSortModeChanged(
    CommentsSortModeChanged event,
    Emitter<CommentsState> emit,
  ) {
    emit(state.copyWith(sortMode: event.sortMode));
  }

  Future<void> _onReportRequested(
    CommentReportRequested event,
    Emitter<CommentsState> emit,
  ) async {
    try {
      final reportingService = await _contentReportingServiceFuture;
      await reportingService.reportContent(
        eventId: event.commentId,
        authorPubkey: event.authorPubkey,
        reason: event.reason,
        details: event.details,
      );
    } catch (e) {
      Log.error(
        'Error reporting comment: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(error: CommentsError.reportFailed));
    }
  }

  Future<void> _onBlockUserRequested(
    CommentBlockUserRequested event,
    Emitter<CommentsState> emit,
  ) async {
    try {
      // Publish mute list update to relays
      final muteService = await _muteServiceFuture;
      await muteService.muteUser(event.authorPubkey);

      // Block locally for immediate runtime filtering
      _contentBlocklistService.blockUser(event.authorPubkey);

      // Remove all comments by the blocked user
      final updatedCommentsById = Map<String, Comment>.from(state.commentsById)
        ..removeWhere(
          (_, comment) => comment.authorPubkey == event.authorPubkey,
        );

      emit(
        state.copyWith(
          commentsById: updatedCommentsById,
          replyCountsByCommentId: _computeReplyCounts(updatedCommentsById),
        ),
      );
    } catch (e) {
      Log.error(
        'Error blocking user: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(error: CommentsError.blockFailed));
    }
  }

  Future<void> _onMentionSearchRequested(
    MentionSearchRequested event,
    Emitter<CommentsState> emit,
  ) async {
    final query = event.query.toLowerCase();
    if (query.isEmpty) {
      emit(state.copyWith(mentionQuery: '', mentionSuggestions: []));
      return;
    }

    // Tier 1: Instant local search from known pubkeys
    final seen = <String>{};
    final suggestions = <MentionSuggestion>[];

    // Collect candidate pubkeys: video author + comment participants + following
    final candidatePubkeys = <String>[];

    // Video author first (priority)
    if (state.rootAuthorPubkey.isNotEmpty) {
      candidatePubkeys.add(state.rootAuthorPubkey);
    }

    // Comment participants
    for (final comment in state.commentsById.values) {
      candidatePubkeys.add(comment.authorPubkey);
    }

    // Following list
    final followingPubkeys = _followRepository?.followingPubkeys ?? [];
    candidatePubkeys.addAll(followingPubkeys);

    // Filter by query match on cached profile names
    for (final pubkey in candidatePubkeys) {
      if (seen.contains(pubkey)) continue;
      seen.add(pubkey);

      final profile = _userProfileService?.getCachedProfile(pubkey);
      final displayName = profile?.displayName ?? profile?.name;

      // Match query against display name (case-insensitive contains)
      if (displayName != null && displayName.toLowerCase().contains(query)) {
        suggestions.add(
          MentionSuggestion(
            pubkey: pubkey,
            displayName: displayName,
            picture: profile?.picture,
          ),
        );
      }

      if (suggestions.length >= 5) break;
    }

    emit(
      state.copyWith(
        mentionQuery: query,
        mentionSuggestions: suggestions.take(5).toList(),
      ),
    );

    // Tier 2: Async remote search if <5 local results
    if (suggestions.length < 5 && _userProfileService != null) {
      try {
        final remoteResults = await _userProfileService.searchUsers(
          query,
          limit: 10,
        );

        // Merge with local results, deduplicating by pubkey
        final mergedSuggestions = List<MentionSuggestion>.from(suggestions);
        for (final profile in remoteResults) {
          if (seen.contains(profile.pubkey)) continue;
          seen.add(profile.pubkey);

          final name = profile.displayName ?? profile.name;
          if (name == null) continue;

          mergedSuggestions.add(
            MentionSuggestion(
              pubkey: profile.pubkey,
              displayName: name,
              picture: profile.picture,
            ),
          );

          if (mergedSuggestions.length >= 5) break;
        }

        emit(
          state.copyWith(
            mentionQuery: query,
            mentionSuggestions: mergedSuggestions.take(5).toList(),
          ),
        );
      } catch (e) {
        // Tier 2 failure is non-fatal; local results remain visible
        Log.warning(
          'Mention search failed: $e',
          name: 'CommentsBloc',
          category: LogCategory.ui,
        );
      }
    }
  }

  void _onMentionRegistered(
    MentionRegistered event,
    Emitter<CommentsState> emit,
  ) {
    final updatedMentions = Map<String, String>.from(state.activeMentions)
      ..[event.displayName] = event.npub;
    emit(state.copyWith(activeMentions: updatedMentions));
  }

  void _onMentionSuggestionsCleared(
    MentionSuggestionsCleared event,
    Emitter<CommentsState> emit,
  ) {
    emit(state.copyWith(mentionQuery: '', mentionSuggestions: []));
  }

  /// Computes an engagement score for ranking comments.
  ///
  /// Score = (likes + replies*2) / (ageHours + 2)^1.2
  /// Higher scores indicate more engaging, recent content.
  @visibleForTesting
  static double engagementScore({
    required Comment comment,
    required DateTime now,
    required Map<String, int> likeCounts,
    required Map<String, int> replyCounts,
  }) {
    final likes = likeCounts[comment.id] ?? 0;
    final replies = replyCounts[comment.id] ?? 0;
    final engagement = likes + (replies * 2);
    final ageHours = now.difference(comment.createdAt).inMinutes / 60.0;
    return engagement / pow(ageHours + 2, 1.2);
  }

  /// Computes reply counts per comment ID from a comments map.
  /// Returns a map of comment ID → number of replies targeting it.
  static Map<String, int> _computeReplyCounts(
    Map<String, Comment> commentsById,
  ) {
    final counts = <String, int>{};
    for (final comment in commentsById.values) {
      final parentId = comment.replyToEventId;
      if (parentId != null && parentId.isNotEmpty) {
        counts[parentId] = (counts[parentId] ?? 0) + 1;
      }
    }
    return counts;
  }
}
