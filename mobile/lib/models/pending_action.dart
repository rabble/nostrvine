// ABOUTME: Model for tracking offline social actions (likes, reposts, follows)
// ABOUTME: Supports local persistence via Hive for sync-on-reconnect functionality

import 'dart:math' as math;
import 'package:hive_ce/hive.dart';

part 'pending_action.g.dart';

/// Type of social action queued for offline sync
@HiveType(typeId: 3)
enum PendingActionType {
  @HiveField(0)
  like,

  @HiveField(1)
  unlike,

  @HiveField(2)
  repost,

  @HiveField(3)
  unrepost,

  @HiveField(4)
  follow,

  @HiveField(5)
  unfollow,
}

/// Status of a pending action in the sync queue
@HiveType(typeId: 4)
enum PendingActionStatus {
  @HiveField(0)
  pending, // Waiting to sync

  @HiveField(1)
  syncing, // Currently being synced

  @HiveField(2)
  completed, // Successfully synced

  @HiveField(3)
  failed, // Sync failed after retries
}

/// Represents a social action queued for offline sync.
///
/// Used to persist user intent (like, repost, follow) when offline
/// and automatically sync when connectivity is restored.
@HiveType(typeId: 5)
class PendingAction {
  const PendingAction({
    required this.id,
    required this.type,
    required this.targetId,
    required this.createdAt,
    required this.status,
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
    String? authorPubkey,
    String? addressableId,
    int? targetKind,
  }) => PendingAction(
    id: '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(999999)}',
    type: type,
    targetId: targetId,
    authorPubkey: authorPubkey,
    addressableId: addressableId,
    targetKind: targetKind,
    createdAt: DateTime.now(),
    status: PendingActionStatus.pending,
  );

  /// Unique identifier for this action
  @HiveField(0)
  final String id;

  /// Type of action (like, unlike, repost, etc.)
  @HiveField(1)
  final PendingActionType type;

  /// Target event ID (for likes/reposts) or pubkey (for follows)
  @HiveField(2)
  final String targetId;

  /// Pubkey of the original event author (for likes/reposts)
  @HiveField(3)
  final String? authorPubkey;

  /// Addressable ID for reposts (format: "kind:pubkey:d-tag")
  @HiveField(4)
  final String? addressableId;

  /// Kind of the target event (e.g., 34236 for videos)
  @HiveField(5)
  final int? targetKind;

  /// When the action was created
  @HiveField(6)
  final DateTime createdAt;

  /// Current sync status
  @HiveField(7)
  final PendingActionStatus status;

  /// Number of sync attempts
  @HiveField(8)
  final int retryCount;

  /// Last error message if sync failed
  @HiveField(9)
  final String? lastError;

  /// Timestamp of last sync attempt
  @HiveField(10)
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

  /// Check if this is a "negative" action (unlike, unrepost, unfollow)
  bool get isNegativeAction =>
      type == PendingActionType.unlike ||
      type == PendingActionType.unrepost ||
      type == PendingActionType.unfollow;

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
    DateTime? createdAt,
    PendingActionStatus? status,
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
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError ?? this.lastError,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
  );

  /// Get display-friendly action description
  String get displayDescription {
    switch (type) {
      case PendingActionType.like:
        return 'Like';
      case PendingActionType.unlike:
        return 'Unlike';
      case PendingActionType.repost:
        return 'Repost';
      case PendingActionType.unrepost:
        return 'Unrepost';
      case PendingActionType.follow:
        return 'Follow';
      case PendingActionType.unfollow:
        return 'Unfollow';
    }
  }

  /// Get status text for display
  String get statusText {
    switch (status) {
      case PendingActionStatus.pending:
        return 'Waiting to sync...';
      case PendingActionStatus.syncing:
        return 'Syncing...';
      case PendingActionStatus.completed:
        return 'Synced';
      case PendingActionStatus.failed:
        return 'Failed: ${lastError ?? 'Unknown error'}';
    }
  }

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
