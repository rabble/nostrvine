// ABOUTME: Repository for managing comments (Kind 1111 NIP-22) on Nostr.
// ABOUTME: Provides loading, posting, and streaming of threaded comments.
// ABOUTME: Uses NostrClient for relay operations and organizes comments
// chronologically.

import 'dart:async';

import 'package:comments_repository/src/exceptions.dart';
import 'package:comments_repository/src/models/models.dart';
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
  }) : _nostrClient = nostrClient;

  final NostrClient _nostrClient;

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
    String? relayUrl,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final untilTimestamp = before != null
          ? before.millisecondsSinceEpoch ~/ 1000
          : null;

      // Target a specific relay when provided (e.g., our own relay for speed)
      final tempRelays = relayUrl != null ? [relayUrl] : null;

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
          _nostrClient.queryEvents(
            [filterByE],
            tempRelays: tempRelays,
            timeout: timeout,
          ),
          _nostrClient.queryEvents(
            [filterByA],
            tempRelays: tempRelays,
            timeout: timeout,
          ),
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
      final events = await _nostrClient.queryEvents(
        [filterByE],
        tempRelays: tempRelays,
        timeout: timeout,
      );
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
  /// - [imetaTag]: Optional NIP-92 imeta tag entries for video attachments.
  ///   Each entry is a space-delimited "key value" string, e.g.
  ///   `["url https://...", "m video/mp4", "dim 720x1280"]`.
  ///   When provided, the imeta tag is appended to the event tags and
  ///   the video URL is included in the content per NIP-92 spec.
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
    List<String>? imetaTag,
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
      // NIP-92: Attach inline media metadata if provided
      if (imetaTag != null && imetaTag.isNotEmpty) ['imeta', ...imetaTag],
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

      // Parse media fields from the imeta tag if provided
      final imetaFields = _parseImetaEntries(imetaTag);

      return Comment(
        id: sentEvent.id,
        content: trimmedContent,
        authorPubkey: sentEvent.pubkey,
        createdAt: event.createdAtDateTime,
        rootEventId: rootEventId,
        rootAuthorPubkey: rootEventAuthorPubkey,
        replyToEventId: replyToEventId,
        replyToAuthorPubkey: replyToAuthorPubkey,
        videoUrl: imetaFields['url'],
        thumbnailUrl: imetaFields['image'],
        videoDimensions: imetaFields['dim'],
        videoDuration: imetaFields['duration'] != null
            ? int.tryParse(imetaFields['duration']!)
            : null,
        videoBlurhash: imetaFields['blurhash'],
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
    try {
      // NIP-22: Filter by Kind 1111 and uppercase E tag
      final filterByE = Filter(
        kinds: const [_commentKind],
        uppercaseE: [rootEventId],
      );

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
        return countByE > countByA ? countByE : countByA;
      }

      final result = await _nostrClient.countEvents([filterByE]);
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
    required DateTime since,
    String? rootAddressableId,
  }) {
    try {
      final sinceTimestamp = since.millisecondsSinceEpoch ~/ 1000;

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
  /// Returns a flat list of [Comment] objects sorted chronologically
  /// (newest first). Each comment includes its root event ID and kind
  /// extracted from the event's own NIP-22 tags.
  ///
  /// Parameters:
  /// - [authorPubkey]: The hex public key of the comment author
  /// - [limit]: Maximum number of comments to fetch
  /// - [before]: Cursor for pagination — fetch comments created before
  ///   this time. Subtract 1 second from the oldest loaded comment's
  ///   timestamp when paginating.
  ///
  /// Throws [LoadCommentsByAuthorFailedException] if the query fails.
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

      final comments = <Comment>[];
      for (final event in events) {
        final comment = _eventToCommentFromRawEvent(event);
        if (comment != null) {
          comments.add(comment);
        }
      }

      // Sort newest first
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return comments;
    } on Exception catch (e) {
      throw LoadCommentsByAuthorFailedException(
        'Failed to load comments by author: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Converts a raw Nostr event to a Comment by extracting root event
  /// info from the event's own NIP-22 tags.
  ///
  /// Unlike [_eventToComment], this method does not require the caller
  /// to know the root event ID or kind upfront — it reads them from
  /// the uppercase E and K tags on the event itself.
  ///
  /// Returns `null` if the event is missing required tags or is
  /// otherwise malformed.
  Comment? _eventToCommentFromRawEvent(Event event) {
    try {
      String? rootEventId;
      int? rootEventKind;

      // Extract root event ID (E tag) and root kind (K tag)
      for (final rawTag in event.tags) {
        final tag = rawTag as List<dynamic>;
        if (tag.length < 2) continue;
        final tagType = tag[0] as String;
        final tagValue = tag[1] as String;

        if (tagType == 'E') {
          rootEventId = tagValue;
        } else if (tagType == 'K') {
          rootEventKind = int.tryParse(tagValue);
        }
      }

      // Both E and K tags are required for a valid comment
      if (rootEventId == null || rootEventKind == null) return null;

      return _eventToComment(event, rootEventId, rootEventKind);
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
      List<String>? imetaEntries;

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
          case 'imeta':
            // NIP-92 inline media metadata
            imetaEntries = tag.skip(1).map((e) => e.toString()).toList();
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

      // Parse NIP-92 imeta fields for video metadata
      final imetaFields = _parseImetaEntries(imetaEntries);
      final videoUrl = imetaFields['url'];

      // Only populate video fields if the URL is a video mime type
      // or if the imeta tag contains video-related fields
      final hasVideoMedia =
          videoUrl != null && (imetaFields['m']?.startsWith('video/') ?? true);

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
        videoUrl: hasVideoMedia ? videoUrl : null,
        thumbnailUrl: hasVideoMedia ? imetaFields['image'] : null,
        videoDimensions: hasVideoMedia ? imetaFields['dim'] : null,
        videoDuration: hasVideoMedia && imetaFields['duration'] != null
            ? int.tryParse(imetaFields['duration']!)
            : null,
        videoBlurhash: hasVideoMedia ? imetaFields['blurhash'] : null,
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

  /// Parses NIP-92 imeta tag entries into a key-value map.
  ///
  /// Each entry is a space-delimited "key value" string, e.g.:
  /// `["url https://example.com/video.mp4", "m video/mp4", "dim 720x1280"]`
  ///
  /// Returns a map like `{url: "https://...", m: "video/mp4", dim: "720x1280"}`.
  Map<String, String> _parseImetaEntries(List<String>? entries) {
    if (entries == null || entries.isEmpty) return {};

    final fields = <String, String>{};
    for (final entry in entries) {
      final spaceIndex = entry.indexOf(' ');
      if (spaceIndex <= 0) continue;
      final key = entry.substring(0, spaceIndex);
      final value = entry.substring(spaceIndex + 1);
      if (value.isNotEmpty) {
        fields[key] = value;
      }
    }
    return fields;
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
