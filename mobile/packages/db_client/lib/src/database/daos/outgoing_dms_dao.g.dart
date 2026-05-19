// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outgoing_dms_dao.dart';

// ignore_for_file: type=lint
mixin _$OutgoingDmsDaoMixin on DatabaseAccessor<AppDatabase> {
  $OutgoingDmsTable get outgoingDms => attachedDatabase.outgoingDms;
  OutgoingDmsDaoManager get managers => OutgoingDmsDaoManager(this);
}

class OutgoingDmsDaoManager {
  final _$OutgoingDmsDaoMixin _db;
  OutgoingDmsDaoManager(this._db);
  $$OutgoingDmsTableTableManager get outgoingDms =>
      $$OutgoingDmsTableTableManager(_db.attachedDatabase, _db.outgoingDms);
}
