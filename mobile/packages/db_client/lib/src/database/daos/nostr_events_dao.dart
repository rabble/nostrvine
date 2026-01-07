// ABOUTME: Data Access Object for Nostr event operations with reactive
// ABOUTME: Drift queries. Provides CRUD operations for all Nostr events
// ABOUTME: stored in the shared database. Handles NIP-01 replaceable events.

import 'dart:convert';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/drift.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

part 'nostr_events_dao.g.dart';

/// Default cache expiry duration for Nostr events (1 day).
///
/// All events stored in the database will expire after this duration
/// to prevent unbounded cache growth. Events can be refreshed by
/// re-fetching from relays.
const Duration defaultEventCacheExpiry = Duration(days: 1);

@DriftAccessor(tables: [NostrEvents, VideoMetrics])
class NostrEventsDao extends DatabaseAccessor<AppDatabase>
    with _$NostrEventsDaoMixin {
  NostrEventsDao(super.attachedDatabase);

  /// Calculate expire_at Unix timestamp for an event using default expiry.
  int _defaultExpireAt() {
    return DateTime.now().add(defaultEventCacheExpiry).millisecondsSinceEpoch ~/
        1000;
  }

  /// Insert or replace event with NIP-01 replaceable event handling.
  ///
  /// All events are stored with a default 1-day expiry to prevent unbounded
  /// cache growth. To customize the expiry, provide [expireAt] as a Unix
  /// timestamp.
  ///
  /// For regular events: uses INSERT OR REPLACE by event ID.
  ///
  /// For replaceable events (kind 0, 3, 10000-19999): replaces existing event
  /// with same pubkey+kind only if the new event has a higher created_at.
  ///
  /// For parameterized replaceable events (kind 30000-39999): replaces existing
  /// event with same pubkey+kind+d-tag only if the new event has a higher
  /// created_at.
  ///
  /// For video events (kind 34236 or 16), also upserts video metrics to the
  /// video_metrics table for fast sorted queries.
  Future<void> upsertEvent(Event event, {int? expireAt}) async {
    final effectiveExpireAt = expireAt ?? _defaultExpireAt();

    // Handle replaceable events (kind 0, 3, 10000-19999)
    if (EventKind.isReplaceable(event.kind)) {
      await _upsertReplaceableEvent(event, expireAt: effectiveExpireAt);
      return;
    }

    // Handle parameterized replaceable events (kind 30000-39999)
    if (EventKind.isParameterizedReplaceable(event.kind)) {
      await _upsertParameterizedReplaceableEvent(
        event,
        expireAt: effectiveExpireAt,
      );
      return;
    }

    // Regular event: simple insert or replace by ID
    await _insertEvent(event, expireAt: effectiveExpireAt);

    // Also upsert video metrics for video events (kind 34236 only)
    // Note: Kind 16 reposts reference videos but don't contain video metadata
    if (event.kind == 34236) {
      await db.videoMetricsDao.upsertVideoMetrics(event);
    }
  }

  /// Insert event without replaceable logic (by event ID)
  ///
  /// If [expireAt] is provided, the event will be marked for cache eviction
  /// after that Unix timestamp.
  ///
  /// Uses customInsert with updates parameter to notify stream watchers.
  /// Automatically handles case where expire_at column doesn't exist yet.
  Future<void> _insertEvent(Event event, {int? expireAt}) async {
    // Use INSERT without expire_at column - it may not exist yet on older DBs
    // This matches the schema created by nostr_sdk's embedded relay
    await customInsert(
      'INSERT OR REPLACE INTO event '
      '(id, pubkey, created_at, kind, tags, content, sig, sources) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(event.id),
        Variable.withString(event.pubkey),
        Variable.withInt(event.createdAt),
        Variable.withInt(event.kind),
        Variable.withString(jsonEncode(event.tags)),
        Variable.withString(event.content),
        Variable.withString(event.sig),
        const Variable(null), // sources - not used yet
      ],
      updates: {nostrEvents},
    );

    // Set expire_at separately via UPDATE if provided and column exists
    if (expireAt != null && db.hasExpireAtColumn) {
      await setEventExpiry(event.id, expireAt);
    }
  }

  /// Upsert replaceable event (kind 0, 3, 10000-19999)
  ///
  /// Only stores the event if no existing event with same pubkey+kind exists,
  /// or if the new event has a higher created_at timestamp.
  Future<void> _upsertReplaceableEvent(
    Event event, {
    required int expireAt,
  }) async {
    // Check if a newer event already exists for this pubkey+kind
    final existingRows = await customSelect(
      'SELECT id, created_at FROM event WHERE pubkey = ? AND kind = ? LIMIT 1',
      variables: [
        Variable.withString(event.pubkey),
        Variable.withInt(event.kind),
      ],
      readsFrom: {nostrEvents},
    ).get();

    if (existingRows.isNotEmpty) {
      final existingCreatedAt = existingRows.first.read<int>('created_at');
      if (event.createdAt <= existingCreatedAt) {
        // Existing event is newer or same age, don't replace
        return;
      }
      // Delete the old event before inserting the new one
      final existingId = existingRows.first.read<String>('id');
      await customUpdate(
        'DELETE FROM event WHERE id = ?',
        variables: [Variable.withString(existingId)],
        updates: {nostrEvents},
        updateKind: UpdateKind.delete,
      );
    }

    await _insertEvent(event, expireAt: expireAt);
  }

  /// Upsert parameterized replaceable event (kind 30000-39999)
  ///
  /// Only stores the event if no existing event with same pubkey+kind+d-tag
  /// exists, or if the new event has a higher created_at timestamp.
  Future<void> _upsertParameterizedReplaceableEvent(
    Event event, {
    required int expireAt,
  }) async {
    final dTagValue = event.dTagValue;

    // Check if a newer event already exists for this pubkey+kind+d-tag
    // We need to check tags JSON for the d-tag value
    final existingRows = await customSelect(
      'SELECT id, created_at, tags FROM event '
      'WHERE pubkey = ? AND kind = ?',
      variables: [
        Variable.withString(event.pubkey),
        Variable.withInt(event.kind),
      ],
      readsFrom: {nostrEvents},
    ).get();

    for (final row in existingRows) {
      final tagsJson = row.read<String>('tags');
      final tags = (jsonDecode(tagsJson) as List)
          .map((tag) => (tag as List).map((e) => e.toString()).toList())
          .toList();
      final existingDTag = _extractDTagFromTags(tags);

      if (existingDTag == dTagValue) {
        final existingCreatedAt = row.read<int>('created_at');
        if (event.createdAt <= existingCreatedAt) {
          // Existing event is newer or same age, don't replace
          return;
        }
        // Delete the old event before inserting the new one
        final existingId = row.read<String>('id');
        await customUpdate(
          'DELETE FROM event WHERE id = ?',
          variables: [Variable.withString(existingId)],
          updates: {nostrEvents},
          updateKind: UpdateKind.delete,
        );
        break;
      }
    }

    await _insertEvent(event, expireAt: expireAt);

    // Also upsert video metrics for video events
    if (event.kind == 34236) {
      await db.videoMetricsDao.upsertVideoMetrics(event);
    }
  }

  /// Batch insert or replace multiple events in a single transaction.
  ///
  /// All events are stored with a default 1-day expiry. To customize
  /// the expiry, provide [expireAt] as a Unix timestamp.
  ///
  /// Much more efficient than calling upsertEvent() repeatedly.
  /// Uses a single database transaction to avoid lock contention.
  /// Handles NIP-01 replaceable event semantics.
  Future<void> upsertEventsBatch(List<Event> events, {int? expireAt}) async {
    if (events.isEmpty) return;

    final effectiveExpireAt = expireAt ?? _defaultExpireAt();

    await transaction(() async {
      // Batch upsert all events with replaceable logic
      for (final event in events) {
        await upsertEvent(event, expireAt: effectiveExpireAt);
      }
    });
  }

  /// Watch events with a Nostr Filter (reactive stream)
  ///
  /// Returns a Stream that emits whenever the matching events change in the
  /// database. Uses Drift's reactive query mechanism to automatically re-emit
  /// when inserts, updates, or deletes occur on the events table.
  ///
  /// Supports all the same filter parameters as [getEventsByFilter].
  ///
  /// Example:
  /// ```dart
  /// dao.watchEventsByFilter(Filter(kinds: [1])).listen((events) {
  ///   print('Got ${events.length} events');
  /// });
  /// ```
  Stream<List<Event>> watchEventsByFilter(
    Filter filter, {
    String? sortBy,
  }) {
    return _buildFilterQuery(
      filter,
      sortBy: sortBy,
    ).watch().map((rows) => rows.map(_rowToEvent).toList());
  }

  /// Query events with a Nostr Filter (cache-first strategy)
  ///
  /// Supports all standard Nostr filter parameters:
  /// - ids: List of event IDs to match
  /// - kinds: Event kinds to match (no default - returns all kinds if null)
  /// - authors: List of pubkeys to filter by
  /// - t: List of hashtags to filter by (searches tags JSON)
  /// - e: List of referenced event IDs (e tags)
  /// - p: List of mentioned pubkeys (p tags)
  /// - d: List of addressable event identifiers (d tags)
  /// - search: Full-text search in content (NIP-50)
  /// - since: Minimum created_at timestamp (Unix seconds)
  /// - until: Maximum created_at timestamp (Unix seconds)
  /// - limit: Maximum number of events to return
  ///
  /// Additional parameter:
  /// - sortBy: Field to sort by (loop_count, likes, views, created_at).
  ///   Defaults to created_at DESC.
  ///
  /// Used by cache-first query strategy to return instant results before
  /// relay query.
  Future<List<Event>> getEventsByFilter(
    Filter filter, {
    String? sortBy,
  }) async {
    final rows = await _buildFilterQuery(filter, sortBy: sortBy).get();
    return rows.map(_rowToEvent).toList();
  }

  /// Builds a Selectable query for events matching the given filter.
  ///
  /// This method is used internally by both [getEventsByFilter] (one-shot)
  /// and [watchEventsByFilter] (reactive stream).
  Selectable<QueryRow> _buildFilterQuery(
    Filter filter, {
    String? sortBy,
  }) {
    // Build dynamic SQL query based on provided filters
    final conditions = <String>[];
    final variables = <Variable>[];

    // IDs filter
    final ids = filter.ids;
    if (ids != null && ids.isNotEmpty) {
      final placeholders = List.filled(ids.length, '?').join(', ');
      conditions.add('id IN ($placeholders)');
      variables.addAll(ids.map(Variable.withString));
    }

    // Kind filter (no default - returns all kinds if not specified)
    final kinds = filter.kinds;
    if (kinds != null && kinds.isNotEmpty) {
      if (kinds.length == 1) {
        conditions.add('kind = ?');
        variables.add(Variable.withInt(kinds.first));
      } else {
        final placeholders = List.filled(kinds.length, '?').join(', ');
        conditions.add('kind IN ($placeholders)');
        variables.addAll(kinds.map(Variable.withInt));
      }
    }

    // Authors filter
    final authors = filter.authors;
    if (authors != null && authors.isNotEmpty) {
      final placeholders = List.filled(authors.length, '?').join(', ');
      conditions.add('pubkey IN ($placeholders)');
      variables.addAll(authors.map(Variable.withString));
    }

    // Hashtags filter (t tags)
    final hashtags = filter.t;
    if (hashtags != null && hashtags.isNotEmpty) {
      final hashtagConditions = hashtags.map((tag) {
        final lowerTag = tag.toLowerCase();
        variables.add(Variable.withString('%"t"%"$lowerTag"%'));
        return 'tags LIKE ?';
      }).toList();
      conditions.add('(${hashtagConditions.join(' OR ')})');
    }

    // Referenced events filter (e tags)
    final eTags = filter.e;
    if (eTags != null && eTags.isNotEmpty) {
      final eTagConditions = eTags.map((eventId) {
        variables.add(Variable.withString('%"e"%"$eventId"%'));
        return 'tags LIKE ?';
      }).toList();
      conditions.add('(${eTagConditions.join(' OR ')})');
    }

    // Mentioned pubkeys filter (p tags)
    final pTags = filter.p;
    if (pTags != null && pTags.isNotEmpty) {
      final pTagConditions = pTags.map((pubkey) {
        variables.add(Variable.withString('%"p"%"$pubkey"%'));
        return 'tags LIKE ?';
      }).toList();
      conditions.add('(${pTagConditions.join(' OR ')})');
    }

    // Addressable event identifiers filter (d tags)
    final dTags = filter.d;
    if (dTags != null && dTags.isNotEmpty) {
      final dTagConditions = dTags.map((identifier) {
        variables.add(Variable.withString('%"d"%"$identifier"%'));
        return 'tags LIKE ?';
      }).toList();
      conditions.add('(${dTagConditions.join(' OR ')})');
    }

    // Uppercase E tags (NIP-22 root event reference)
    // Use GLOB for case-sensitive matching (LIKE is case-insensitive in SQLite)
    final uppercaseETags = filter.uppercaseE;
    if (uppercaseETags != null && uppercaseETags.isNotEmpty) {
      final eTagConditions = uppercaseETags.map((eventId) {
        variables.add(Variable.withString('*"E"*"$eventId"*'));
        return 'tags GLOB ?';
      }).toList();
      conditions.add('(${eTagConditions.join(' OR ')})');
    }

    // Uppercase K tags (NIP-22 root event kind)
    // Use GLOB for case-sensitive matching (LIKE is case-insensitive in SQLite)
    final uppercaseKTags = filter.uppercaseK;
    if (uppercaseKTags != null && uppercaseKTags.isNotEmpty) {
      final kTagConditions = uppercaseKTags.map((kind) {
        variables.add(Variable.withString('*"K"*"$kind"*'));
        return 'tags GLOB ?';
      }).toList();
      conditions.add('(${kTagConditions.join(' OR ')})');
    }

    // Content search filter (NIP-50 style, case insensitive)
    final search = filter.search;
    if (search != null && search.isNotEmpty) {
      conditions.add('content LIKE ? COLLATE NOCASE');
      variables.add(Variable.withString('%$search%'));
    }

    // Time range filters
    final since = filter.since;
    if (since != null) {
      conditions.add('created_at >= ?');
      variables.add(Variable.withInt(since));
    }
    final until = filter.until;
    if (until != null) {
      conditions.add('created_at <= ?');
      variables.add(Variable.withInt(until));
    }

    // Build WHERE clause (or no WHERE if no conditions)
    final whereClause = conditions.isEmpty ? '1=1' : conditions.join(' AND ');

    // Determine ORDER BY clause and whether we need to join video_metrics
    String orderByClause;
    var needsMetricsJoin = false;

    if (sortBy != null && sortBy != 'created_at') {
      needsMetricsJoin = true;

      final sortColumn =
          {
            'loop_count': 'loop_count',
            'likes': 'likes',
            'views': 'views',
            'comments': 'comments',
            'avg_completion': 'avg_completion',
          }[sortBy] ??
          'loop_count';

      orderByClause = 'COALESCE(m.$sortColumn, 0) DESC, e.created_at DESC';
    } else {
      orderByClause = 'e.created_at DESC';
    }

    // Use filter.limit or default to 100
    final limit = filter.limit ?? 100;

    final String sql;
    if (needsMetricsJoin) {
      sql =
          '''
        SELECT e.* FROM event e
        LEFT JOIN video_metrics m ON e.id = m.event_id
        WHERE $whereClause
        ORDER BY $orderByClause
        LIMIT ?
      ''';
    } else {
      sql =
          '''
        SELECT * FROM event e
        WHERE $whereClause
        ORDER BY $orderByClause
        LIMIT ?
      ''';
    }

    variables.add(Variable.withInt(limit));

    return customSelect(
      sql,
      variables: variables,
      readsFrom: needsMetricsJoin ? {nostrEvents, videoMetrics} : {nostrEvents},
    );
  }

  /// Get a single event by ID.
  ///
  /// Returns `null` if the event is not found.
  Future<Event?> getEventById(String eventId) async {
    final rows = await customSelect(
      'SELECT * FROM event WHERE id = ? LIMIT 1',
      variables: [Variable.withString(eventId)],
      readsFrom: {nostrEvents},
    ).get();

    if (rows.isEmpty) return null;
    return _rowToEvent(rows.first);
  }

  /// Get a profile (kind 0) event by pubkey.
  ///
  /// Returns the most recent profile event for the given pubkey,
  /// or `null` if no profile is found.
  Future<Event?> getProfileByPubkey(String pubkey) async {
    final rows = await customSelect(
      'SELECT * FROM event WHERE pubkey = ? AND kind = ? '
      'ORDER BY created_at DESC LIMIT 1',
      variables: [
        Variable.withString(pubkey),
        Variable.withInt(EventKind.metadata),
      ],
      readsFrom: {nostrEvents},
    ).get();

    if (rows.isEmpty) return null;
    return _rowToEvent(rows.first);
  }

  /// Delete all events from the cache.
  ///
  /// Returns the number of events deleted.
  Future<int> deleteAllEvents() async {
    return customUpdate(
      'DELETE FROM event',
      updates: {nostrEvents},
      updateKind: UpdateKind.delete,
    );
  }

  /// Delete all events of a specific kind.
  ///
  /// Useful for clearing cached video events (kind 34236) when switching
  /// environments.
  ///
  /// Returns the number of events deleted.
  Future<int> deleteEventsByKind(int kind) async {
    return customUpdate(
      'DELETE FROM event WHERE kind = ?',
      variables: [Variable.withInt(kind)],
      updates: {nostrEvents},
      updateKind: UpdateKind.delete,
    );
  }

  /// Delete a single event by its ID.
  ///
  /// Used when processing NIP-09 deletion events (Kind 5) to remove the
  /// target events from the local cache.
  ///
  /// Returns true if an event was deleted, false if no event was found.
  Future<bool> deleteEventById(String eventId) async {
    final rowsDeleted = await customUpdate(
      'DELETE FROM event WHERE id = ?',
      variables: [Variable.withString(eventId)],
      updates: {nostrEvents},
      updateKind: UpdateKind.delete,
    );
    return rowsDeleted > 0;
  }

  /// Delete multiple events by their IDs.
  ///
  /// Used when processing NIP-09 deletion events (Kind 5) that reference
  /// multiple events via 'e' tags.
  ///
  /// Returns the number of events deleted.
  Future<int> deleteEventsByIds(List<String> eventIds) async {
    if (eventIds.isEmpty) return 0;

    final placeholders = List.filled(eventIds.length, '?').join(', ');
    return customUpdate(
      'DELETE FROM event WHERE id IN ($placeholders)',
      variables: eventIds.map(Variable.withString).toList(),
      updates: {nostrEvents},
      updateKind: UpdateKind.delete,
    );
  }

  /// Convert database row to Event model
  Event _rowToEvent(QueryRow row) {
    final tags = (jsonDecode(row.read<String>('tags')) as List)
        .map((tag) => (tag as List).map((e) => e.toString()).toList())
        .toList();

    final event = Event(
      row.read<String>('pubkey'),
      row.read<int>('kind'),
      tags,
      row.read<String>('content'),
      createdAt: row.read<int>('created_at'),
    );
    // Set id and sig manually since they're stored fields
    return event
      ..id = row.read<String>('id')
      ..sig = row.read<String>('sig');
  }

  /// Extracts the d-tag value from raw tag list (for database queries).
  ///
  /// Returns empty string if no d-tag is found (per NIP-01 spec).
  String _extractDTagFromTags(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.isNotEmpty && tag[0] == 'd') {
        return tag.length > 1 ? tag[1] : '';
      }
    }
    return '';
  }

  // ---------------------------------------------------------------------------
  // Cache Expiry Management
  // ---------------------------------------------------------------------------

  /// Set the expiry timestamp for an existing event.
  ///
  /// Returns true if the event was found and updated, false if not found
  /// or if expire_at column doesn't exist.
  Future<bool> setEventExpiry(String eventId, int expireAt) async {
    // Skip if expire_at column doesn't exist
    if (!db.hasExpireAtColumn) {
      return false;
    }

    final rowsAffected = await customUpdate(
      'UPDATE event SET expire_at = ? WHERE id = ?',
      variables: [
        Variable.withInt(expireAt),
        Variable.withString(eventId),
      ],
      updates: {nostrEvents},
      updateKind: UpdateKind.update,
    );
    return rowsAffected > 0;
  }

  /// Delete events that have expired or have no expiry set.
  ///
  /// If [before] is provided, deletes events expired before that timestamp.
  /// Also deletes events with NULL expire_at (legacy events from before
  /// the mandatory expiry policy).
  ///
  /// Returns the number of events deleted, or 0 if expire_at column doesn't
  /// exist.
  Future<int> deleteExpiredEvents(int? before) async {
    // Skip if expire_at column doesn't exist
    if (!db.hasExpireAtColumn) {
      return 0;
    }

    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return customUpdate(
      'DELETE FROM event WHERE expire_at IS NULL OR expire_at < ?',
      variables: [Variable.withInt(before ?? nowUnix)],
      updates: {nostrEvents},
      updateKind: UpdateKind.delete,
    );
  }

  /// Get the count of events that will expire before [before] Unix timestamp.
  /// Returns 0 if expire_at column doesn't exist.
  Future<int> countExpiredEvents(int before) async {
    // Skip if expire_at column doesn't exist
    if (!db.hasExpireAtColumn) {
      return 0;
    }

    final result = await customSelect(
      'SELECT COUNT(*) as count FROM event '
      'WHERE expire_at IS NOT NULL AND expire_at < ?',
      variables: [Variable.withInt(before)],
      readsFrom: {nostrEvents},
    ).getSingle();
    return result.read<int>('count');
  }

  /// Get total count of all events in the database.
  Future<int> getEventCount() async {
    final result = await customSelect(
      'SELECT COUNT(*) as count FROM event',
      readsFrom: {nostrEvents},
    ).getSingle();
    return result.read<int>('count');
  }
}
