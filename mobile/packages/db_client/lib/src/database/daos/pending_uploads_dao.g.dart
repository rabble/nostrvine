// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_uploads_dao.dart';

// ignore_for_file: type=lint
mixin _$PendingUploadsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingUploadsTable get pendingUploads => attachedDatabase.pendingUploads;
  PendingUploadsDaoManager get managers => PendingUploadsDaoManager(this);
}

class PendingUploadsDaoManager {
  final _$PendingUploadsDaoMixin _db;
  PendingUploadsDaoManager(this._db);
  $$PendingUploadsTableTableManager get pendingUploads =>
      $$PendingUploadsTableTableManager(
        _db.attachedDatabase,
        _db.pendingUploads,
      );
}
