// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nostr_events_dao.dart';

// ignore_for_file: type=lint
mixin _$NostrEventsDaoMixin on DatabaseAccessor<AppDatabase> {
  $NostrEventsTable get nostrEvents => attachedDatabase.nostrEvents;
  $VideoMetricsTable get videoMetrics => attachedDatabase.videoMetrics;
  NostrEventsDaoManager get managers => NostrEventsDaoManager(this);
}

class NostrEventsDaoManager {
  final _$NostrEventsDaoMixin _db;
  NostrEventsDaoManager(this._db);
  $$NostrEventsTableTableManager get nostrEvents =>
      $$NostrEventsTableTableManager(_db.attachedDatabase, _db.nostrEvents);
  $$VideoMetricsTableTableManager get videoMetrics =>
      $$VideoMetricsTableTableManager(_db.attachedDatabase, _db.videoMetrics);
}
