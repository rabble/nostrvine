// ABOUTME: DAO for unbounded seen-video set (id + last-seen).
// ABOUTME: Backs wasSeenRecently without decoding rich metrics.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'seen_videos_dao.g.dart';

@DriftAccessor(tables: [SeenVideos])
class SeenVideosDao extends DatabaseAccessor<AppDatabase>
    with _$SeenVideosDaoMixin {
  SeenVideosDao(super.attachedDatabase);

  /// Upserts a single seen video.
  Future<void> markSeen(
    String videoId, {
    required int firstSeenAt,
    required int lastSeenAt,
  }) {
    return into(seenVideos).insert(
      SeenVideosCompanion.insert(
        videoId: videoId,
        firstSeenAt: firstSeenAt,
        lastSeenAt: lastSeenAt,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Upserts many seen videos in a single batch.
  Future<void> markSeenBatch(List<SeenVideoRow> rows) async {
    await batch((b) {
      for (final row in rows) {
        b.insert(
          seenVideos,
          SeenVideosCompanion.insert(
            videoId: row.videoId,
            firstSeenAt: row.firstSeenAt,
            lastSeenAt: row.lastSeenAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Raw batch upsert from videoIds + timestamps (avoid building rows).
  Future<void> upsertBatch(
    Iterable<String> videoIds, {
    required int nowMs,
  }) async {
    await batch((b) {
      for (final id in videoIds) {
        b.insert(
          seenVideos,
          SeenVideosCompanion.insert(
            videoId: id,
            firstSeenAt: nowMs,
            lastSeenAt: nowMs,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Whether [videoId] was seen at all.
  Future<bool> hasSeen(String videoId) async {
    final q = select(seenVideos)
      ..where((t) => t.videoId.equals(videoId))
      ..limit(1);
    return await q.getSingleOrNull() != null;
  }

  /// Whether [videoId] was seen within [within] (e.g. 24h).
  Future<bool> wasSeenRecently(
    String videoId, {
    Duration within = const Duration(hours: 24),
  }) async {
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - within.inMilliseconds;
    final q = select(seenVideos)
      ..where((t) => t.videoId.equals(videoId))
      ..where((t) => t.lastSeenAt.isBiggerThanValue(cutoff))
      ..limit(1);
    return await q.getSingleOrNull() != null;
  }

  /// Synchronous in-memory-style check using a preloaded map — prefer
  /// [wasSeenRecently] for DB truth; this is for tests.
  Future<Set<String>> getAllSeenIds() async {
    final rows = await select(seenVideos).get();
    return rows.map((r) => r.videoId).toSet();
  }

  /// All rows, for migration verification / debug.
  Future<List<SeenVideoRow>> getAll() => select(seenVideos).get();

  /// Remove a single id (mark as unseen).
  Future<int> remove(String videoId) {
    return (delete(seenVideos)..where((t) => t.videoId.equals(videoId))).go();
  }

  /// Clear all (test / user preference).
  Future<int> clearAll() => delete(seenVideos).go();

  /// Delete entries older than [ttl] (default 1 year) — called on startup.
  Future<int> pruneExpired({Duration ttl = const Duration(days: 365)}) async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - ttl.inMilliseconds;
    return (delete(seenVideos)
          ..where((t) => t.lastSeenAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Count total rows.
  Future<int> count() async {
    final r =
        await customSelect('SELECT COUNT(*) AS c FROM seen_videos')
            .getSingle();
    return r.read<int>('c');
  }
}
