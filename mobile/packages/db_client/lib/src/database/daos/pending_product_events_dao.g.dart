// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_product_events_dao.dart';

// ignore_for_file: type=lint
mixin _$PendingProductEventsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingProductEventsTable get pendingProductEvents =>
      attachedDatabase.pendingProductEvents;
  PendingProductEventsDaoManager get managers =>
      PendingProductEventsDaoManager(this);
}

class PendingProductEventsDaoManager {
  final _$PendingProductEventsDaoMixin _db;
  PendingProductEventsDaoManager(this._db);
  $$PendingProductEventsTableTableManager get pendingProductEvents =>
      $$PendingProductEventsTableTableManager(
        _db.attachedDatabase,
        _db.pendingProductEvents,
      );
}
