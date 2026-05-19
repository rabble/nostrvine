// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_actions_dao.dart';

// ignore_for_file: type=lint
mixin _$PendingActionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingActionsTable get pendingActions => attachedDatabase.pendingActions;
  PendingActionsDaoManager get managers => PendingActionsDaoManager(this);
}

class PendingActionsDaoManager {
  final _$PendingActionsDaoMixin _db;
  PendingActionsDaoManager(this._db);
  $$PendingActionsTableTableManager get pendingActions =>
      $$PendingActionsTableTableManager(
        _db.attachedDatabase,
        _db.pendingActions,
      );
}
