// ABOUTME: Data Access Object for pending upload persistence operations.
// ABOUTME: Provides CRUD for upload state management.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:models/models.dart';

part 'pending_uploads_dao.g.dart';

@DriftAccessor(tables: [PendingUploads])
class PendingUploadsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingUploadsDaoMixin {
  PendingUploadsDao(super.attachedDatabase);

  /// Upsert a pending upload from domain model
  Future<void> upsertUpload(PendingUpload upload) {
    return into(pendingUploads).insertOnConflictUpdate(
      PendingUploadsCompanion.insert(
        id: upload.id,
        localVideoPath: upload.localVideoPath,
        nostrPubkey: upload.nostrPubkey,
        status: upload.status.name,
        createdAt: upload.createdAt,
        cloudinaryPublicId: Value(upload.cloudinaryPublicId),
        videoId: Value(upload.videoId),
        cdnUrl: Value(upload.cdnUrl),
        errorMessage: Value(upload.errorMessage),
        uploadProgress: Value(upload.uploadProgress),
        thumbnailPath: Value(upload.thumbnailPath),
        title: Value(upload.title),
        description: Value(upload.description),
        hashtags: Value(
          upload.hashtags != null ? jsonEncode(upload.hashtags) : null,
        ),
        nostrEventId: Value(upload.nostrEventId),
        completedAt: Value(upload.completedAt),
        retryCount: Value(upload.retryCount ?? 0),
        videoWidth: Value(upload.videoWidth),
        videoHeight: Value(upload.videoHeight),
        videoDurationMillis: Value(upload.videoDurationMillis),
        proofManifestJson: Value(upload.proofManifestJson),
        streamingMp4Url: Value(upload.streamingMp4Url),
        streamingHlsUrl: Value(upload.streamingHlsUrl),
        fallbackUrl: Value(upload.fallbackUrl),
      ),
    );
  }

  /// Convert database row to domain model
  PendingUpload _rowToModel(PendingUploadRow row) {
    return PendingUpload(
      id: row.id,
      localVideoPath: row.localVideoPath,
      nostrPubkey: row.nostrPubkey,
      status: UploadStatus.values.firstWhere(
        (e) => e.name == row.status,
        orElse: () => UploadStatus.pending,
      ),
      createdAt: row.createdAt,
      cloudinaryPublicId: row.cloudinaryPublicId,
      videoId: row.videoId,
      cdnUrl: row.cdnUrl,
      errorMessage: row.errorMessage,
      uploadProgress: row.uploadProgress,
      thumbnailPath: row.thumbnailPath,
      title: row.title,
      description: row.description,
      hashtags: row.hashtags != null
          ? (jsonDecode(row.hashtags!) as List).cast<String>()
          : null,
      nostrEventId: row.nostrEventId,
      completedAt: row.completedAt,
      retryCount: row.retryCount,
      videoWidth: row.videoWidth,
      videoHeight: row.videoHeight,
      videoDurationMillis: row.videoDurationMillis,
      proofManifestJson: row.proofManifestJson,
      streamingMp4Url: row.streamingMp4Url,
      streamingHlsUrl: row.streamingHlsUrl,
      fallbackUrl: row.fallbackUrl,
    );
  }

  /// Get upload by ID
  Future<PendingUpload?> getUpload(String id) async {
    final query = select(pendingUploads)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _rowToModel(row) : null;
  }

  Expression<bool> _ownedBy(
    GeneratedColumn<String> column,
    String ownerPubkey,
  ) {
    return column.equals(ownerPubkey);
  }

  /// Get all pending uploads for [ownerPubkey] (not completed/failed).
  Future<List<PendingUpload>> getPendingUploads({
    required String ownerPubkey,
  }) async {
    final query = select(pendingUploads)
      ..where(
        (t) =>
            _ownedBy(t.nostrPubkey, ownerPubkey) &
            t.status.isNotIn(['published', 'failed']),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Get all uploads for [ownerPubkey] sorted by creation time.
  Future<List<PendingUpload>> getAllUploads({
    required String ownerPubkey,
  }) async {
    final query = select(pendingUploads)
      ..where((t) => _ownedBy(t.nostrPubkey, ownerPubkey))
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Get uploads for [ownerPubkey] by status.
  Future<List<PendingUpload>> getUploadsByStatus(
    UploadStatus status, {
    required String ownerPubkey,
  }) async {
    final query = select(pendingUploads)
      ..where(
        (t) =>
            _ownedBy(t.nostrPubkey, ownerPubkey) & t.status.equals(status.name),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Get all uploads across every owner for maintenance tasks.
  Future<List<PendingUpload>> getAllUploadsForMaintenance() async {
    final query = select(pendingUploads)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Get all non-terminal uploads across every owner for maintenance tasks.
  Future<List<PendingUpload>> getPendingUploadsForMaintenance() async {
    final query = select(pendingUploads)
      ..where((t) => t.status.isNotIn(['published', 'failed']))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Get uploads with [status] across every owner for maintenance tasks.
  Future<List<PendingUpload>> getUploadsByStatusForMaintenance(
    UploadStatus status,
  ) async {
    final query = select(pendingUploads)
      ..where((t) => t.status.equals(status.name))
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Update upload status
  Future<bool> updateStatus(
    String id,
    UploadStatus status, {
    String? errorMessage,
    double? uploadProgress,
  }) async {
    final rowsAffected =
        await (update(pendingUploads)..where((t) => t.id.equals(id))).write(
          PendingUploadsCompanion(
            status: Value(status.name),
            errorMessage: errorMessage != null
                ? Value(errorMessage)
                : const Value.absent(),
            uploadProgress: uploadProgress != null
                ? Value(uploadProgress)
                : const Value.absent(),
          ),
        );
    return rowsAffected > 0;
  }

  /// Delete upload by ID
  Future<int> deleteUpload(String id) {
    return (delete(pendingUploads)..where((t) => t.id.equals(id))).go();
  }

  /// Delete completed uploads (published or failed)
  Future<int> deleteCompleted() {
    return (delete(
      pendingUploads,
    )..where((t) => t.status.isIn(['published', 'failed']))).go();
  }

  /// Watch all uploads for [ownerPubkey] (reactive stream).
  Stream<List<PendingUpload>> watchAllUploads({required String ownerPubkey}) {
    final query = select(pendingUploads)
      ..where((t) => _ownedBy(t.nostrPubkey, ownerPubkey))
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Watch pending uploads for [ownerPubkey] (reactive stream).
  Stream<List<PendingUpload>> watchPendingUploads({
    required String ownerPubkey,
  }) {
    final query = select(pendingUploads)
      ..where(
        (t) =>
            _ownedBy(t.nostrPubkey, ownerPubkey) &
            t.status.isNotIn(['published', 'failed']),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Watch all uploads across every owner for maintenance tasks.
  Stream<List<PendingUpload>> watchAllUploadsForMaintenance() {
    final query = select(pendingUploads)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Watch pending uploads across every owner for maintenance tasks.
  Stream<List<PendingUpload>> watchPendingUploadsForMaintenance() {
    final query = select(pendingUploads)
      ..where((t) => t.status.isNotIn(['published', 'failed']))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Clear all uploads
  Future<int> clearAll() {
    return delete(pendingUploads).go();
  }

  /// Delete all uploads for [userPubkey].
  ///
  /// Used on destructive sign-out to prevent cross-account data leaks.
  Future<int> deleteAllForUser(String userPubkey) {
    return (delete(
      pendingUploads,
    )..where((t) => t.nostrPubkey.equals(userPubkey))).go();
  }
}
