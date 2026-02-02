// ABOUTME: Data Access Object for pending offline actions persistence.
// ABOUTME: Provides CRUD for offline action queue management.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

part 'pending_actions_dao.g.dart';

/// Type of social action queued for offline sync
enum PendingActionType {
  like,
  unlike,
  repost,
  unrepost,
  follow,
  unfollow,
}

/// Status of a pending action in the sync queue
enum PendingActionStatus {
  pending, // Waiting to sync
  syncing, // Currently being synced
  completed, // Successfully synced
  failed, // Sync failed after retries
}

/// Domain model for a pending action
@immutable
class PendingAction {
  const PendingAction({
    required this.id,
    required this.type,
    required this.targetId,
    required this.status,
    required this.userPubkey,
    required this.createdAt,
    this.authorPubkey,
    this.addressableId,
    this.targetKind,
    this.retryCount = 0,
    this.lastError,
    this.lastAttemptAt,
  });

  /// Create a new pending action
  factory PendingAction.create({
    required PendingActionType type,
    required String targetId,
    required String userPubkey,
    String? authorPubkey,
    String? addressableId,
    int? targetKind,
  }) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return PendingAction(
      id: '${timestamp}_${targetId.hashCode.abs()}',
      type: type,
      targetId: targetId,
      status: PendingActionStatus.pending,
      userPubkey: userPubkey,
      createdAt: DateTime.now(),
      authorPubkey: authorPubkey,
      addressableId: addressableId,
      targetKind: targetKind,
    );
  }

  final String id;
  final PendingActionType type;
  final String targetId;
  final String? authorPubkey;
  final String? addressableId;
  final int? targetKind;
  final PendingActionStatus status;
  final String userPubkey;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  final DateTime? lastAttemptAt;

  /// Maximum number of retry attempts before marking as failed
  static const int maxRetries = 5;

  /// Check if this action can be retried
  bool get canRetry =>
      status == PendingActionStatus.failed && retryCount < maxRetries;

  /// Check if this is a "positive" action (like, repost, follow)
  bool get isPositiveAction =>
      type == PendingActionType.like ||
      type == PendingActionType.repost ||
      type == PendingActionType.follow;

  /// Get the opposite action type (like -> unlike, etc.)
  PendingActionType get oppositeType {
    switch (type) {
      case PendingActionType.like:
        return PendingActionType.unlike;
      case PendingActionType.unlike:
        return PendingActionType.like;
      case PendingActionType.repost:
        return PendingActionType.unrepost;
      case PendingActionType.unrepost:
        return PendingActionType.repost;
      case PendingActionType.follow:
        return PendingActionType.unfollow;
      case PendingActionType.unfollow:
        return PendingActionType.follow;
    }
  }

  /// Check if this action cancels another action on the same target
  bool cancels(PendingAction other) {
    if (targetId != other.targetId) return false;
    return type == other.oppositeType;
  }

  /// Copy with updated fields
  PendingAction copyWith({
    String? id,
    PendingActionType? type,
    String? targetId,
    String? authorPubkey,
    String? addressableId,
    int? targetKind,
    PendingActionStatus? status,
    String? userPubkey,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
    DateTime? lastAttemptAt,
  }) => PendingAction(
    id: id ?? this.id,
    type: type ?? this.type,
    targetId: targetId ?? this.targetId,
    authorPubkey: authorPubkey ?? this.authorPubkey,
    addressableId: addressableId ?? this.addressableId,
    targetKind: targetKind ?? this.targetKind,
    status: status ?? this.status,
    userPubkey: userPubkey ?? this.userPubkey,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError ?? this.lastError,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
  );

  @override
  String toString() =>
      'PendingAction{id: $id, type: $type, target: $targetId, status: $status}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingAction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@DriftAccessor(tables: [PendingActions])
class PendingActionsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingActionsDaoMixin {
  PendingActionsDao(super.attachedDatabase);

  /// Convert domain model to database companion
  PendingActionsCompanion _modelToCompanion(PendingAction action) {
    return PendingActionsCompanion.insert(
      id: action.id,
      type: action.type.name,
      targetId: action.targetId,
      authorPubkey: Value(action.authorPubkey),
      addressableId: Value(action.addressableId),
      targetKind: Value(action.targetKind),
      status: action.status.name,
      userPubkey: action.userPubkey,
      createdAt: action.createdAt,
      retryCount: Value(action.retryCount),
      lastError: Value(action.lastError),
      lastAttemptAt: Value(action.lastAttemptAt),
    );
  }

  /// Convert database row to domain model
  PendingAction _rowToModel(PendingActionRow row) {
    return PendingAction(
      id: row.id,
      type: PendingActionType.values.firstWhere(
        (e) => e.name == row.type,
        orElse: () => PendingActionType.like,
      ),
      targetId: row.targetId,
      authorPubkey: row.authorPubkey,
      addressableId: row.addressableId,
      targetKind: row.targetKind,
      status: PendingActionStatus.values.firstWhere(
        (e) => e.name == row.status,
        orElse: () => PendingActionStatus.pending,
      ),
      userPubkey: row.userPubkey,
      createdAt: row.createdAt,
      retryCount: row.retryCount,
      lastError: row.lastError,
      lastAttemptAt: row.lastAttemptAt,
    );
  }

