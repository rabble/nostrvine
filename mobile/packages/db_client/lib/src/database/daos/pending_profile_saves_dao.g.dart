// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_profile_saves_dao.dart';

// ignore_for_file: type=lint
mixin _$PendingProfileSavesDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingProfileSavesTable get pendingProfileSaves =>
      attachedDatabase.pendingProfileSaves;
  PendingProfileSavesDaoManager get managers =>
      PendingProfileSavesDaoManager(this);
}

class PendingProfileSavesDaoManager {
  final _$PendingProfileSavesDaoMixin _db;
  PendingProfileSavesDaoManager(this._db);
  $$PendingProfileSavesTableTableManager get pendingProfileSaves =>
      $$PendingProfileSavesTableTableManager(
        _db.attachedDatabase,
        _db.pendingProfileSaves,
      );
}
