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

  /// Returns an expression that limits results to a specific owner.
  ///
  /// Because [nostrPubkey] is non-nullable on [PendingUploads] (every row
  /// has been written with a valid pubkey since the table was created),
  /// there are no legacy NULL rows to surface. A simple equality filter is
  /// sufficient — no "owned OR NULL" arm is needed.
  ///
  /// When [nostrPubkey] is null the filter is a no-op, preserving the
  /// existing behaviour for callers that do not yet supply an owner (e.g.
  /// admin/debug tooling or migration paths).
  Expression<bool> _ownedBy(
    PendingUploads t,
    String? nostrPubkey,
  ) {
    if (nostrPubkey == null) return const Constant(true);
    return t.nostrPubkey.equals(nostrPubkey);
  }

  /// Get all pending uploads (not completed/failed) for [nostrPubkey].
  ///
  /// Pass [nostrPubkey] to scope results to a specific account. Omitting it
  /// returns all accounts' uploads (use only when no account context exists).
  Future<List<PendingUpload>> getPendingUploads({String? nostrPubkey}) async {
    final query = select(pendingUploads)
      ..where(
        (t) =>
            t.status.isNotIn(['published', 'failed']) &
            _ownedBy(t, nostrPubkey),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Get all uploads sorted by creation time for [nostrPubkey].
  ///
  /// Pass [nostrPubkey] to scope results to a specific account. Omitting it
  /// returns all accounts' uploads (use only when no account context exists).
  Future<List<PendingUpload>> getAllUploads({String? nostrPubkey}) async {
    final query = select(pendingUploads)
      ..where((t) => _ownedBy(t, nostrPubkey))
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Get uploads by status for [nostrPubkey].
  ///
  /// Pass [nostrPubkey] to scope results to a specific account. Omitting it
  /// returns all accounts' uploads (use only when no account context exists).
  Future<List<PendingUpload>> getUploadsByStatus(
    UploadStatus status, {
    String? nostrPubkey,
  }) async {
    final query = select(pendingUploads)
      ..where(
        (t) => t.status.equals(status.name) & _ownedBy(t, nostrPubkey),
      )
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

  /// Watch all uploads (reactive stream) for [nostrPubkey].
  ///
  /// Pass [nostrPubkey] to scope results to a specific account. Omitting it
  /// returns all accounts' uploads (use only when no account context exists).
  Stream<List<PendingUpload>> watchAllUploads({String? nostrPubkey}) {
    final query = select(pendingUploads)
      ..where((t) => _ownedBy(t, nostrPubkey))
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Watch pending uploads (reactive stream) for [nostrPubkey].
  ///
  /// Pass [nostrPubkey] to scope results to a specific account. Omitting it
  /// returns all accounts' uploads (use only when no account context exists).
  Stream<List<PendingUpload>> watchPendingUploads({String? nostrPubkey}) {
    final query = select(pendingUploads)
      ..where(
        (t) =>
            t.status.isNotIn(['published', 'failed']) &
            _ownedBy(t, nostrPubkey),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Delete completed (published or failed) uploads for [nostrPubkey].
  ///
  /// Pass [nostrPubkey] to scope deletion to a specific account. Omitting it
  /// deletes completed uploads across all accounts.
  Future<int> deleteCompleted({String? nostrPubkey}) {
    return (delete(pendingUploads)..where(
          (t) =>
              t.status.isIn(['published', 'failed']) & _ownedBy(t, nostrPubkey),
        ))
        .go();
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
