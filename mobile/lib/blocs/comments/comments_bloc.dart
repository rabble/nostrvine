// ABOUTME: BLoC for managing comments on videos with threaded replies
// ABOUTME: Handles loading, posting, and UI state for comments

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/comment.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'comments_event.dart';
part 'comments_state.dart';

/// BLoC for managing comments on a video.
///
/// Handles:
/// - Loading comments from Nostr relays
/// - Building hierarchical comment trees
/// - Posting new comments with optimistic updates
/// - Real-time comment updates via stream
class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  CommentsBloc({
    required SocialService socialService,
    required AuthService authService,
    required String rootEventId,
    required String rootAuthorPubkey,
  }) : _socialService = socialService,
       _authService = authService,
       super(
         CommentsState(
           rootEventId: rootEventId,
           rootAuthorPubkey: rootAuthorPubkey,
         ),
       ) {
    on<CommentsLoadRequested>(_onLoadRequested);
    on<CommentPostRequested>(_onPostRequested);
    on<CommentExpansionToggled>(_onExpansionToggled);
    on<_CommentReceived>(_onCommentReceived);
    on<_CommentsStreamCompleted>(_onStreamCompleted);
    on<_CommentsStreamError>(_onStreamError);
  }

  final SocialService _socialService;
  final AuthService _authService;

  StreamSubscription<Event>? _commentsSubscription;
  Timer? _timeoutTimer;

  final _commentMap = <String, Comment>{};
  final _replyMap = <String, List<String>>{}; // parentId -> [childIds]
  bool _hasReceivedFirstEvent = false;

  @override
  Future<void> close() {
    _commentsSubscription?.cancel();
    _timeoutTimer?.cancel();
    return super.close();
  }

  /// Handle request to load comments
  Future<void> _onLoadRequested(
    CommentsLoadRequested event,
    Emitter<CommentsState> emit,
  ) async {
    if (state.status == CommentsStatus.loading) return;

    emit(state.copyWith(status: CommentsStatus.loading, error: null));

    try {
      // Reset tracking state
      _commentMap.clear();
      _replyMap.clear();
      _hasReceivedFirstEvent = false;

      // Cancel any existing subscription
      await _commentsSubscription?.cancel();
      _timeoutTimer?.cancel();

      // Subscribe to comments stream
      final commentsStream = _socialService.fetchCommentsForEvent(
        state.rootEventId,
      );

      _commentsSubscription = commentsStream.listen(
        (nostrEvent) {
          final comment = _eventToComment(nostrEvent);
          if (comment != null) {
            add(_CommentReceived(comment));
          }
        },
        onError: (error) => add(_CommentsStreamError(error)),
        onDone: () => add(const _CommentsStreamCompleted()),
      );

      // Set timeout for initial load
      _timeoutTimer = Timer(const Duration(seconds: 3), () {
        if (!_hasReceivedFirstEvent) {
          add(const _CommentsStreamCompleted());
        }
      });
    } catch (e) {
      Log.error(
        'Error loading comments: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );
      emit(
        state.copyWith(
          status: CommentsStatus.failure,
          error: 'Failed to load comments',
        ),
      );
    }
  }

  /// Handle incoming comment from stream
  void _onCommentReceived(_CommentReceived event, Emitter<CommentsState> emit) {
    final comment = event.comment;
    _commentMap[comment.id] = comment;

    // Track parent-child relationships
    if (comment.replyToEventId != null) {
      _replyMap[comment.replyToEventId!] =
          (_replyMap[comment.replyToEventId!] ?? [])..add(comment.id);
    }

    // Rebuild tree and update state
    final topLevelComments = _buildCommentTree();
    emit(
      state.copyWith(
        status: CommentsStatus.success,
        topLevelComments: topLevelComments,
        totalCommentCount: _commentMap.length,
        commentCache: Map.from(_commentMap),
      ),
    );

    _hasReceivedFirstEvent = true;
  }

  /// Handle stream completion
  void _onStreamCompleted(
    _CommentsStreamCompleted event,
    Emitter<CommentsState> emit,
  ) {
    if (!_hasReceivedFirstEvent) {
      // No comments received - show empty state
      emit(
        state.copyWith(
          status: CommentsStatus.success,
          topLevelComments: [],
          totalCommentCount: 0,
        ),
      );
    }
    // If we already received events, keep the current state
  }

  /// Handle stream error
  void _onStreamError(_CommentsStreamError event, Emitter<CommentsState> emit) {
    Log.error(
      'Error in comment stream: ${event.error}',
      name: 'CommentsBloc',
      category: LogCategory.ui,
    );

    if (!_hasReceivedFirstEvent) {
      emit(
        state.copyWith(
          status: CommentsStatus.failure,
          error: 'Failed to load comments',
        ),
      );
    }
  }

  /// Handle post comment request
  Future<void> _onPostRequested(
    CommentPostRequested event,
    Emitter<CommentsState> emit,
  ) async {
    if (!_authService.isAuthenticated) {
      emit(state.copyWith(error: 'Please sign in to comment'));
      return;
    }

    final content = event.content.trim();
    if (content.isEmpty) {
      emit(state.copyWith(error: 'Comment cannot be empty'));
      return;
    }

    try {
      // Get current user pubkey for optimistic update
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey == null) {
        throw Exception('User public key not found');
      }

      // Create optimistic comment
      final optimisticComment = Comment(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        content: content,
        authorPubkey: currentUserPubkey,
        createdAt: DateTime.now(),
        rootEventId: state.rootEventId,
        replyToEventId: event.replyToEventId,
        rootAuthorPubkey: state.rootAuthorPubkey,
        replyToAuthorPubkey: event.replyToAuthorPubkey,
      );

      // Add optimistic comment
      _commentMap[optimisticComment.id] = optimisticComment;
      if (event.replyToEventId != null) {
        _replyMap[event.replyToEventId!] =
            (_replyMap[event.replyToEventId!] ?? [])..add(optimisticComment.id);
      }

      final topLevelComments = _buildCommentTree();
      emit(
        state.copyWith(
          topLevelComments: topLevelComments,
          totalCommentCount: _commentMap.length,
          commentCache: Map.from(_commentMap),
          error: null,
        ),
      );

      // Post the actual comment
      await _socialService.postComment(
        content: content,
        rootEventId: state.rootEventId,
        rootEventAuthorPubkey: state.rootAuthorPubkey,
        replyToEventId: event.replyToEventId,
        replyToAuthorPubkey: event.replyToAuthorPubkey,
      );

      // Reload to get the real event ID
      add(const CommentsLoadRequested());
    } catch (e) {
      Log.error(
        'Error posting comment: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );
      emit(state.copyWith(error: 'Failed to post comment'));

      // Reload to remove optimistic comment
      add(const CommentsLoadRequested());
    }
  }

  /// Handle expansion toggle
  void _onExpansionToggled(
    CommentExpansionToggled event,
    Emitter<CommentsState> emit,
  ) {
    final updatedComments = _toggleExpansionInTree(
      state.topLevelComments,
      event.commentId,
    );
    emit(state.copyWith(topLevelComments: updatedComments));
  }

  /// Convert Nostr event to Comment model
  Comment? _eventToComment(Event event) {
    try {
      String? rootEventId;
      String? replyToEventId;
      String? rootAuthorPubkey;
      String? replyToAuthorPubkey;

      // Parse tags to determine comment relationships
      for (final tag in event.tags) {
        if (tag.length < 2) continue;

        if (tag[0] == 'e') {
          // Event reference tag
          if (tag.length >= 4 && tag[3] == 'root') {
            rootEventId = tag[1];
          } else if (tag.length >= 4 && tag[3] == 'reply') {
            replyToEventId = tag[1];
          } else {
            // First e tag without marker is assumed to be root
            rootEventId ??= tag[1];
          }
        } else if (tag[0] == 'p') {
          // Pubkey reference tag
          if (rootAuthorPubkey == null) {
            rootAuthorPubkey = tag[1];
          } else {
            replyToAuthorPubkey = tag[1];
          }
        }
      }

      return Comment(
        id: event.id,
        content: event.content,
        authorPubkey: event.pubkey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
        rootEventId: rootEventId ?? state.rootEventId,
        replyToEventId: replyToEventId,
        rootAuthorPubkey: rootAuthorPubkey ?? '',
        replyToAuthorPubkey: replyToAuthorPubkey,
      );
    } catch (e) {
      Log.error(
        'Error parsing comment event: $e',
        name: 'CommentsBloc',
        category: LogCategory.ui,
      );
      return null;
    }
  }

  /// Build hierarchical comment tree from flat comment map
  List<CommentNode> _buildCommentTree() {
    final childrenMap = <String, List<String>>{}; // parentId -> [childIds]
    final topLevelIds = <String>[];

    for (final comment in _commentMap.values) {
      if (comment.replyToEventId == null ||
          comment.replyToEventId == state.rootEventId ||
          !_commentMap.containsKey(comment.replyToEventId)) {
        // Top-level comment (or orphaned reply)
        topLevelIds.add(comment.id);
      } else {
        // Child comment
        childrenMap[comment.replyToEventId!] =
            (childrenMap[comment.replyToEventId!] ?? [])..add(comment.id);
      }
    }

    // Recursively build nodes
    CommentNode buildNode(String commentId) {
      final comment = _commentMap[commentId]!;
      final childIds = childrenMap[commentId] ?? [];

      final childNodes = childIds.map(buildNode).toList()
        ..sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));

      return CommentNode(comment: comment, replies: childNodes);
    }

    // Build top-level nodes and sort (newest first)
    return topLevelIds.map(buildNode).toList()
      ..sort((a, b) => b.comment.createdAt.compareTo(a.comment.createdAt));
  }

  /// Toggle expansion in comment tree
  List<CommentNode> _toggleExpansionInTree(
    List<CommentNode> nodes,
    String commentId,
  ) {
    return nodes.map((node) {
      if (node.comment.id == commentId) {
        return node.copyWith(isExpanded: !node.isExpanded);
      } else if (node.replies.isNotEmpty) {
        return node.copyWith(
          replies: _toggleExpansionInTree(node.replies, commentId),
        );
      }
      return node;
    }).toList();
  }
}