  /// Upsert a pending action
  Future<void> upsertAction(PendingAction action) {
    return into(pendingActions).insertOnConflictUpdate(
      _modelToCompanion(action),
    );
  }

  /// Get action by ID
  Future<PendingAction?> getAction(String id) async {
    final query = select(pendingActions)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _rowToModel(row) : null;
  }

  /// Get all pending actions for a user (status = pending)
  Future<List<PendingAction>> getPendingActions(String userPubkey) async {
    final query = select(pendingActions)
      ..where(
        (t) =>
            t.userPubkey.equals(userPubkey) &
            t.status.equals(PendingActionStatus.pending.name),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Get all actions for a user (any status)
  Future<List<PendingAction>> getAllActions(String userPubkey) async {
    final query = select(pendingActions)
      ..where((t) => t.userPubkey.equals(userPubkey))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Get actions by status
  Future<List<PendingAction>> getActionsByStatus(
    String userPubkey,
    PendingActionStatus status,
  ) async {
    final query = select(pendingActions)
      ..where(
        (t) => t.userPubkey.equals(userPubkey) & t.status.equals(status.name),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Find a conflicting action (opposite type on same target)
  Future<PendingAction?> findConflictingAction(
    String userPubkey,
    String targetId,
    PendingActionType oppositeType,
  ) async {
    final query = select(pendingActions)
      ..where(
        (t) =>
            t.userPubkey.equals(userPubkey) &
            t.targetId.equals(targetId) &
            t.type.equals(oppositeType.name) &
            t.status.equals(PendingActionStatus.pending.name),
      );
    final row = await query.getSingleOrNull();
    return row != null ? _rowToModel(row) : null;
  }

  /// Check if there's a pending action for a target
  Future<bool> hasPendingAction(
    String userPubkey,
    String targetId,
    PendingActionType type,
  ) async {
    final query = select(pendingActions)
      ..where(
        (t) =>
            t.userPubkey.equals(userPubkey) &
            t.targetId.equals(targetId) &
            t.type.equals(type.name) &
            t.status.equals(PendingActionStatus.pending.name),
      );
    final row = await query.getSingleOrNull();
    return row != null;
  }

  /// Update action status
  Future<bool> updateStatus(
    String id,
    PendingActionStatus status, {
    String? lastError,
    int? retryCount,
  }) async {
    final rowsAffected =
        await (update(pendingActions)..where((t) => t.id.equals(id))).write(
          PendingActionsCompanion(
            status: Value(status.name),
            lastError: lastError != null
                ? Value(lastError)
                : const Value.absent(),
            retryCount: retryCount != null
                ? Value(retryCount)
                : const Value.absent(),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );
    return rowsAffected > 0;
  }

  /// Delete action by ID
  Future<int> deleteAction(String id) {
    return (delete(pendingActions)..where((t) => t.id.equals(id))).go();
  }

  /// Delete completed actions (status = completed)
  Future<int> deleteCompleted(String userPubkey) {
    return (delete(pendingActions)..where(
          (t) =>
              t.userPubkey.equals(userPubkey) &
              t.status.equals(PendingActionStatus.completed.name),
        ))
        .go();
  }

  /// Delete old completed actions (older than specified duration)
  Future<int> deleteOldCompleted(String userPubkey, Duration olderThan) {
    final cutoff = DateTime.now().subtract(olderThan);
    return (delete(pendingActions)..where(
          (t) =>
              t.userPubkey.equals(userPubkey) &
              t.status.equals(PendingActionStatus.completed.name) &
              t.createdAt.isSmallerThanValue(cutoff),
        ))
        .go();
  }

  /// Watch pending actions (reactive stream)
  Stream<List<PendingAction>> watchPendingActions(String userPubkey) {
    final query = select(pendingActions)
      ..where(
        (t) =>
            t.userPubkey.equals(userPubkey) &
            t.status.equals(PendingActionStatus.pending.name),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Watch all actions (reactive stream)
  Stream<List<PendingAction>> watchAllActions(String userPubkey) {
    final query = select(pendingActions)
      ..where((t) => t.userPubkey.equals(userPubkey))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Clear all actions for a user
  Future<int> clearAll(String userPubkey) {
    return (delete(
      pendingActions,
    )..where((t) => t.userPubkey.equals(userPubkey))).go();
  }

  /// Reset syncing actions to pending (for app restart recovery)
  Future<int> resetSyncingToPending(String userPubkey) async {
    return (update(pendingActions)..where(
          (t) =>
              t.userPubkey.equals(userPubkey) &
              t.status.equals(PendingActionStatus.syncing.name),
        ))
        .write(
          PendingActionsCompanion(
            status: Value(PendingActionStatus.pending.name),
          ),
        );
  }
}
