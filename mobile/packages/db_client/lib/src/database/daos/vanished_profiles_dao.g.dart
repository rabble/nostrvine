// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vanished_profiles_dao.dart';

// ignore_for_file: type=lint
mixin _$VanishedProfilesDaoMixin on DatabaseAccessor<AppDatabase> {
  $VanishedProfilesTable get vanishedProfiles =>
      attachedDatabase.vanishedProfiles;
  VanishedProfilesDaoManager get managers => VanishedProfilesDaoManager(this);
}

class VanishedProfilesDaoManager {
  final _$VanishedProfilesDaoMixin _db;
  VanishedProfilesDaoManager(this._db);
  $$VanishedProfilesTableTableManager get vanishedProfiles =>
      $$VanishedProfilesTableTableManager(
        _db.attachedDatabase,
        _db.vanishedProfiles,
      );
}
