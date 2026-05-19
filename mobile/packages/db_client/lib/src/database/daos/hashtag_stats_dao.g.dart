// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hashtag_stats_dao.dart';

// ignore_for_file: type=lint
mixin _$HashtagStatsDaoMixin on DatabaseAccessor<AppDatabase> {
  $HashtagStatsTable get hashtagStats => attachedDatabase.hashtagStats;
  HashtagStatsDaoManager get managers => HashtagStatsDaoManager(this);
}

class HashtagStatsDaoManager {
  final _$HashtagStatsDaoMixin _db;
  HashtagStatsDaoManager(this._db);
  $$HashtagStatsTableTableManager get hashtagStats =>
      $$HashtagStatsTableTableManager(_db.attachedDatabase, _db.hashtagStats);
}
