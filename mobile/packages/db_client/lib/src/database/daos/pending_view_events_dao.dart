// ABOUTME: Data Access Object for the durable video view-event outbox.
// ABOUTME: Stores finalized views until kind 22236 relay publish succeeds.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

part 'pending_view_events_dao.g.dart';

enum PendingViewEventStatus {
  pending,
  publishing,
  failed,
}

class UnknownPendingViewEventStatusException implements Exception {
  const UnknownPendingViewEventStatusException(this.rawValue);

  final String rawValue;

  @override
  String toString() {
    final known = PendingViewEventStatus.values.map((e) => e.name).join(', ');
    return 'UnknownPendingViewEventStatusException: '
        'unrecognised pending_view_events status "$rawValue"; '
        'expected one of $known';
  }
}

@immutable
class PendingViewEvent {
  const PendingViewEvent({
    required this.id,
    required this.videoId,
    required this.videoPubkey,
    required this.userPubkey,
    required this.watchDurationMs,
    required this.trafficSource,
    required this.status,
    required this.createdAt,
    this.videoVineId,
    this.totalDurationMs,
    this.loopCount,
    this.sourceDetail,
    this.retryCount = 0,
    this.lastError,
    this.lastAttemptAt,
  });

  final String id;
  final String videoId;
  final String videoPubkey;
  final String? videoVineId;
  final String userPubkey;
  final int watchDurationMs;
  final int? totalDurationMs;
  final int? loopCount;
  final String trafficSource;
  final String? sourceDetail;
  final PendingViewEventStatus status;
  final int retryCount;
  final String? lastError;
  final DateTime? lastAttemptAt;
  final DateTime createdAt;

  PendingViewEvent copyWith({
    String? id,
    String? videoId,
    String? videoPubkey,
    String? videoVineId,
    String? userPubkey,
    int? watchDurationMs,
    int? totalDurationMs,
    int? loopCount,
    String? trafficSource,
    String? sourceDetail,
    PendingViewEventStatus? status,
    int? retryCount,
    String? lastError,
    DateTime? lastAttemptAt,
    DateTime? createdAt,
  }) => PendingViewEvent(
    id: id ?? this.id,
    videoId: videoId ?? this.videoId,
    videoPubkey: videoPubkey ?? this.videoPubkey,
    videoVineId: videoVineId ?? this.videoVineId,
    userPubkey: userPubkey ?? this.userPubkey,
    watchDurationMs: watchDurationMs ?? this.watchDurationMs,
    totalDurationMs: totalDurationMs ?? this.totalDurationMs,
    loopCount: loopCount ?? this.loopCount,
    trafficSource: trafficSource ?? this.trafficSource,
    sourceDetail: sourceDetail ?? this.sourceDetail,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError ?? this.lastError,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingViewEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@DriftAccessor(tables: [PendingViewEvents])
class PendingViewEventsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingViewEventsDaoMixin {
  PendingViewEventsDao(super.attachedDatabase);

  PendingViewEventsCompanion _modelToCompanion(PendingViewEvent event) {
    return PendingViewEventsCompanion.insert(
      id: event.id,
      videoId: event.videoId,
      videoPubkey: event.videoPubkey,
      videoVineId: Value(event.videoVineId),
      userPubkey: event.userPubkey,
      watchDurationMs: event.watchDurationMs,
      totalDurationMs: Value(event.totalDurationMs),
      loopCount: Value(event.loopCount),
      trafficSource: event.trafficSource,
      sourceDetail: Value(event.sourceDetail),
      status: event.status.name,
      retryCount: Value(event.retryCount),
      lastError: Value(event.lastError),
      lastAttemptAt: Value(event.lastAttemptAt),
      createdAt: event.createdAt,
    );
  }

  PendingViewEvent _rowToModel(PendingViewEventRow row) {
    return PendingViewEvent(
      id: row.id,
      videoId: row.videoId,
      videoPubkey: row.videoPubkey,
      videoVineId: row.videoVineId,
      userPubkey: row.userPubkey,
      watchDurationMs: row.watchDurationMs,
      totalDurationMs: row.totalDurationMs,
      loopCount: row.loopCount,
      trafficSource: row.trafficSource,
      sourceDetail: row.sourceDetail,
      status: _parseStatus(row.status),
      retryCount: row.retryCount,
      lastError: row.lastError,
      lastAttemptAt: row.lastAttemptAt,
      createdAt: row.createdAt,
    );
  }

  PendingViewEventStatus _parseStatus(String raw) {
    for (final status in PendingViewEventStatus.values) {
      if (status.name == raw) return status;
    }
    throw UnknownPendingViewEventStatusException(raw);
  }

  Future<void> enqueue(PendingViewEvent event) async {
    await into(pendingViewEvents).insert(
      _modelToCompanion(event),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<bool> markPublishing(String id) async {
    final rows =
        await (update(pendingViewEvents)..where((t) => t.id.equals(id))).write(
          PendingViewEventsCompanion(
            status: Value(PendingViewEventStatus.publishing.name),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );
    return rows > 0;
  }

  Future<bool> markFailed(String id, String error) async {
    return transaction(() async {
      final row = await (select(
        pendingViewEvents,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return false;

      final rows =
          await (update(
            pendingViewEvents,
          )..where((t) => t.id.equals(id))).write(
            PendingViewEventsCompanion(
              status: Value(PendingViewEventStatus.failed.name),
              retryCount: Value(row.retryCount + 1),
              lastError: Value(error),
              lastAttemptAt: Value(DateTime.now()),
            ),
          );
      return rows > 0;
    });
  }

  Future<int> resetPublishingToPending(String userPubkey) {
    return (update(pendingViewEvents)..where(
          (t) =>
              t.userPubkey.equals(userPubkey) &
              t.status.equals(PendingViewEventStatus.publishing.name),
        ))
        .write(
          PendingViewEventsCompanion(
            status: Value(PendingViewEventStatus.pending.name),
          ),
        );
  }

  Future<int> deleteById(String id) {
    return (delete(pendingViewEvents)..where((t) => t.id.equals(id))).go();
  }

  Future<PendingViewEvent?> getById(String id) async {
    final row = await (select(
      pendingViewEvents,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _rowToModel(row);
  }

  Future<List<PendingViewEvent>> getRetryableForUser({
    required String userPubkey,
    required int maxRetries,
  }) async {
    final query = select(pendingViewEvents)
      ..where(
        (t) =>
            t.userPubkey.equals(userPubkey) &
            (t.status.equals(PendingViewEventStatus.pending.name) |
                t.status.equals(PendingViewEventStatus.failed.name)),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }
}
