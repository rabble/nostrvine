// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seen_videos_dao.dart';

// ignore_for_file: type=lint
mixin _$SeenVideosDaoMixin on DatabaseAccessor<AppDatabase> {
  $SeenVideosTable get seenVideos => attachedDatabase.seenVideos;
  SeenVideosDaoManager get managers => SeenVideosDaoManager(this);
}

class SeenVideosDaoManager {
  final _$SeenVideosDaoMixin _db;
  SeenVideosDaoManager(this._db);
  $$SeenVideosTableTableManager get seenVideos =>
      $$SeenVideosTableTableManager(_db.attachedDatabase, _db.seenVideos);
}
