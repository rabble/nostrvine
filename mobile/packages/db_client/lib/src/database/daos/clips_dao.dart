// ABOUTME: Data Access Object for video clip persistence operations.
// ABOUTME: Provides CRUD with draft-scoped queries, ordering, and
// ABOUTME: per-account isolation via ownerPubkey.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

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

  /// Whether a clip is a *library* clip: it has no draft association, or (when
  /// [includeAutosaveDraftId] is given) it belongs to the throwaway autosave /
  /// recording-scratch draft. Clips saved into a named project are excluded.
  Expression<bool> _isLibraryClip(
    GeneratedColumn<String> draftIdColumn,
    String? includeAutosaveDraftId,
  ) {
    if (includeAutosaveDraftId == null) return draftIdColumn.isNull();
    return draftIdColumn.isNull() |
        draftIdColumn.equals(includeAutosaveDraftId);
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
  /// trashed clips unless [includeTrashed] is true. When [ownerPubkey] is
  /// provided, returns only clips owned by that account **plus** legacy
  /// clips with no owner.
  ///
  /// [includeTrashed] is for file-reference scans that must keep a
  /// trashed (restorable) clip's files alive — active-clip listings should
  /// leave it at its default.
  Future<List<ClipRow>> getAllClips({
    int? limit,
    String? ownerPubkey,
    bool includeTrashed = false,
  }) {
    final query = select(clips)
      ..where(
        (t) => includeTrashed
            ? _ownedOrLegacy(t.ownerPubkey, ownerPubkey)
            : _ownedOrLegacy(t.ownerPubkey, ownerPubkey) & t.deletedAt.isNull(),
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

  /// Get all library clips, newest first. Excludes trashed clips. When
  /// [ownerPubkey] is provided, returns only clips owned by that account
  /// **plus** legacy clips with no owner.
  ///
  /// Clips in a named draft are excluded; when [includeAutosaveDraftId] is
  /// given, clips in that throwaway autosave draft are included so a
  /// just-recorded clip stays visible while the editor holds it in autosave.
  Future<List<ClipRow>> getLibraryClips({
    int? limit,
    String? ownerPubkey,
    String? includeAutosaveDraftId,
  }) {
    final query = select(clips)
      ..where(
        (t) =>
            _isLibraryClip(t.draftId, includeAutosaveDraftId) &
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
  Stream<List<ClipRow>> watchLibraryClips({
    String? ownerPubkey,
    String? includeAutosaveDraftId,
  }) {
    final query = select(clips)
      ..where(
        (t) =>
            _isLibraryClip(t.draftId, includeAutosaveDraftId) &
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
  /// to be hard-deleted by the purge sweep. When [ownerPubkey] is provided,
  /// returns only clips owned by that account **plus** legacy clips with no
  /// owner.
  Future<List<ClipRow>> getTrashedClipsOlderThan(
    DateTime cutoff, {
    String? ownerPubkey,
  }) {
    final query = select(clips)
      ..where(
        (t) =>
            _ownedOrLegacy(t.ownerPubkey, ownerPubkey) &
            t.deletedAt.isNotNull() &
            t.deletedAt.isSmallerThanValue(cutoff),
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

  /// Check if a filename is referenced by any clip-owned file reference.
  ///
  /// Prefer [referencedFilenames] when checking more than one file — the JSON
  /// scan below is unindexed, so a per-file loop pays for a full scan each.
  Future<bool> isFileReferenced(String filename) async {
    final referenced = await referencedFilenames({filename});
    return referenced.isNotEmpty;
  }

  /// The subset of [filenames] referenced by any clip-owned file reference.
  ///
  /// The indexed `file_path` / `thumbnail_path` columns cover normal clips and
  /// thumbnail assets. Frames-only stop-motion clips have no `file_path`; their
  /// source stills live inside the JSON `data` blob as
  /// `stopMotionFrames[].path`, so candidate JSON rows are decoded and checked
  /// before cleanup deletes a shared frame file.
  ///
  /// Resolves the whole set in a single scan rather than one per filename:
  /// `data` is unindexed, and deleting one stop-motion session asks about every
  /// still in it at once.
  Future<Set<String>> referencedFilenames(Set<String> filenames) async {
    if (filenames.isEmpty) return const <String>{};

    final referenced = <String>{};
    final indexedRows =
        await (selectOnly(clips)
              ..addColumns([clips.filePath, clips.thumbnailPath])
              ..where(
                clips.filePath.isIn(filenames) |
                    clips.thumbnailPath.isIn(filenames),
              ))
            .get();
    for (final row in indexedRows) {
      final filePath = row.read(clips.filePath);
      final thumbnailPath = row.read(clips.thumbnailPath);
      if (filePath != null && filenames.contains(filePath)) {
        referenced.add(filePath);
      }
      if (thumbnailPath != null && filenames.contains(thumbnailPath)) {
        referenced.add(thumbnailPath);
      }
    }

    final unresolved = filenames.difference(referenced).toList();
    if (unresolved.isEmpty) return referenced;

    // One full JSON scan for every remaining filename. The data column is
    // unindexed, so an OR-chain of LIKE predicates still scans the table and
    // can exceed SQLite's expression-depth limit for large stop-motion sets.
    final candidateRows = await customSelect(
      'SELECT data FROM clips',
      readsFrom: {clips},
    ).get();

    for (final row in candidateRows) {
      final Object? data;
      try {
        data = json.decode(row.read<String>('data'));
      } on FormatException {
        continue;
      }
      for (final filename in unresolved) {
        if (referenced.contains(filename)) continue;
        if (_jsonReferencesFilename(data, filename)) referenced.add(filename);
      }
    }

    return referenced;
  }

  static const _jsonFilePathKeys = {
    'filePath',
    'thumbnailPath',
    'ghostFramePath',
    'forwardVideoPath',
    'reversedVideoPath',
    'path',
  };

  static bool _jsonReferencesFilename(
    Object? value,
    String filename, {
    String? key,
  }) {
    if (value is String) {
      return key != null &&
          _jsonFilePathKeys.contains(key) &&
          p.basename(value) == filename;
    }

    if (value is Map) {
      for (final entry in value.entries) {
        if (_jsonReferencesFilename(
          entry.value,
          filename,
          key: entry.key.toString(),
        )) {
          return true;
        }
      }
      return false;
    }

    if (value is Iterable) {
      return value.any((item) => _jsonReferencesFilename(item, filename));
    }

    return false;
  }
}
