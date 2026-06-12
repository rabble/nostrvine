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

  /// Get all clips for a draft. Excludes trashed clips.
  Future<List<ClipRow>> getClipsByDraftId(String draftId) {
    final query = select(clips)
      ..where((t) => t.draftId.equals(draftId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]);
    return query.get();
  }

  /// Get a single clip by ID. Returns trashed clips too — callers that
  /// only want active clips must filter on [ClipRow.deletedAt] themselves.
  Future<ClipRow?> getClipById(String id) {
    return (select(clips)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get all clips sorted by recorded date (newest first). Excludes
  /// trashed clips. When [ownerPubkey] is provided, returns only clips
  /// owned by that account **plus** legacy clips with no owner.
  Future<List<ClipRow>> getAllClips({int? limit, String? ownerPubkey}) {
    final query = select(clips)
      ..where(
        (t) =>
            _ownedOrLegacy(t.ownerPubkey, ownerPubkey) & t.deletedAt.isNull(),
      )
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

  /// Watch all clips for a draft (reactive stream). Excludes trashed clips.
  Stream<List<ClipRow>> watchClipsByDraftId(String draftId) {
    final query = select(clips)
      ..where((t) => t.draftId.equals(draftId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]);
    return query.watch();
  }

  /// Watch a single clip by ID (reactive stream)
  Stream<ClipRow?> watchClipById(String id) {
    return (select(clips)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// Get count of clips for a draft. Excludes trashed clips.
  Future<int> getCountByDraftId(String draftId) async {
    final query = selectOnly(clips)
      ..where(clips.draftId.equals(draftId) & clips.deletedAt.isNull())
      ..addColumns([clips.id.count()]);
    final result = await query.getSingle();
    return result.read(clips.id.count()) ?? 0;
  }

  // -- Library clip methods (draftId IS NULL) --

  /// Get all library clips (no draft association), newest first.
  /// Excludes trashed clips. When [ownerPubkey] is provided, returns
  /// only clips owned by that account **plus** legacy clips with no
  /// owner.
  Future<List<ClipRow>> getLibraryClips({int? limit, String? ownerPubkey}) {
    final query = select(clips)
      ..where(
        (t) =>
            t.draftId.isNull() &
            _ownedOrLegacy(t.ownerPubkey, ownerPubkey) &
            t.deletedAt.isNull(),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.recordedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Watch all library clips (reactive stream). Excludes trashed clips.
  /// When [ownerPubkey] is provided, returns only clips owned by that
  /// account **plus** legacy clips with no owner.
  Stream<List<ClipRow>> watchLibraryClips({String? ownerPubkey}) {
    final query = select(clips)
      ..where(
        (t) =>
            t.draftId.isNull() &
            _ownedOrLegacy(t.ownerPubkey, ownerPubkey) &
            t.deletedAt.isNull(),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.recordedAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  // -- Trash methods --

  /// Mark a clip as trashed at `deletedAt`. Also nulls out `draftId`
  /// when `clearDraftId` is true, decoupling the clip from any draft
  /// session.
  ///
  /// Returns true if a row was updated.
  Future<bool> softDeleteClip({
    required String id,
    required DateTime deletedAt,
    bool clearDraftId = false,
  }) async {
    final companion = clearDraftId
        ? ClipsCompanion(
            deletedAt: Value(deletedAt),
            draftId: const Value(null),
          )
        : ClipsCompanion(deletedAt: Value(deletedAt));
    final rows = await (update(
      clips,
    )..where((t) => t.id.equals(id))).write(companion);
    return rows > 0;
  }

  /// Restore a trashed clip by clearing its `deletedAt` marker. Leaves
  /// `draftId` untouched; the clip lands wherever it was last attached
  /// (library when `draftId` is NULL).
  ///
  /// Returns true if a row was updated.
  Future<bool> restoreClip(String id) async {
    final rows = await (update(clips)..where((t) => t.id.equals(id))).write(
      const ClipsCompanion(deletedAt: Value(null)),
    );
    return rows > 0;
  }

  /// Get all trashed library clips, newest-deleted-first.
  /// When [ownerPubkey] is provided, returns only clips owned by that
  /// account **plus** legacy clips with no owner.
  Future<List<ClipRow>> getTrashedLibraryClips({String? ownerPubkey}) {
    final query = select(clips)
      ..where(
        (t) =>
            t.draftId.isNull() &
            _ownedOrLegacy(t.ownerPubkey, ownerPubkey) &
            t.deletedAt.isNotNull(),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
      ]);
    return query.get();
  }

  /// Watch all trashed library clips (reactive stream).
  Stream<List<ClipRow>> watchTrashedLibraryClips({String? ownerPubkey}) {
    final query = select(clips)
      ..where(
        (t) =>
            t.draftId.isNull() &
            _ownedOrLegacy(t.ownerPubkey, ownerPubkey) &
            t.deletedAt.isNotNull(),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  /// Get trashed clips whose `deletedAt` is older than [cutoff], ready
  /// to be hard-deleted by the purge sweep.
  Future<List<ClipRow>> getTrashedClipsOlderThan(DateTime cutoff) {
    final query = select(clips)
      ..where(
        (t) => t.deletedAt.isNotNull() & t.deletedAt.isSmallerThanValue(cutoff),
      );
    return query.get();
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

  /// Claim legacy clips (NULL ownerPubkey) or rows owned by the optional
  /// [sourceOwnerPubkey] marker for [newOwnerPubkey].
  ///
  /// Called during session setup so that pre-multi-account clips are
  /// attributed to the user who created them and signed-out recorder clips
  /// are claimed by the next successful sign-in.
  Future<int> claimLegacyRows(
    String newOwnerPubkey, {
    String? sourceOwnerPubkey,
  }) {
    return (update(clips)..where(
          (t) => sourceOwnerPubkey == null
              ? t.ownerPubkey.isNull()
              : t.ownerPubkey.isNull() |
                    t.ownerPubkey.equals(sourceOwnerPubkey),
        ))
        .write(ClipsCompanion(ownerPubkey: Value(newOwnerPubkey)));
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
