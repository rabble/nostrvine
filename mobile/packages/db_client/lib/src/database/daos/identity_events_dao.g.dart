// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity_events_dao.dart';

// ignore_for_file: type=lint
mixin _$IdentityEventsDaoMixin on DatabaseAccessor<AppDatabase> {
  $IdentityEventsTable get identityEvents => attachedDatabase.identityEvents;
  IdentityEventsDaoManager get managers => IdentityEventsDaoManager(this);
}

class IdentityEventsDaoManager {
  final _$IdentityEventsDaoMixin _db;
  IdentityEventsDaoManager(this._db);
  $$IdentityEventsTableTableManager get identityEvents =>
      $$IdentityEventsTableTableManager(
        _db.attachedDatabase,
        _db.identityEvents,
      );
}
