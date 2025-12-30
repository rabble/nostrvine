// ABOUTME: Repository for managing comments (Kind 1111 NIP-22) on Nostr.
// ABOUTME: Provides loading, posting, and streaming of threaded comments.
// ABOUTME: Uses NostrClient for relay operations and builds thread trees.

import 'package:comments_repository/src/exceptions.dart';
import 'package:comments_repository/src/models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:rxdart/rxdart.dart';

/// Kind 1111 is the NIP-22 comment kind for replying to non-Kind-1 events.
const int _commentKind = EventKind.comment;

/// Kind 5 is the NIP-09 deletion request kind.
const int _deletionKind = EventKind.eventDeletion;

/// Default limit for comment queries.
const _defaultLimit = 100;

/// Repository for managing comments (Kind 1111 NIP-22) on Nostr events.
///
/// This repository provides a unified interface for:
/// - Loading comments with thread structure
/// - Watching real-time comment streams
/// - Posting new comments and replies
/// - Counting comments on events
///
/// Comments use NIP-22 threading with uppercase/lowercase tags:
/// - Uppercase tags (`E`, `K`, `P`): Point to the root scope (e.g., video)
/// - Lowercase tags (`e`, `k`, `p`): Point to the parent item (for replies)
class CommentsRepository {
  /// Creates a new comments repository.
  ///
  /// Parameters:
  /// - [nostrClient]: Client for Nostr relay communication (handles signing)
  CommentsRepository({
    required NostrClient nostrClient,
  }) : _nostrClient = nostrClient;

  final NostrClient _nostrClient;

  /// Loads comments for a root event and returns a threaded structure.
  ///
  /// This is a one-shot query that returns all comments organized into
  /// a tree structure based on reply relationships.
  ///
  /// Parameters:
  /// - [rootEventId]: The ID of the event to load comments for
  /// - [rootEventKind]: The kind of the root event (e.g., 34236 for videos)
  /// - [limit]: Maximum number of comments to fetch (default: 100)
  ///
  /// Returns a [CommentThread] containing:
  /// - Top-level comments (direct replies to root)
  /// - Nested replies organized under their parent comments
  /// - Total comment count
  ///
  /// Throws [LoadCommentsFailedException] if the query fails.
  Future<CommentThread> loadComments({
    required String rootEventId,
    required int rootEventKind,
    int limit = _defaultLimit,
  }) async {
    try {
      // NIP-22: Filter by Kind 1111 and uppercase E tag for root scope
      final filter = Filter(
        kinds: const [_commentKind],
        uppercaseE: [rootEventId],
        limit: limit,
      );

      final events = await _nostrClient.queryEvents([filter]);
      return _buildThreadFromEvents(events, rootEventId, rootEventKind);
    } on Exception catch (e) {
      throw LoadCommentsFailedException('Failed to load comments: $e');
    }
  }

  /// Watches comments for a root event with real-time updates.
  ///
  /// Returns a stream that emits [CommentThread] whenever new comments
  /// arrive. The stream uses a scan operator to accumulate comments
  /// and rebuild the thread structure as new events arrive.
  ///
  /// Parameters:
  /// - [rootEventId]: The ID of the event to watch comments for
  /// - [rootEventKind]: The kind of the root event (e.g., 34236 for videos)
  /// - [limit]: Maximum number of comments to fetch (default: 100)
  ///
  /// Note: Stream management (deduplication, cleanup) is handled by
  /// NostrClient. Use [NostrClient.unsubscribe] to stop watching.
  Stream<CommentThread> watchComments({
    required String rootEventId,
    required int rootEventKind,
    int limit = _defaultLimit,
  }) {
    // NIP-22: Filter by Kind 1111 and uppercase E tag for root scope
    final filter = Filter(
      kinds: const [_commentKind],
      uppercaseE: [rootEventId],
      limit: limit,
    );

    // NostrClient handles subscription deduplication internally
    return _nostrClient
        .subscribe([filter])
        .map((event) => _eventToComment(event, rootEventId, rootEventKind))
        .whereNotNull()
        .scan<Map<String, Comment>>(
          (accumulated, comment, _) => {...accumulated, comment.id: comment},
          <String, Comment>{},
        )
        .map((commentMap) => _buildThreadFromComments(commentMap, rootEventId))
        .startWith(CommentThread.empty(rootEventId));
  }

