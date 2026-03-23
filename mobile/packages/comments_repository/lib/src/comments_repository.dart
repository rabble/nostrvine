// ABOUTME: Repository for managing comments (Kind 1111 NIP-22) on Nostr.
// ABOUTME: Provides loading, posting, and streaming of threaded comments.
// ABOUTME: Uses NostrClient for relay operations and organizes comments
// chronologically.

import 'dart:async';
import 'dart:math';

import 'package:comments_repository/src/exceptions.dart';
import 'package:comments_repository/src/models/models.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

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
    FunnelcakeApiClient? funnelcakeApiClient,
  }) : _nostrClient = nostrClient,
       _funnelcakeApiClient = funnelcakeApiClient;

  final NostrClient _nostrClient;
  final FunnelcakeApiClient? _funnelcakeApiClient;

  /// In-memory cache of comment counts keyed by root event ID.
  ///
  /// Prevents redundant relay queries when the same video is scrolled
  /// back into view. Adjusted on post/delete and can be set externally
  /// via [updateCachedCommentCount] (e.g. from the comments sheet).
  final Map<String, int> _commentCountCache = {};

  /// Subscription ID for the active comment watch, if any.
  String? _watchSubscriptionId;

  /// Default page size for author comment queries.
  static const _authorCommentsLimit = 50;

  /// Loads comments for a root event and returns them in a flat list.
  ///
  /// This is a one-shot query that returns all comments organized
  /// chronologically (newest first) with reply relationships maintained
  /// through each Comment's replyToEventId field.
  ///
  /// Parameters:
  /// - [rootEventId]: The ID of the event to load comments for
  /// - [rootEventKind]: The kind of the root event (e.g., 34236 for videos)
  /// - [rootAddressableId]: Optional addressable identifier for the root event
  ///   (format: `kind:pubkey:d-tag`). When provided, queries by both E and A
  ///   tags to find comments that reference the event by either identifier.
  ///   This is important for Kind 34236 addressable events where some clients
  ///   may use E tags and others may use A tags.
  /// - [limit]: Maximum number of comments to fetch (default: 100)
  /// - [before]: Cursor for pagination - fetch comments created
  ///   before this time.
  ///   Note: Nostr `until` filter is inclusive, so subtract 1 second from the
  ///   oldest loaded comment's timestamp when paginating.
  ///
  /// Returns a [CommentThread] containing:
  /// - All comments in chronological order
  /// - Comment cache for quick lookup by ID
  /// - Total comment count
  ///
  /// Throws [LoadCommentsFailedException] if the query fails.
  Future<CommentThread> loadComments({
    required String rootEventId,
    required int rootEventKind,
    String? rootAddressableId,
    int limit = _defaultLimit,
    DateTime? before,
    int offset = 0,
  }) async {
    try {
      if (before == null && (_funnelcakeApiClient?.isAvailable ?? false)) {
        try {
          final response = await _funnelcakeApiClient!.getVideoComments(
            videoId: rootEventId,
            limit: limit,
            offset: offset,
          );
          if (response != null) {
            return _buildThreadFromRestComments(
              response,
              rootEventId,
              rootEventKind,
              rootAddressableId: rootAddressableId,
            );
          }
        } on FunnelcakeException {
          // Fall back to relay query when REST bootstrap is unavailable.
        }
      }

      final untilTimestamp = before != null
          ? before.millisecondsSinceEpoch ~/ 1000
          : null;

      // NIP-22: Filter by Kind 1111 and uppercase E tag for root scope
      final filterByE = Filter(
        kinds: const [_commentKind],
        uppercaseE: [rootEventId],
        limit: limit,
        until: untilTimestamp,
      );

      // If we have an addressable ID, also query by uppercase A tag
      // Some clients may reference addressable events using A instead of E
      if (rootAddressableId != null && rootAddressableId.isNotEmpty) {
        final filterByA = Filter(
          kinds: const [_commentKind],
          uppercaseA: [rootAddressableId],
          limit: limit,
          until: untilTimestamp,
        );

        // Run both queries in parallel and merge results
        final results = await Future.wait([
          _nostrClient.queryEvents([filterByE]),
          _nostrClient.queryEvents([filterByA]),
        ]);

        // Merge and deduplicate by event ID
        final eventMap = <String, Event>{};
        for (final event in results[0]) {
          eventMap[event.id] = event;
        }
        for (final event in results[1]) {
          eventMap[event.id] = event;
        }

        return _buildThreadFromEvents(
          eventMap.values.toList(),
          rootEventId,
          rootEventKind,
          rootAddressableId: rootAddressableId,
        );
      }

      // No addressable ID - just query by E tag
      final events = await _nostrClient.queryEvents([filterByE]);
      return _buildThreadFromEvents(
        events,
        rootEventId,
        rootEventKind,
      );
    } on Exception catch (e) {
      throw LoadCommentsFailedException('Failed to load comments: $e');
    }
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
  /// - [rootAddressableId]: Optional addressable identifier for the root event
  ///   (format: `kind:pubkey:d-tag`). When provided, includes both E and A tags
  ///   to ensure the comment can be found by clients querying either way.
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
    String? rootAddressableId,
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
      // Include A tag for addressable events (Kind 30000-39999)
      // This ensures comments can be found by clients querying by either E or A
      // NIP-22: A tags use 3 elements [A, address, relay_hint]
      if (rootAddressableId != null && rootAddressableId.isNotEmpty)
        ['A', rootAddressableId, ''],
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
        // Include lowercase 'a' tag for addressable events too
        // NIP-22: a tags use 3 elements [a, address, relay_hint]
        if (rootAddressableId != null && rootAddressableId.isNotEmpty)
          ['a', rootAddressableId, ''],
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

      final cached = _commentCountCache[rootEventId];
      if (cached != null) _commentCountCache[rootEventId] = cached + 1;

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
  /// - [rootAddressableId]: Optional addressable identifier for the root event
  ///   (format: `kind:pubkey:d-tag`). When provided, counts comments from both
  ///   E and A tag queries to get an accurate total.
  ///
  /// Returns the number of comments on the event.
  ///
  /// Throws [CountCommentsFailedException] if counting fails.
  Future<int> getCommentsCount(
    String rootEventId, {
    String? rootAddressableId,
  }) async {
    final cached = _commentCountCache[rootEventId];
    if (cached != null) return cached;

    try {
      // NIP-22: Filter by Kind 1111 and uppercase E tag
      final filterByE = Filter(
        kinds: const [_commentKind],
        uppercaseE: [rootEventId],
      );

      int count;

      // If we have an addressable ID, also query by uppercase A tag
      if (rootAddressableId != null && rootAddressableId.isNotEmpty) {
        final filterByA = Filter(
          kinds: const [_commentKind],
          uppercaseA: [rootAddressableId],
        );

        // Run both COUNT queries in parallel
        // Note: This may over-count if a comment has both E and A tags,
        // but that's rare and the count is still useful for UI purposes.
        // For exact count, use loadComments which deduplicates.
        final results = await Future.wait([
          _nostrClient.countEvents([filterByE]),
          _nostrClient.countEvents([filterByA]),
        ]);

        // Return the maximum of the two counts
        // (since comments should have at least one of these tags)
        final countByE = results[0].count;
        final countByA = results[1].count;
        count = countByE > countByA ? countByE : countByA;
      } else {
        final result = await _nostrClient.countEvents([filterByE]);
        count = result.count;
      }

      _commentCountCache[rootEventId] = count;
      return count;
    } on Exception catch (e) {
      throw CountCommentsFailedException('Failed to count comments: $e');
    }
  }

  /// Updates the cached comment count for a root event.
  ///
  /// Called by the UI layer (e.g. after the comments sheet is dismissed)
  /// to keep the cache in sync with the authoritative count from the
  /// loaded comment thread. This avoids a stale NIP-45 COUNT when the
  /// user scrolls back to the same video.
  void updateCachedCommentCount(String rootEventId, int count) {
    _commentCountCache[rootEventId] = count;
  }

  /// Clears the in-memory comment count cache.
  ///
  /// Should be called on logout so stale counts from a previous user's
  /// session are not served after re-login.
  void clearCommentCountCache() {
    _commentCountCache.clear();
  }

  /// Deletes a comment by publishing a NIP-09 deletion request.
  ///
  /// Creates a Kind 5 event with an `e` tag referencing the comment
  /// and a `k` tag specifying the comment kind (1111).
  ///
  /// Parameters:
  /// - [commentId]: The ID of the comment event to delete
  /// - [rootEventId]: Optional root event ID. When provided, the cached
  ///   comment count for that root event is decremented so subsequent
  ///   [getCommentsCount] calls return the correct value.
  /// - [reason]: Optional reason for the deletion
  ///
  /// Throws [DeleteCommentFailedException] if broadcasting fails.
  Future<void> deleteComment({
    required String commentId,
    String? rootEventId,
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

      if (rootEventId != null) {
        final cached = _commentCountCache[rootEventId];
        if (cached != null) {
          _commentCountCache[rootEventId] = max(0, cached - 1);
        }
      }
    } on CommentsRepositoryException {
      rethrow;
    } on Exception catch (e) {
      throw DeleteCommentFailedException('Failed to delete comment: $e');
    }
  }

  /// Watches for new comments in real-time via a persistent Nostr subscription.
  ///
  /// Opens a subscription for Kind 1111 events matching the root event,
  /// returning a [Stream<Comment>] that emits each new comment as it arrives.
  ///
  /// Parameters:
  /// - [rootEventId]: The ID of the root event to watch comments for
  /// - [rootEventKind]: The kind of the root event (e.g., 34236 for videos)
  /// - [rootAddressableId]: Optional addressable identifier (format:
  ///   `kind:pubkey:d-tag`). When provided, subscribes to both E and A tags.
  /// - [since]: Only receive comments created after this time
  ///
  /// Returns a [Stream<Comment>] that emits new comments as they arrive.
  /// Call [stopWatchingComments] to close the subscription.
  ///
  /// Throws [WatchCommentsFailedException] if the subscription fails.
  Stream<Comment> watchComments({
    required String rootEventId,
    required int rootEventKind,
    DateTime? since,
    String? rootAddressableId,
    void Function()? onEose,
  }) {
    try {
      final sinceTimestamp = since != null
          ? since.millisecondsSinceEpoch ~/ 1000
          : null;

      final filters = <Filter>[
        Filter(
          kinds: const [_commentKind],
          uppercaseE: [rootEventId],
          since: sinceTimestamp,
        ),
        if (rootAddressableId != null && rootAddressableId.isNotEmpty)
          Filter(
            kinds: const [_commentKind],
            uppercaseA: [rootAddressableId],
            since: sinceTimestamp,
          ),
      ];

      _watchSubscriptionId = 'comments_watch_$rootEventId';

      final eventStream = _nostrClient.subscribe(
        filters,
        subscriptionId: _watchSubscriptionId,
        onEose: onEose,
      );

      // When dual-filter subscriptions are active (E + A tags), the same
      // comment event can arrive from both filters. Deduplicate by event ID
      // to prevent consumers from processing duplicates.
      final seenIds = <String>{};

      return eventStream
          .where((event) => seenIds.add(event.id))
          .map((event) => _eventToComment(event, rootEventId, rootEventKind))
          .where((comment) => comment != null)
          .cast<Comment>();
    } on Exception catch (e) {
      throw WatchCommentsFailedException('Failed to watch comments: $e');
    }
  }

  /// Stops watching for new comments.
  ///
  /// Closes the persistent Nostr subscription opened by [watchComments].
  Future<void> stopWatchingComments() async {
    final id = _watchSubscriptionId;
    if (id != null) {
      await _nostrClient.unsubscribe(id);
      _watchSubscriptionId = null;
    }
  }

  /// Loads comments authored by a specific user across all videos.
  ///
  /// Returns a list of comments sorted newest first.
  /// Supports cursor-based pagination via [before].
  ///
  /// Throws:
  ///
  /// * [LoadCommentsByAuthorFailedException] if the query fails.
  Future<List<Comment>> loadCommentsByAuthor({
    required String authorPubkey,
    int limit = _authorCommentsLimit,
    DateTime? before,
  }) async {
    try {
      final untilTimestamp = before != null
          ? before.millisecondsSinceEpoch ~/ 1000
          : null;

      final filter = Filter(
        kinds: const [_commentKind],
        authors: [authorPubkey],
        limit: limit,
        until: untilTimestamp,
      );

      final events = await _nostrClient.queryEvents([filter]);

      final comments =
          events.map(_eventToCommentFromRawEvent).whereType<Comment>().toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return comments;
    } on Exception catch (e) {
      throw LoadCommentsByAuthorFailedException(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Converts a raw Nostr event to a Comment by extracting root info
  /// from the event's own NIP-22 tags.
  ///
  /// Unlike [_eventToComment] which requires root context from the caller,
  /// this method reads the uppercase `E` and `K` tags directly from the event.
  /// Returns `null` if the required root tags are missing.
  Comment? _eventToCommentFromRawEvent(Event event) {
    try {
      String? rootEventId;
      String? rootEventKind;

      for (final rawTag in event.tags) {
        final tag = rawTag as List<dynamic>;
        if (tag.length < 2) continue;
        final tagType = tag[0] as String;
        final tagValue = tag[1] as String;

        if (tagType == 'E') {
          rootEventId = tagValue;
        } else if (tagType == 'K') {
          rootEventKind = tagValue;
        }
      }

      if (rootEventId == null || rootEventKind == null) return null;

      final kind = int.tryParse(rootEventKind);
      if (kind == null) return null;

      return _eventToComment(event, rootEventId, kind);
    } on Exception {
      return null;
    }
  }

  /// Converts a Nostr event to a Comment model using NIP-22 format.
  Comment? _eventToComment(Event event, String rootEventId, int rootEventKind) {
    try {
      String? parsedRootEventId;
      String? parsedRootAddressableId;
      String? replyToEventId;
      String? rootAuthorPubkey;
      String? replyToAuthorPubkey;
      String? parentKind;

      // Parse NIP-22 tags to determine comment relationships
      // Uppercase tags (E, A, K, P) = root scope
      // Lowercase tags (e, a, k, p) = parent item
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
          case 'A':
            // Root addressable ID (uppercase = root scope)
            // Format: kind:pubkey:d-tag
            parsedRootAddressableId = tagValue;
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

      // Extract root author pubkey from addressable ID if not found in tags
      // A tag format: kind:pubkey:d-tag
      if (rootAuthorPubkey == null && parsedRootAddressableId != null) {
        final parts = parsedRootAddressableId.split(':');
        if (parts.length >= 2) {
          rootAuthorPubkey = parts[1];
        }
      }

      // Determine if this is a top-level comment or a reply
      // If parent kind equals root kind, it's a top-level comment
      final isTopLevel =
          parentKind == rootEventKind.toString() ||
          replyToEventId == parsedRootEventId;

      // Parse NIP-92 imeta tags for attached video metadata
      String? videoUrl;
      String? thumbnailUrl;
      String? videoDimensions;
      int? videoDuration;
      String? videoBlurhash;

      for (final rawTag in event.tags) {
        final tag = rawTag as List<dynamic>;
        if (tag.isEmpty) continue;
        if (tag[0] as String != 'imeta') continue;

        // imeta tag fields: "key value" pairs after the tag name
        for (var i = 1; i < tag.length; i++) {
          final field = (tag[i] as String).trim();
          if (field.startsWith('url ')) {
            final url = field.substring(4).trim();
            // Only treat as video if it has a video extension
            if (url.endsWith('.mp4') ||
                url.endsWith('.mov') ||
                url.endsWith('.webm') ||
                url.contains('video')) {
              videoUrl = url;
            }
          } else if (field.startsWith('image ')) {
            thumbnailUrl = field.substring(6).trim();
          } else if (field.startsWith('dim ')) {
            videoDimensions = field.substring(4).trim();
          } else if (field.startsWith('duration ')) {
            videoDuration = int.tryParse(field.substring(9).trim());
          } else if (field.startsWith('blurhash ')) {
            videoBlurhash = field.substring(9).trim();
          }
        }
      }

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
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        videoDimensions: videoDimensions,
        videoDuration: videoDuration,
        videoBlurhash: videoBlurhash,
      );
    } on Exception {
      return null;
    }
  }

  /// Checks whether an event's uppercase `E` or `A` tag matches the queried
  /// root. This provides client-side filtering for relays that do not support
  /// NIP-22 uppercase tag filters and return all Kind 1111 events.
  bool _eventMatchesRoot(
    Event event,
    String rootEventId,
    String? rootAddressableId,
  ) {
    for (final rawTag in event.tags) {
      final tag = rawTag as List<dynamic>;
      if (tag.length < 2) continue;
      final tagType = tag[0] as String;
      final tagValue = tag[1] as String;
      if (tagType == 'E' && tagValue == rootEventId) return true;
      if (tagType == 'A' &&
          rootAddressableId != null &&
          tagValue == rootAddressableId) {
        return true;
      }
    }
    return false;
  }

  /// Builds a CommentThread from a list of Nostr events.
  ///
  /// Events that do not reference the queried root (via uppercase `E` or `A`
  /// tags) are filtered out to guard against relays that ignore uppercase tag
  /// filters.
  CommentThread _buildThreadFromEvents(
    List<Event> events,
    String rootEventId,
    int rootEventKind, {
    String? rootAddressableId,
  }) {
    final commentMap = <String, Comment>{};

    for (final event in events) {
      if (!_eventMatchesRoot(event, rootEventId, rootAddressableId)) continue;
      final comment = _eventToComment(event, rootEventId, rootEventKind);
      if (comment != null) {
        commentMap[comment.id] = comment;
      }
    }

    return _buildThreadFromComments(commentMap, rootEventId);
  }

  CommentThread _buildThreadFromRestComments(
    VideoCommentsResponse response,
    String rootEventId,
    int rootEventKind, {
    String? rootAddressableId,
  }) {
    final commentMap = <String, Comment>{};

    for (final restComment in response.comments) {
      final comment = _restCommentToComment(
        restComment,
        rootEventId,
        rootEventKind,
        rootAddressableId: rootAddressableId,
      );
      if (comment != null) {
        commentMap[comment.id] = comment;
      }
    }

    final thread = _buildThreadFromComments(commentMap, rootEventId);
    return thread.copyWith(totalCount: response.total);
  }

  Comment? _restCommentToComment(
    VideoComment restComment,
    String rootEventId,
    int rootEventKind, {
    String? rootAddressableId,
  }) {
    try {
      String? parsedRootEventId;
      String? parsedRootAddressableId;
      String? rootAuthorPubkey;

      for (final tag in restComment.tags) {
        if (tag.length < 2) continue;
        switch (tag[0]) {
          case 'E':
            parsedRootEventId = tag[1];
            if (tag.length >= 4) {
              rootAuthorPubkey = tag[3];
            }
          case 'A':
            parsedRootAddressableId = tag[1];
          case 'P':
            rootAuthorPubkey ??= tag[1];
        }
      }

      if (rootAuthorPubkey == null && parsedRootAddressableId != null) {
        final parts = parsedRootAddressableId.split(':');
        if (parts.length >= 2) {
          rootAuthorPubkey = parts[1];
        }
      }
      if (rootAuthorPubkey == null && rootAddressableId != null) {
        final parts = rootAddressableId.split(':');
        if (parts.length >= 2) {
          rootAuthorPubkey = parts[1];
        }
      }

      final parsedReplyToEventId = restComment.replyToEventId;
      final isTopLevel =
          parsedReplyToEventId == null || parsedReplyToEventId == rootEventId;

      return Comment(
        id: restComment.id,
        content: restComment.content,
        authorPubkey: restComment.pubkey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          restComment.createdAt * 1000,
        ),
        rootEventId: parsedRootEventId ?? rootEventId,
        rootAuthorPubkey: rootAuthorPubkey ?? '',
        replyToEventId: isTopLevel ? null : parsedReplyToEventId,
        replyToAuthorPubkey: isTopLevel ? null : restComment.replyToPubkey,
      );
    } on Exception {
      return null;
    }
  }

  /// Builds a CommentThread from a map of comments.
  ///
  /// Organizes comments into a flat list sorted chronologically (newest first).
  /// Reply relationships are maintained through each Comment's
  /// replyToEventId field.
  CommentThread _buildThreadFromComments(
    Map<String, Comment> commentMap,
    String rootEventId,
  ) {
    if (commentMap.isEmpty) {
      return CommentThread.empty(rootEventId);
    }

    // Simple chronological sort: newest first
    final sortedComments = commentMap.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return CommentThread(
      rootEventId: rootEventId,
      comments: sortedComments,
      totalCount: commentMap.length,
      commentCache: Map<String, Comment>.unmodifiable(commentMap),
    );
  }
}
