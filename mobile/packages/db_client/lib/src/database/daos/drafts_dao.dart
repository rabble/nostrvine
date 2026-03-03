// ABOUTME: Data Access Object for video draft persistence operations.
// ABOUTME: Provides CRUD with publish-status filtering and timestamp
// ABOUTME: ordering.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'drafts_dao.g.dart';

/// Data transfer object for clip insertion within a transaction.
class DraftClipData {
  const DraftClipData({
    required this.id,
    required this.orderIndex,
    required this.durationMs,
    required this.recordedAt,
    required this.data,
    this.filePath,
    this.thumbnailPath,
  });

  final String id;
  final int orderIndex;
  final int durationMs;
  final DateTime recordedAt;
  final String data;
  final String? filePath;
  final String? thumbnailPath;
}

@DriftAccessor(tables: [Drafts, Clips])
class DraftsDao extends DatabaseAccessor<AppDatabase> with _$DraftsDaoMixin {
  DraftsDao(super.attachedDatabase);

  /// Upsert a draft (insert or update on conflict)
  Future<void> upsertDraft({
    required String id,
    required String title,
    required String description,
    required String publishStatus,
    required DateTime createdAt,
    required DateTime lastModified,
    required String data,
    required String? renderedFilePath,
    required String? renderedThumbnailPath,
    int publishAttempts = 0,
    String? publishError,
  }) {
    return into(drafts).insertOnConflictUpdate(
      DraftsCompanion.insert(
        id: id,
        title: Value(title),
        description: Value(description),
        publishStatus: Value(publishStatus),
        publishAttempts: Value(publishAttempts),
        publishError: Value(publishError),
        createdAt: createdAt,
        lastModified: lastModified,
        data: data,
        renderedFilePath: Value(renderedFilePath),
        renderedThumbnailPath: Value(renderedThumbnailPath),
      ),
    );
  }

  /// Get all drafts sorted by last modified (newest first)
  Future<List<DraftRow>> getAllDrafts({int? limit}) {
    final query = select(drafts)
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.lastModified,
          mode: OrderingMode.desc,
        ),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Get a single draft by ID
  Future<DraftRow?> getDraftById(String id) {
    return (select(drafts)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get drafts filtered by publish status
  Future<List<DraftRow>> getDraftsByStatus(String status, {int? limit}) {
    final query = select(drafts)
      ..where((t) => t.publishStatus.equals(status))
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.lastModified,
          mode: OrderingMode.desc,
        ),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Update publish status and optionally error/attempts
  Future<bool> updatePublishStatus({
    required String id,
    required String publishStatus,
    String? publishError,
    int? publishAttempts,
  }) async {
    final rowsAffected = await (update(drafts)..where((t) => t.id.equals(id)))
        .write(
          DraftsCompanion(
            publishStatus: Value(publishStatus),
            publishError: Value(publishError),
            publishAttempts: publishAttempts != null
                ? Value(publishAttempts)
                : const Value.absent(),
            lastModified: Value(DateTime.now()),
          ),
        );
    return rowsAffected > 0;
  }

  /// Delete a draft by ID
  Future<int> deleteDraft(String id) {
    return (delete(drafts)..where((t) => t.id.equals(id))).go();
  }

  /// Delete drafts older than a given date
  Future<int> deleteOlderThan(DateTime dateTime) {
    return (delete(
      drafts,
    )..where((t) => t.lastModified.isSmallerThanValue(dateTime))).go();
  }

  /// Watch all drafts (reactive stream)
  Stream<List<DraftRow>> watchAllDrafts({int? limit}) {
    final query = select(drafts)
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.lastModified,
          mode: OrderingMode.desc,
        ),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch();
  }

  /// Watch a single draft by ID (reactive stream)
  Stream<DraftRow?> watchDraftById(String id) {
    return (select(drafts)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// Watch drafts filtered by publish status (reactive stream)
  Stream<List<DraftRow>> watchDraftsByStatus(
    String status, {
    int? limit,
  }) {
    final query = select(drafts)
      ..where((t) => t.publishStatus.equals(status))
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.lastModified,
          mode: OrderingMode.desc,
        ),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch();
  }

  /// Get count of drafts by publish status
  Future<int> getCountByStatus(String status) async {
    final query = selectOnly(drafts)
      ..where(drafts.publishStatus.equals(status))
      ..addColumns([drafts.id.count()]);
    final result = await query.getSingle();
    return result.read(drafts.id.count()) ?? 0;
  }

  /// Get total count of all drafts
  Future<int> getCount() async {
    final query = selectOnly(drafts)..addColumns([drafts.id.count()]);
    final result = await query.getSingle();
    return result.read(drafts.id.count()) ?? 0;
  }

  /// Clear all drafts
  Future<int> clearAll() {
    return delete(drafts).go();
  }

  /// Check if a filename is referenced by any draft's
  /// rendered_file_path or rendered_thumbnail_path.
  Future<bool> isRenderedFileReferenced(String filename) async {
    final query = selectOnly(drafts)
      ..addColumns([drafts.id.count()])
      ..where(
        drafts.renderedFilePath.equals(filename) |
            drafts.renderedThumbnailPath.equals(filename),
      );
    final result = await query.getSingle();
    return (result.read(drafts.id.count()) ?? 0) > 0;
  }

  /// Atomically save a draft and its clips in a single transaction.
  ///
  /// This ensures readers never observe a draft with 0 clips during updates.
  Future<void> saveDraftWithClips({
    required String id,
    required String title,
    required String description,
    required String publishStatus,
    required DateTime createdAt,
    required DateTime lastModified,
    required String data,
    required String? renderedFilePath,
    required String? renderedThumbnailPath,
    required List<DraftClipData> clipDataList,
    int publishAttempts = 0,
    String? publishError,
  }) {
    return transaction(() async {
      // 1. Upsert the draft row
      await into(drafts).insertOnConflictUpdate(
        DraftsCompanion.insert(
          id: id,
          title: Value(title),
          description: Value(description),
          publishStatus: Value(publishStatus),
          publishAttempts: Value(publishAttempts),
          publishError: Value(publishError),
          createdAt: createdAt,
          lastModified: lastModified,
          data: data,
          renderedFilePath: Value(renderedFilePath),
          renderedThumbnailPath: Value(renderedThumbnailPath),
        ),
      );

      // 2. Delete existing clips for this draft
      await (delete(clips)..where((t) => t.draftId.equals(id))).go();

      // 3. Insert new clips
      for (final clipData in clipDataList) {
        await into(clips).insertOnConflictUpdate(
          ClipsCompanion.insert(
            id: '$id:${clipData.id}',
            draftId: Value(id),
            orderIndex: Value(clipData.orderIndex),
            durationMs: clipData.durationMs,
            recordedAt: clipData.recordedAt,
            data: clipData.data,
            filePath: Value(clipData.filePath),
            thumbnailPath: Value(clipData.thumbnailPath),
          ),
        );
      }
    });
  }
}