  /// Posts a new comment using NIP-22 format.
  ///
  /// Creates a Kind 1111 event with proper NIP-22 threading tags
  /// and broadcasts it to relays.
  ///
  /// Parameters:
  /// - [content]: The comment text
  /// - [rootEventId]: The ID of the root event (e.g., video)
  /// - [rootEventKind]: The kind of the root event (e.g., 34236)
  /// - [rootEventAuthorPubkey]: Public key of the root event author
  /// - [replyToEventId]: ID of parent comment (for nested replies)
  /// - [replyToAuthorPubkey]: Public key of parent comment author
  ///
  /// Returns the created [Comment] with its event ID.
  ///
  /// Throws [InvalidCommentContentException] if content is empty.
  /// Throws [PostCommentFailedException] if broadcasting fails.
  Future<Comment> postComment({
    required String content,
    required String rootEventId,
    required int rootEventKind,
    required String rootEventAuthorPubkey,
    String? replyToEventId,
    String? replyToAuthorPubkey,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw const InvalidCommentContentException('Comment cannot be empty');
    }

    // Build tags for NIP-22 threading
    // Uppercase tags point to root scope, lowercase to parent item
    final tags = <List<String>>[
      // Root scope tags (uppercase) - always point to the original event
      ['E', rootEventId, '', rootEventAuthorPubkey],
      ['K', rootEventKind.toString()],
      ['P', rootEventAuthorPubkey],
      // Parent item tags (lowercase)
      if (replyToEventId != null && replyToAuthorPubkey != null) ...[
        // Replying to another comment
        ['e', replyToEventId, '', replyToAuthorPubkey],
        ['k', _commentKind.toString()],
        ['p', replyToAuthorPubkey],
      ] else ...[
        // Top-level comment - parent is the same as root
        ['e', rootEventId, '', rootEventAuthorPubkey],
        ['k', rootEventKind.toString()],
        ['p', rootEventAuthorPubkey],
      ],
    ];

    // Create the event
    final event = Event(
      _nostrClient.publicKey,
      _commentKind,
      tags,
      trimmedContent,
    );

    try {
      // Broadcast the event (NostrClient handles signing)
      final sentEvent = await _nostrClient.publishEvent(event);

      if (sentEvent == null) {
        throw const PostCommentFailedException('Failed to publish comment');
      }

      return Comment(
        id: sentEvent.id,
        content: trimmedContent,
        authorPubkey: sentEvent.pubkey,
        createdAt: event.createdAtDateTime,
        rootEventId: rootEventId,
        rootAuthorPubkey: rootEventAuthorPubkey,
        replyToEventId: replyToEventId,
        replyToAuthorPubkey: replyToAuthorPubkey,
      );
    } on CommentsRepositoryException {
      rethrow;
    } on Exception catch (e) {
      throw PostCommentFailedException('Failed to post comment: $e');
    }
  }

  /// Gets the comment count for an event.
  ///
  /// Uses NIP-45 COUNT requests if supported by relays,
  /// otherwise falls back to querying and counting.
  ///
  /// Parameters:
  /// - [rootEventId]: The ID of the event to count comments for
  ///
  /// Returns the number of comments on the event.
  ///
  /// Throws [CountCommentsFailedException] if counting fails.
  Future<int> getCommentsCount(String rootEventId) async {
    try {
      // NIP-22: Filter by Kind 1111 and uppercase E tag
      final filter = Filter(
        kinds: const [_commentKind],
        uppercaseE: [rootEventId],
      );

      final result = await _nostrClient.countEvents([filter]);
      return result.count;
    } on Exception catch (e) {
      throw CountCommentsFailedException('Failed to count comments: $e');
    }
  }

