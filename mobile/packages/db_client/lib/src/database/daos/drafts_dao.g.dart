// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drafts_dao.dart';

// ignore_for_file: type=lint
mixin _$DraftsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DraftsTable get drafts => attachedDatabase.drafts;
  $ClipsTable get clips => attachedDatabase.clips;
  DraftsDaoManager get managers => DraftsDaoManager(this);
}

class DraftsDaoManager {
  final _$DraftsDaoMixin _db;
  DraftsDaoManager(this._db);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db.attachedDatabase, _db.drafts);
  $$ClipsTableTableManager get clips =>
      $$ClipsTableTableManager(_db.attachedDatabase, _db.clips);
}
