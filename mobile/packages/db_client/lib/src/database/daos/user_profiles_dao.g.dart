// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profiles_dao.dart';

// ignore_for_file: type=lint
mixin _$UserProfilesDaoMixin on DatabaseAccessor<AppDatabase> {
  $UserProfilesTable get userProfiles => attachedDatabase.userProfiles;
  UserProfilesDaoManager get managers => UserProfilesDaoManager(this);
}

class UserProfilesDaoManager {
  final _$UserProfilesDaoMixin _db;
  UserProfilesDaoManager(this._db);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db.attachedDatabase, _db.userProfiles);
}