  /// Deletes a comment by publishing a NIP-09 deletion request.
  ///
  /// Creates a Kind 5 event with an `e` tag referencing the comment
  /// and a `k` tag specifying the comment kind (1111).
  ///
  /// Parameters:
  /// - [commentId]: The ID of the comment event to delete
  /// - [reason]: Optional reason for the deletion
  ///
  /// Throws [DeleteCommentFailedException] if broadcasting fails.
  Future<void> deleteComment({
    required String commentId,
    String? reason,
  }) async {
    try {
      // NIP-09: Build deletion request tags
      final tags = <List<String>>[
        ['e', commentId],
        ['k', _commentKind.toString()],
      ];

      final event = Event(
        _nostrClient.publicKey,
        _deletionKind,
        tags,
        reason ?? '',
      );

      final sentEvent = await _nostrClient.publishEvent(event);
      if (sentEvent == null) {
        throw const DeleteCommentFailedException(
          'Failed to publish deletion request',
        );
      }
    } on CommentsRepositoryException {
      rethrow;
    } on Exception catch (e) {
      throw DeleteCommentFailedException('Failed to delete comment: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Converts a Nostr event to a Comment model using NIP-22 format.
  Comment? _eventToComment(Event event, String rootEventId, int rootEventKind) {
    try {
      String? parsedRootEventId;
      String? replyToEventId;
      String? rootAuthorPubkey;
      String? replyToAuthorPubkey;
      String? parentKind;

      // Parse NIP-22 tags to determine comment relationships
      // Uppercase tags (E, K, P) = root scope
      // Lowercase tags (e, k, p) = parent item
      for (final rawTag in event.tags) {
        final tag = rawTag as List<dynamic>;
        if (tag.length < 2) continue;

        final tagType = tag[0] as String;
        final tagValue = tag[1] as String;

        switch (tagType) {
          case 'E':
            // Root event ID (uppercase = root scope)
            parsedRootEventId = tagValue;
            if (tag.length >= 4) {
              rootAuthorPubkey = tag[3] as String;
            }
          case 'P':
            // Root author pubkey (uppercase = root scope)
            rootAuthorPubkey ??= tagValue;
          case 'e':
            // Parent event ID (lowercase = parent item)
            replyToEventId = tagValue;
            if (tag.length >= 4) {
              replyToAuthorPubkey = tag[3] as String;
            }
          case 'k':
            // Parent kind (lowercase = parent item)
            parentKind = tagValue;
          case 'p':
            // Parent author pubkey (lowercase = parent item)
            replyToAuthorPubkey ??= tagValue;
        }
      }

      // Determine if this is a top-level comment or a reply
      // If parent kind equals root kind, it's a top-level comment
      final isTopLevel =
          parentKind == rootEventKind.toString() ||
          replyToEventId == parsedRootEventId;

      return Comment(
        id: event.id,
        content: event.content,
        authorPubkey: event.pubkey,
        createdAt: event.createdAtDateTime,
        rootEventId: parsedRootEventId ?? rootEventId,
        // For top-level comments, replyToEventId should be null
        replyToEventId: isTopLevel ? null : replyToEventId,
        rootAuthorPubkey: rootAuthorPubkey ?? '',
        replyToAuthorPubkey: isTopLevel ? null : replyToAuthorPubkey,
      );
    } on Exception {
      return null;
    }
  }

  /// Builds a CommentThread from a list of Nostr events.
  CommentThread _buildThreadFromEvents(
    List<Event> events,
    String rootEventId,
    int rootEventKind,
  ) {
    final commentMap = <String, Comment>{};

    for (final event in events) {
      final comment = _eventToComment(event, rootEventId, rootEventKind);
      if (comment != null) {
        commentMap[comment.id] = comment;
      }
    }

    return _buildThreadFromComments(commentMap, rootEventId);
  }

  /// Builds a CommentThread from a map of comments.
  ///
  /// Creates placeholder nodes for missing parent comments to preserve
  /// thread structure when replies are received but their parents are not.
  CommentThread _buildThreadFromComments(
    Map<String, Comment> commentMap,
    String rootEventId,
  ) {
    if (commentMap.isEmpty) {
      return CommentThread.empty(rootEventId);
    }

    // Track missing parent IDs that need placeholder nodes
    final missingParentIds = <String>{};

    // Build a map of parent comment ID -> child comment IDs
    final childrenMap = <String, List<String>>{};
    final topLevelIds = <String>[];

    for (final comment in commentMap.values) {
      final replyTo = comment.replyToEventId;
      if (replyTo == null || replyTo == rootEventId) {
        // Top-level comment (direct reply to root)
        topLevelIds.add(comment.id);
      } else if (!commentMap.containsKey(replyTo)) {
        // Parent not found - track it for placeholder creation
        missingParentIds.add(replyTo);
        (childrenMap[replyTo] ??= []).add(comment.id);
      } else {
        // Nested reply - add to parent's children list
        (childrenMap[replyTo] ??= []).add(comment.id);
      }
    }

    // Add missing parents to top-level (they'll be rendered as placeholders)
    topLevelIds.addAll(missingParentIds);

    // Cache for built nodes to avoid rebuilding
    final nodeCache = <String, CommentNode>{};

    // Recursively build a node and all its descendants
    CommentNode buildNode(String commentId) {
      // Return cached node if already built
      if (nodeCache.containsKey(commentId)) {
        return nodeCache[commentId]!;
      }

      final childIds = childrenMap[commentId] ?? <String>[];

      // Check if this is a missing parent (placeholder)
      final isMissing = missingParentIds.contains(commentId);
      final comment = isMissing
          ? _createPlaceholderComment(commentId, rootEventId)
          : commentMap[commentId]!;

      // Recursively build child nodes
      final replies = childIds.map(buildNode).toList()
        // Sort replies by time (oldest first for chronological reading)
        ..sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));

      final node = CommentNode(
        comment: comment,
        replies: replies,
        isNotFound: isMissing,
      );
      nodeCache[commentId] = node;
      return node;
    }

    // Build all top-level nodes (this recursively builds entire tree)
    final topLevel = topLevelIds.map(buildNode).toList()
      // Sort top-level by time (newest first)
      ..sort((a, b) => b.comment.createdAt.compareTo(a.comment.createdAt));

    return CommentThread(
      rootEventId: rootEventId,
      topLevelComments: topLevel,
      totalCount: commentMap.length,
      commentCache: Map<String, Comment>.unmodifiable(commentMap),
    );
  }

  /// Creates a placeholder comment for a missing parent.
  Comment _createPlaceholderComment(String commentId, String rootEventId) {
    return Comment(
      id: commentId,
      content: '',
      authorPubkey: '',
      createdAt: DateTime.now(),
      rootEventId: rootEventId,
      rootAuthorPubkey: '',
    );
  }

  // ---------------------------------------------------------------------------
  // Tree manipulation helpers
  // ---------------------------------------------------------------------------

  /// Handles a deleted comment in the tree.
  ///
  /// If the comment has replies, marks it as not found to preserve threading.
  /// If the comment has no replies, removes it completely.
  /// Also cleans up placeholder branches that no longer have real comments.
  List<CommentNode> markCommentAsNotFound(
    List<CommentNode> nodes,
    String commentId,
  ) {
    final result = <CommentNode>[];

    for (final node in nodes) {
      if (node.comment.id == commentId) {
        // Found the target comment
        if (node.replies.isNotEmpty) {
          // Has replies - keep as placeholder
          result.add(node.copyWith(isNotFound: true));
        }
        // No replies - skip (remove from tree)
      } else if (node.replies.isNotEmpty) {
        // Not the target - recurse into replies
        final updatedReplies = markCommentAsNotFound(node.replies, commentId);

        // If this is a placeholder and has no real comments below, remove it
        if (node.isNotFound && !_hasRealComments(updatedReplies)) {
          continue;
        }

        result.add(node.copyWith(replies: updatedReplies));
      } else {
        // Not the target and no replies - keep as is
        result.add(node);
      }
    }

    return result;
  }

  /// Checks if any node in the list (or their descendants) is a real comment.
  bool _hasRealComments(List<CommentNode> nodes) {
    for (final node in nodes) {
      if (!node.isNotFound) return true;
      if (_hasRealComments(node.replies)) return true;
    }
    return false;
  }
}
