// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_stats_dao.dart';

// ignore_for_file: type=lint
mixin _$ProfileStatsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProfileStatsTable get profileStats => attachedDatabase.profileStats;
  ProfileStatsDaoManager get managers => ProfileStatsDaoManager(this);
}

class ProfileStatsDaoManager {
  final _$ProfileStatsDaoMixin _db;
  ProfileStatsDaoManager(this._db);
  $$ProfileStatsTableTableManager get profileStats =>
      $$ProfileStatsTableTableManager(_db.attachedDatabase, _db.profileStats);
}
