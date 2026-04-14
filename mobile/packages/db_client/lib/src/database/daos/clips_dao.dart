// ABOUTME: Data Access Object for video clip persistence operations.
// ABOUTME: Provides CRUD with draft-scoped queries, ordering, and
// ABOUTME: per-account isolation via ownerPubkey.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'clips_dao.g.dart';

@DriftAccessor(tables: [Clips])
class ClipsDao extends DatabaseAccessor<AppDatabase> with _$ClipsDaoMixin {
  ClipsDao(super.attachedDatabase);

  /// Upsert a clip (insert or update on conflict)
  Future<void> upsertClip({
    required String id,
    required int orderIndex,
    required int durationMs,
    required DateTime recordedAt,
    required String data,
    required String? filePath,
    required String? thumbnailPath,
    String? draftId,
    String? ownerPubkey,
  }) {
    return into(clips).insertOnConflictUpdate(
      ClipsCompanion.insert(
        id: id,
        draftId: Value(draftId),
        orderIndex: Value(orderIndex),
        durationMs: durationMs,
        recordedAt: recordedAt,
        data: data,
        filePath: Value(filePath),
        thumbnailPath: Value(thumbnailPath),
        ownerPubkey: Value(ownerPubkey),
      ),
    );
  }

  /// Build a filter expression that returns rows owned by [ownerPubkey]
  /// **or** legacy rows with no owner (NULL).
  Expression<bool> _ownedOrLegacy(
    GeneratedColumn<String> column,
    String? ownerPubkey,
  ) {
    if (ownerPubkey == null) return const Constant(true);
    return column.equals(ownerPubkey) | column.isNull();
  }

  /// Get all clips for a draft
  Future<List<ClipRow>> getClipsByDraftId(String draftId) {
    final query = select(clips)
      ..where((t) => t.draftId.equals(draftId))
      ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]);
    return query.get();
  }

  /// Get a single clip by ID
  Future<ClipRow?> getClipById(String id) {
    return (select(clips)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get all clips sorted by recorded date (newest first).
  /// When [ownerPubkey] is provided, returns only clips owned by that
  /// account **plus** legacy clips with no owner.
  Future<List<ClipRow>> getAllClips({int? limit, String? ownerPubkey}) {
    final query = select(clips)
      ..where((t) => _ownedOrLegacy(t.ownerPubkey, ownerPubkey))
      ..orderBy([
        (t) => OrderingTerm(expression: t.recordedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Update the order index of a clip
  Future<bool> updateOrderIndex({
    required String id,
    required int orderIndex,
  }) async {
    final rowsAffected = await (update(clips)..where((t) => t.id.equals(id)))
        .write(ClipsCompanion(orderIndex: Value(orderIndex)));
    return rowsAffected > 0;
  }

  /// Delete a clip by ID
  Future<int> deleteClip(String id) {
    return (delete(clips)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all clips belonging to a draft
  Future<int> deleteClipsByDraftId(String draftId) {
    return (delete(clips)..where((t) => t.draftId.equals(draftId))).go();
  }

  /// Watch all clips for a draft (reactive stream)
  Stream<List<ClipRow>> watchClipsByDraftId(String draftId) {
    final query = select(clips)
      ..where((t) => t.draftId.equals(draftId))
      ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]);
    return query.watch();
  }

  /// Watch a single clip by ID (reactive stream)
  Stream<ClipRow?> watchClipById(String id) {
    return (select(clips)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// Get count of clips for a draft
  Future<int> getCountByDraftId(String draftId) async {
    final query = selectOnly(clips)
      ..where(clips.draftId.equals(draftId))
      ..addColumns([clips.id.count()]);
    final result = await query.getSingle();
    return result.read(clips.id.count()) ?? 0;
  }

  // -- Library clip methods (draftId IS NULL) --

  /// Get all library clips (no draft association), newest first.
  /// When [ownerPubkey] is provided, returns only clips owned by that
  /// account **plus** legacy clips with no owner.
  Future<List<ClipRow>> getLibraryClips({int? limit, String? ownerPubkey}) {
    final query = select(clips)
      ..where(
        (t) => t.draftId.isNull() & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.recordedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Watch all library clips (reactive stream).
  /// When [ownerPubkey] is provided, returns only clips owned by that
  /// account **plus** legacy clips with no owner.
  Stream<List<ClipRow>> watchLibraryClips({String? ownerPubkey}) {
    final query = select(clips)
      ..where(
        (t) => t.draftId.isNull() & _ownedOrLegacy(t.ownerPubkey, ownerPubkey),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.recordedAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  /// Delete all library clips (draftId IS NULL)
  Future<int> clearLibraryClips() {
    return (delete(clips)..where((t) => t.draftId.isNull())).go();
  }

  /// Clear all clips
  Future<int> clearAll() {
    return delete(clips).go();
  }

  /// Delete all clips owned by [userPubkey].
  ///
  /// Legacy clips with NULL ownerPubkey are preserved because they
  /// cannot be attributed to any specific account.
  /// Used on destructive sign-out to prevent cross-account data leaks.
  Future<int> deleteAllForUser(String userPubkey) {
    return (delete(clips)..where((t) => t.ownerPubkey.equals(userPubkey))).go();
  }

  /// Claim legacy clips (NULL ownerPubkey) for [ownerPubkey].
  ///
  /// Called during session setup so that pre-multi-account clips are
  /// attributed to the user who created them and stop being visible
  /// to other accounts via the `_ownedOrLegacy` filter.
  Future<int> claimLegacyRows(String ownerPubkey) {
    return (update(clips)..where((t) => t.ownerPubkey.isNull())).write(
      ClipsCompanion(ownerPubkey: Value(ownerPubkey)),
    );
  }

  /// Check if a filename is referenced by any clip's file_path
  /// or thumbnail_path.
  Future<bool> isFileReferenced(String filename) async {
    final query = selectOnly(clips)
      ..addColumns([clips.id.count()])
      ..where(
        clips.filePath.equals(filename) | clips.thumbnailPath.equals(filename),
      );
    final result = await query.getSingle();
    return (result.read(clips.id.count()) ?? 0) > 0;
  }
}
