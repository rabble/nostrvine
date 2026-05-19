// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_metrics_dao.dart';

// ignore_for_file: type=lint
mixin _$VideoMetricsDaoMixin on DatabaseAccessor<AppDatabase> {
  $NostrEventsTable get nostrEvents => attachedDatabase.nostrEvents;
  $VideoMetricsTable get videoMetrics => attachedDatabase.videoMetrics;
  VideoMetricsDaoManager get managers => VideoMetricsDaoManager(this);
}

class VideoMetricsDaoManager {
  final _$VideoMetricsDaoMixin _db;
  VideoMetricsDaoManager(this._db);
  $$NostrEventsTableTableManager get nostrEvents =>
      $$NostrEventsTableTableManager(_db.attachedDatabase, _db.nostrEvents);
  $$VideoMetricsTableTableManager get videoMetrics =>
      $$VideoMetricsTableTableManager(_db.attachedDatabase, _db.videoMetrics);
}
