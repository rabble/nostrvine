// ABOUTME: Repository for managing comments (Kind 1 text notes) on Nostr.
// ABOUTME: Provides loading, posting, and streaming of threaded comments.
// ABOUTME: Uses NostrClient for relay operations and builds thread trees.

import 'package:comments_repository/src/exceptions.dart';
import 'package:comments_repository/src/models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:rxdart/rxdart.dart';

/// Kind 1 is the NIP-10 text note kind used for comments.
const int _textNoteKind = EventKind.textNote;

/// Default limit for comment queries.
const _defaultLimit = 100;

/// Repository for managing comments (Kind 1 text notes) on Nostr events.
///
/// This repository provides a unified interface for:
/// - Loading comments with thread structure
/// - Watching real-time comment streams
/// - Posting new comments and replies
/// - Counting comments on events
///
/// Comments use NIP-10 threading with `e` tags:
/// - `root` marker: Points to the original event (e.g., video)
/// - `reply` marker: Points to the parent comment for nested replies
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
    int limit = _defaultLimit,
  }) async {
    try {
      final filter = Filter(
        kinds: const [_textNoteKind],
        e: [rootEventId],
        limit: limit,
      );

      final events = await _nostrClient.queryEvents([filter]);
      return _buildThreadFromEvents(events, rootEventId);
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
  /// - [limit]: Maximum number of comments to fetch (default: 100)
  ///
  /// Note: Stream management (deduplication, cleanup) is handled by
  /// NostrClient. Use [NostrClient.unsubscribe] to stop watching.
  Stream<CommentThread> watchComments({
    required String rootEventId,
    int limit = _defaultLimit,
  }) {
    final filter = Filter(
      kinds: const [_textNoteKind],
      e: [rootEventId],
      limit: limit,
    );

    // NostrClient handles subscription deduplication internally
    return _nostrClient
        .subscribe([filter])
        .map((event) => _eventToComment(event, rootEventId))
        .whereNotNull()
        .scan<Map<String, Comment>>(
          (accumulated, comment, _) => {...accumulated, comment.id: comment},
          <String, Comment>{},
        )
        .map((commentMap) => _buildThreadFromComments(commentMap, rootEventId))
        .startWith(CommentThread.empty(rootEventId));
  }

  /// Posts a new comment.
  ///
  /// Creates a Kind 1 text note with proper NIP-10 threading tags
  /// and broadcasts it to relays.
  ///
  /// Parameters:
  /// - [content]: The comment text
  /// - [rootEventId]: The ID of the root event (e.g., video)
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
    required String rootEventAuthorPubkey,
    String? replyToEventId,
    String? replyToAuthorPubkey,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw const InvalidCommentContentException('Comment cannot be empty');
    }

    // Build tags for NIP-10 threading
    final tags = <List<String>>[
      // Root tag: the original event being commented on
      ['e', rootEventId, '', 'root'],
      // Tag the root author for notifications
      ['p', rootEventAuthorPubkey],
    ];

    // Add reply tags if this is a nested reply
    if (replyToEventId != null) {
      tags.add(['e', replyToEventId, '', 'reply']);
      if (replyToAuthorPubkey != null) {
        tags.add(['p', replyToAuthorPubkey]);
      }
    }

    // Create the event
    final event = Event(
      _nostrClient.publicKey,
      _textNoteKind,
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
      final filter = Filter(
        kinds: const [_textNoteKind],
        e: [rootEventId],
      );

      final result = await _nostrClient.countEvents([filter]);
      return result.count;
    } on Exception catch (e) {
      throw CountCommentsFailedException('Failed to count comments: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Converts a Nostr event to a Comment model.
  Comment? _eventToComment(Event event, String rootEventId) {
    try {
      String? parsedRootEventId;
      String? replyToEventId;
      String? rootAuthorPubkey;
      String? replyToAuthorPubkey;

      // Parse tags to determine comment relationships
      // Tags are List<List<dynamic>> in nostr_sdk
      for (final rawTag in event.tags) {
        final tag = rawTag as List<dynamic>;
        if (tag.length < 2) continue;

        final tagType = tag[0] as String;
        final tagValue = tag[1] as String;

        if (tagType == 'e') {
          // Event reference tag
          final marker = tag.length >= 4 ? tag[3] as String : '';
          if (marker == 'root') {
            parsedRootEventId = tagValue;
          } else if (marker == 'reply') {
            replyToEventId = tagValue;
          } else {
            // First e tag without marker is assumed to be root
            parsedRootEventId ??= tagValue;
          }
        } else if (tagType == 'p') {
          // Pubkey reference tag
          if (rootAuthorPubkey == null) {
            rootAuthorPubkey = tagValue;
          } else {
            replyToAuthorPubkey = tagValue;
          }
        }
      }

      return Comment(
        id: event.id,
        content: event.content,
        authorPubkey: event.pubkey,
        createdAt: event.createdAtDateTime,
        rootEventId: parsedRootEventId ?? rootEventId,
        replyToEventId: replyToEventId,
        rootAuthorPubkey: rootAuthorPubkey ?? '',
        replyToAuthorPubkey: replyToAuthorPubkey,
      );
    } on Exception {
      return null;
    }
  }

  /// Builds a CommentThread from a list of Nostr events.
  CommentThread _buildThreadFromEvents(List<Event> events, String rootEventId) {
    final commentMap = <String, Comment>{};

    for (final event in events) {
      final comment = _eventToComment(event, rootEventId);
      if (comment != null) {
        commentMap[comment.id] = comment;
      }
    }

    return _buildThreadFromComments(commentMap, rootEventId);
  }

  /// Builds a CommentThread from a map of comments.
  CommentThread _buildThreadFromComments(
    Map<String, Comment> commentMap,
    String rootEventId,
  ) {
    if (commentMap.isEmpty) {
      return CommentThread.empty(rootEventId);
    }

    final topLevel = <CommentNode>[];
    final nodeMap = <String, CommentNode>{};

    // Create nodes for all comments (initially without replies)
    for (final comment in commentMap.values) {
      nodeMap[comment.id] = CommentNode(comment: comment);
    }

    // Build reply relationships
    final repliesMap = <String, List<CommentNode>>{};
    for (final comment in commentMap.values) {
      final replyTo = comment.replyToEventId;
      if (replyTo != null &&
          replyTo != rootEventId &&
          nodeMap.containsKey(replyTo)) {
        (repliesMap[replyTo] ??= []).add(nodeMap[comment.id]!);
      }
    }

    // Rebuild nodes with their replies
    for (final comment in commentMap.values) {
      // Sort replies by time (oldest first for chronological reading)
      final replies = (repliesMap[comment.id] ?? <CommentNode>[])
        ..sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));
      nodeMap[comment.id] = CommentNode(
        comment: comment,
        replies: replies,
      );
    }

    // Collect top-level comments
    for (final comment in commentMap.values) {
      final replyTo = comment.replyToEventId;
      if (replyTo == null ||
          replyTo == rootEventId ||
          !nodeMap.containsKey(replyTo)) {
        topLevel.add(nodeMap[comment.id]!);
      }
    }

    // Sort top-level by time (newest first)
    topLevel.sort(
      (a, b) => b.comment.createdAt.compareTo(a.comment.createdAt),
    );

    return CommentThread(
      rootEventId: rootEventId,
      topLevelComments: topLevel,
      totalCount: commentMap.length,
      commentCache: Map<String, Comment>.unmodifiable(commentMap),
    );
  }
}
