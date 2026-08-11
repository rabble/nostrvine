// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_categories_dao.dart';

// ignore_for_file: type=lint
mixin _$ClipCategoriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ClipCategoriesTable get clipCategories => attachedDatabase.clipCategories;
  $DraftsTable get drafts => attachedDatabase.drafts;
  $ClipsTable get clips => attachedDatabase.clips;
  ClipCategoriesDaoManager get managers => ClipCategoriesDaoManager(this);
}

class ClipCategoriesDaoManager {
  final _$ClipCategoriesDaoMixin _db;
  ClipCategoriesDaoManager(this._db);
  $$ClipCategoriesTableTableManager get clipCategories =>
      $$ClipCategoriesTableTableManager(
        _db.attachedDatabase,
        _db.clipCategories,
      );
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db.attachedDatabase, _db.drafts);
  $$ClipsTableTableManager get clips =>
      $$ClipsTableTableManager(_db.attachedDatabase, _db.clips);
}
