// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_gift_wraps_dao.dart';

// ignore_for_file: type=lint
mixin _$PendingGiftWrapsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingGiftWrapsTable get pendingGiftWraps =>
      attachedDatabase.pendingGiftWraps;
  PendingGiftWrapsDaoManager get managers => PendingGiftWrapsDaoManager(this);
}

class PendingGiftWrapsDaoManager {
  final _$PendingGiftWrapsDaoMixin _db;
  PendingGiftWrapsDaoManager(this._db);
  $$PendingGiftWrapsTableTableManager get pendingGiftWraps =>
      $$PendingGiftWrapsTableTableManager(
        _db.attachedDatabase,
        _db.pendingGiftWraps,
      );
}
