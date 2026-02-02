// ABOUTME: Service for managing offline social actions with automatic sync on reconnect
// ABOUTME: Queues likes, reposts, and follows when offline and syncs when online

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/models/pending_action.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/utils/async_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:rxdart/rxdart.dart';

/// Callback type for executing a pending action
typedef ActionExecutor = Future<void> Function(PendingAction action);

/// Configuration for retry behavior
class PendingActionRetryConfig {
  const PendingActionRetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
  });

  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
}

/// Service for managing offline social actions with automatic sync on reconnect.
///
/// This service handles:
/// - Queuing actions when offline (likes, reposts, follows)
/// - Automatic sync when connectivity is restored
/// - Cancellation of opposite actions (e.g., like then unlike on same target)
/// - Exponential backoff retry for failed syncs
/// - Persistent storage via Hive
class PendingActionService extends ChangeNotifier {
  PendingActionService({
    required ConnectionStatusService connectionStatusService,
    PendingActionRetryConfig? retryConfig,
  }) : _connectionStatusService = connectionStatusService,
       _retryConfig = retryConfig ?? const PendingActionRetryConfig();

  static const String _boxName = 'pending_actions';

  final ConnectionStatusService _connectionStatusService;
  final PendingActionRetryConfig _retryConfig;

  Box<PendingAction>? _actionsBox;
  bool _isInitialized = false;
  bool _isSyncing = false;

  /// Executors for different action types
  final Map<PendingActionType, ActionExecutor> _executors = {};

  /// Stream controller for pending actions
  final _pendingActionsController = BehaviorSubject<List<PendingAction>>.seeded(
    const [],
  );

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether a sync is currently in progress
  bool get isSyncing => _isSyncing;

  /// Stream of pending actions (reactive)
  Stream<List<PendingAction>> get pendingActionsStream =>
      _pendingActionsController.stream;

