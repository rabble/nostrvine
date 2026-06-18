// ABOUTME: Data Access Object for notification persistence operations.
// ABOUTME: Provides CRUD with cache-age-based cleanup.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'notifications_dao.g.dart';

@DriftAccessor(tables: [Notifications])
class NotificationsDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationsDaoMixin {
  NotificationsDao(super.attachedDatabase);

  /// Upsert a notification
  Future<void> upsertNotification({
    required String id,
    required String type,
    required String fromPubkey,
    required int timestamp,
    String? targetEventId,
    String? targetPubkey,
    String? content,
    bool isRead = false,
  }) {
    return into(notifications).insertOnConflictUpdate(
      NotificationsCompanion.insert(
        id: id,
        type: type,
        fromPubkey: fromPubkey,
        timestamp: timestamp,
        targetEventId: Value(targetEventId),
        targetPubkey: Value(targetPubkey),
        content: Value(content),
        isRead: Value(isRead),
        cachedAt: DateTime.now(),
      ),
    );
  }

  /// Get all notifications sorted by timestamp (newest first)
  Future<List<NotificationRow>> getAllNotifications({int? limit}) {
    final query = select(notifications)
      ..orderBy([
        (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Get unread notifications count
  Future<int> getUnreadCount() async {
    final query = selectOnly(notifications)
      ..where(notifications.isRead.equals(false))
      ..addColumns([notifications.id.count()]);
    final result = await query.getSingle();
    return result.read(notifications.id.count()) ?? 0;
  }

  /// Mark notification as read
  Future<bool> markAsRead(String id) async {
    final rowsAffected =
        await (update(notifications)..where((t) => t.id.equals(id))).write(
          const NotificationsCompanion(isRead: Value(true)),
        );
    return rowsAffected > 0;
  }

  /// Mark all notifications as read
  Future<int> markAllAsRead() {
    return update(notifications).write(
      const NotificationsCompanion(isRead: Value(true)),
    );
  }

  /// Delete notification by ID
  Future<int> deleteNotification(String id) {
    return (delete(notifications)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes cache rows last written before [cutoff].
  ///
  /// Retention is keyed on `cachedAt` (when the row was written through),
  /// not the notification's own `timestamp` (its `createdAt`). The cache is
  /// a write-through snapshot of the latest first page (see [replaceAll]);
  /// pruning by content age would wipe still-current notifications that
  /// merely describe events older than the retention window, defeating
  /// cold-start hydration.
  Future<int> deleteCachedBefore(DateTime cutoff) {
    return (delete(
      notifications,
    )..where((t) => t.cachedAt.isSmallerThanValue(cutoff))).go();
  }

  /// Watch all notifications (reactive stream)
  Stream<List<NotificationRow>> watchAllNotifications({int? limit}) {
    final query = select(notifications)
      ..orderBy([
        (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch();
  }

  /// Watch unread count (reactive stream)
  Stream<int> watchUnreadCount() {
    final query = selectOnly(notifications)
      ..where(notifications.isRead.equals(false))
      ..addColumns([notifications.id.count()]);
    return query.watchSingle().map(
      (row) => row.read(notifications.id.count()) ?? 0,
    );
  }

  /// Clear all notifications
  Future<int> clearAll() {
    return delete(notifications).go();
  }

  /// Replaces every cached notification with [rows] in a single transaction.
  ///
  /// Used by `NotificationRepository` as a write-through cache after a
  /// successful first-page REST refresh, so subsequent cold launches can
  /// hydrate the inbox from local storage before the server responds.
  ///
  /// Accepts plain Dart records so callers don't need to depend on
  /// `package:drift` to build the row companions.
  Future<void> replaceAll(List<NotificationCacheRow> rows) async {
    final cachedAt = DateTime.now();
    final companions = rows
        .map(
          (r) => NotificationsCompanion.insert(
            id: r.id,
            type: r.type,
            fromPubkey: r.fromPubkey,
            timestamp: r.timestamp,
            targetEventId: Value(r.targetEventId),
            targetPubkey: Value(r.targetPubkey),
            content: Value(r.content),
            isRead: Value(r.isRead),
            cachedAt: cachedAt,
          ),
        )
        .toList();
    await transaction(() async {
      await delete(notifications).go();
      if (companions.isEmpty) return;
      await batch((b) => b.insertAll(notifications, companions));
    });
  }
}

/// Plain-Dart row payload accepted by [NotificationsDao.replaceAll].
///
/// Mirrors the persisted columns so callers can populate the cache
/// without depending on `package:drift` directly.
typedef NotificationCacheRow = ({
  String id,
  String type,
  String fromPubkey,
  int timestamp,
  String? targetEventId,
  String? targetPubkey,
  String? content,
  bool isRead,
});
