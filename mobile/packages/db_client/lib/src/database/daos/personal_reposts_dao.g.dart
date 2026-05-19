// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_reposts_dao.dart';

// ignore_for_file: type=lint
mixin _$PersonalRepostsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PersonalRepostsTable get personalReposts => attachedDatabase.personalReposts;
  PersonalRepostsDaoManager get managers => PersonalRepostsDaoManager(this);
}

class PersonalRepostsDaoManager {
  final _$PersonalRepostsDaoMixin _db;
  PersonalRepostsDaoManager(this._db);
  $$PersonalRepostsTableTableManager get personalReposts =>
      $$PersonalRepostsTableTableManager(
        _db.attachedDatabase,
        _db.personalReposts,
      );
}
