// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clips_dao.dart';

// ignore_for_file: type=lint
mixin _$ClipsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DraftsTable get drafts => attachedDatabase.drafts;
  $ClipsTable get clips => attachedDatabase.clips;
  ClipsDaoManager get managers => ClipsDaoManager(this);
}

class ClipsDaoManager {
  final _$ClipsDaoMixin _db;
  ClipsDaoManager(this._db);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db.attachedDatabase, _db.drafts);
  $$ClipsTableTableManager get clips =>
      $$ClipsTableTableManager(_db.attachedDatabase, _db.clips);
}