  /// Get current pending actions
  List<PendingAction> get pendingActions {
    if (_actionsBox == null) return [];
    return _actionsBox!.values
        .where((a) => a.status == PendingActionStatus.pending)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Get all actions (including syncing/failed)
  List<PendingAction> get allActions {
    if (_actionsBox == null) return [];
    return _actionsBox!.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Register an executor for a specific action type
  void registerExecutor(PendingActionType type, ActionExecutor executor) {
    _executors[type] = executor;
    Log.debug(
      'Registered executor for action type: $type',
      name: 'PendingActionService',
      category: LogCategory.system,
    );
  }

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    Log.info(
      'Initializing PendingActionService',
      name: 'PendingActionService',
      category: LogCategory.system,
    );

    try {
      // Open Hive box for pending actions
      _actionsBox = await Hive.openBox<PendingAction>(_boxName);

      // Emit current state
      _emitPendingActions();

      // Resume any actions that were syncing when app closed
      await _resumeInterruptedSyncs();

      // Listen for connectivity changes
      _connectionStatusService.addListener(_onConnectivityChange);

      _isInitialized = true;

      Log.info(
        'PendingActionService initialized with ${pendingActions.length} pending actions',
        name: 'PendingActionService',
        category: LogCategory.system,
      );

      // If online, try to sync any pending actions
      if (_connectionStatusService.isOnline && pendingActions.isNotEmpty) {
        unawaited(syncPendingActions());
      }
    } catch (e) {
      Log.error(
        'Failed to initialize PendingActionService: $e',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Queue an action for later sync
  ///
  /// If a conflicting action exists (e.g., liking then unliking same target),
  /// both actions are cancelled out.
  Future<void> queueAction({
    required PendingActionType type,
    required String targetId,
    String? authorPubkey,
    String? addressableId,
    int? targetKind,
  }) async {
    if (_actionsBox == null) {
      throw StateError('PendingActionService not initialized');
    }

    // Check for cancelling opposite action
    final existingAction = _findConflictingAction(type, targetId);
    if (existingAction != null) {
      // Actions cancel out - remove the existing one
      await _removeAction(existingAction.id);
      Log.info(
        'Action cancelled out: ${existingAction.type} on $targetId',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      return;
    }

    // Create and save new action
    final action = PendingAction.create(
      type: type,
      targetId: targetId,
      authorPubkey: authorPubkey,
      addressableId: addressableId,
      targetKind: targetKind,
    );

    await _actionsBox!.put(action.id, action);
    _emitPendingActions();
    notifyListeners();

    Log.info(
      'Queued action: ${action.type} on $targetId',
      name: 'PendingActionService',
      category: LogCategory.system,
    );
  }

  /// Check if there's a pending action for a target
  bool hasPendingAction(String targetId, PendingActionType type) {
    if (_actionsBox == null) return false;
    return _actionsBox!.values.any(
      (a) =>
          a.targetId == targetId &&
          a.type == type &&
          a.status == PendingActionStatus.pending,
    );
  }

  /// Get pending action for a target if exists
  PendingAction? getPendingAction(String targetId, PendingActionType type) {
    if (_actionsBox == null) return null;
    try {
      return _actionsBox!.values.firstWhere(
        (a) =>
            a.targetId == targetId &&
            a.type == type &&
            a.status == PendingActionStatus.pending,
      );
    } catch (_) {
      return null;
    }
  }

  /// Cancel a pending action
  Future<void> cancelAction(String actionId) async {
    await _removeAction(actionId);
    Log.info(
      'Cancelled action: $actionId',
      name: 'PendingActionService',
      category: LogCategory.system,
    );
  }

  /// Sync all pending actions
  Future<void> syncPendingActions() async {
    if (_isSyncing) {
      Log.debug(
        'Sync already in progress, skipping',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      return;
    }

    if (!_connectionStatusService.isOnline) {
      Log.debug(
        'Offline, skipping sync',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      return;
    }

    final actions = pendingActions;
    if (actions.isEmpty) {
      Log.debug(
        'No pending actions to sync',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      return;
    }

    _isSyncing = true;
    notifyListeners();

    Log.info(
      'Starting sync of ${actions.length} pending actions',
      name: 'PendingActionService',
      category: LogCategory.system,
    );

    for (final action in actions) {
      if (!_connectionStatusService.isOnline) {
        Log.warning(
          'Lost connectivity during sync, pausing',
          name: 'PendingActionService',
          category: LogCategory.system,
        );
        break;
      }

      await _syncAction(action);
    }

    _isSyncing = false;
    notifyListeners();

    Log.info(
      'Sync complete. Remaining pending: ${pendingActions.length}',
      name: 'PendingActionService',
      category: LogCategory.system,
    );
  }

  /// Clear completed actions older than specified duration
  Future<void> clearOldCompletedActions({
    Duration olderThan = const Duration(days: 7),
  }) async {
    if (_actionsBox == null) return;

    final cutoff = DateTime.now().subtract(olderThan);
    final toRemove = _actionsBox!.values
        .where(
          (a) =>
              a.status == PendingActionStatus.completed &&
              a.createdAt.isBefore(cutoff),
        )
        .map((a) => a.id)
        .toList();

    for (final id in toRemove) {
      await _actionsBox!.delete(id);
    }

    if (toRemove.isNotEmpty) {
      _emitPendingActions();
      Log.debug(
        'Cleared ${toRemove.length} old completed actions',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    }
  }

  /// Clear all data (for logout)
  Future<void> clearAll() async {
    await _actionsBox?.clear();
    _emitPendingActions();
    notifyListeners();
    Log.info(
      'Cleared all pending actions',
      name: 'PendingActionService',
      category: LogCategory.system,
    );
  }

  /// Dispose resources
  @override
  void dispose() {
    _connectionStatusService.removeListener(_onConnectivityChange);
    _pendingActionsController.close();
    super.dispose();
  }

  // Private methods

  void _emitPendingActions() {
    if (!_pendingActionsController.isClosed) {
      _pendingActionsController.add(pendingActions);
    }
  }

  void _onConnectivityChange() {
    if (_connectionStatusService.isOnline && pendingActions.isNotEmpty) {
      Log.info(
        'Connectivity restored, triggering sync',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      unawaited(syncPendingActions());
    }
  }

  PendingAction? _findConflictingAction(
    PendingActionType type,
    String targetId,
  ) {
    if (_actionsBox == null) return null;

    // Find opposite action type
    PendingActionType oppositeType;
    switch (type) {
      case PendingActionType.like:
        oppositeType = PendingActionType.unlike;
      case PendingActionType.unlike:
        oppositeType = PendingActionType.like;
      case PendingActionType.repost:
        oppositeType = PendingActionType.unrepost;
      case PendingActionType.unrepost:
        oppositeType = PendingActionType.repost;
      case PendingActionType.follow:
        oppositeType = PendingActionType.unfollow;
      case PendingActionType.unfollow:
        oppositeType = PendingActionType.follow;
    }

    try {
      return _actionsBox!.values.firstWhere(
        (a) =>
            a.targetId == targetId &&
            a.type == oppositeType &&
            a.status == PendingActionStatus.pending,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeAction(String actionId) async {
    await _actionsBox?.delete(actionId);
    _emitPendingActions();
    notifyListeners();
  }

  Future<void> _resumeInterruptedSyncs() async {
    if (_actionsBox == null) return;

    // Find actions that were syncing when app closed
    final interrupted = _actionsBox!.values
        .where((a) => a.status == PendingActionStatus.syncing)
        .toList();

    for (final action in interrupted) {
      // Reset to pending so they get retried
      final updated = action.copyWith(status: PendingActionStatus.pending);
      await _actionsBox!.put(action.id, updated);
    }

    if (interrupted.isNotEmpty) {
      _emitPendingActions();
      Log.info(
        'Reset ${interrupted.length} interrupted syncs to pending',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _syncAction(PendingAction action) async {
    final executor = _executors[action.type];
    if (executor == null) {
      Log.error(
        'No executor registered for action type: ${action.type}',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
      return;
    }

    // Mark as syncing
    var updatedAction = action.copyWith(
      status: PendingActionStatus.syncing,
      lastAttemptAt: DateTime.now(),
    );
    await _actionsBox!.put(action.id, updatedAction);
    _emitPendingActions();

    try {
      await AsyncUtils.retryWithBackoff(
        operation: () => executor(action),
        maxRetries: _retryConfig.maxRetries,
        baseDelay: _retryConfig.initialDelay,
        maxDelay: _retryConfig.maxDelay,
        backoffMultiplier: _retryConfig.backoffMultiplier,
        debugName: 'Sync-${action.type}-${action.targetId}',
        retryWhen: (error) => _isRetriableError(error),
      );

      // Mark as completed
      updatedAction = action.copyWith(
        status: PendingActionStatus.completed,
        lastAttemptAt: DateTime.now(),
      );
      await _actionsBox!.put(action.id, updatedAction);

      Log.info(
        'Successfully synced action: ${action.type} on ${action.targetId}',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    } catch (e) {
      // Mark as failed
      final newRetryCount = action.retryCount + 1;
      updatedAction = action.copyWith(
        status: newRetryCount >= PendingAction.maxRetries
            ? PendingActionStatus.failed
            : PendingActionStatus.pending,
        retryCount: newRetryCount,
        lastError: e.toString(),
        lastAttemptAt: DateTime.now(),
      );
      await _actionsBox!.put(action.id, updatedAction);

      Log.error(
        'Failed to sync action: ${action.type} on ${action.targetId} - $e',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    }

    _emitPendingActions();
    notifyListeners();
  }

  bool _isRetriableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Network errors are retriable
    if (errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('socket')) {
      return true;
    }

    // Server errors are retriable
    if (errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('504')) {
      return true;
    }

    // Auth errors are not retriable
    if (errorStr.contains('401') ||
        errorStr.contains('403') ||
        errorStr.contains('unauthorized')) {
      return false;
    }

    // Default to retriable
    return true;
  }
}
