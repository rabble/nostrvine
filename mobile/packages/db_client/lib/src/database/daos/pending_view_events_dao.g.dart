// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_view_events_dao.dart';

// ignore_for_file: type=lint
mixin _$PendingViewEventsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingViewEventsTable get pendingViewEvents =>
      attachedDatabase.pendingViewEvents;
  PendingViewEventsDaoManager get managers => PendingViewEventsDaoManager(this);
}

class PendingViewEventsDaoManager {
  final _$PendingViewEventsDaoMixin _db;
  PendingViewEventsDaoManager(this._db);
  $$PendingViewEventsTableTableManager get pendingViewEvents =>
      $$PendingViewEventsTableTableManager(
        _db.attachedDatabase,
        _db.pendingViewEvents,
      );
}
