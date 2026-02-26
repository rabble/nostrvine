// ABOUTME: Service for managing offline social actions with automatic sync on reconnect
// ABOUTME: Queues likes, reposts, and follows when offline and syncs when online

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/utils/async_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:rxdart/rxdart.dart';

// Re-export types from db_client for convenience
export 'package:db_client/db_client.dart'
    show PendingAction, PendingActionStatus, PendingActionType;

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
/// - Persistent storage via Drift database
class PendingActionService extends ChangeNotifier {
  PendingActionService({
    required ConnectionStatusService connectionStatusService,
    required PendingActionsDao pendingActionsDao,
    required String userPubkey,
    PendingActionRetryConfig? retryConfig,
  }) : _connectionStatusService = connectionStatusService,
       _dao = pendingActionsDao,
       _userPubkey = userPubkey,
       _retryConfig = retryConfig ?? const PendingActionRetryConfig();

  final ConnectionStatusService _connectionStatusService;
  final PendingActionsDao _dao;
  final String _userPubkey;
  final PendingActionRetryConfig _retryConfig;

  bool _isInitialized = false;
  bool _isSyncing = false;
  StreamSubscription<List<PendingAction>>? _dbSubscription;

  /// Executors for different action types
  final Map<PendingActionType, ActionExecutor> _executors = {};

  /// Stream controller for pending actions
  final _pendingActionsController = BehaviorSubject<List<PendingAction>>.seeded(
    const [],
  );

  /// In-memory cache of pending actions
  List<PendingAction> _cachedPendingActions = [];
  List<PendingAction> _cachedAllActions = [];

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether a sync is currently in progress
  bool get isSyncing => _isSyncing;

  /// Stream of pending actions (reactive)
  Stream<List<PendingAction>> get pendingActionsStream =>
      _pendingActionsController.stream;

  /// Get current pending actions
  List<PendingAction> get pendingActions => _cachedPendingActions;

  /// Get all actions (including syncing/failed)
  List<PendingAction> get allActions => _cachedAllActions;

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
      // Resume any actions that were syncing when app closed
      await _dao.resetSyncingToPending(_userPubkey);

      // Load initial data
      _cachedPendingActions = await _dao.getPendingActions(_userPubkey);
      _cachedAllActions = await _dao.getAllActions(_userPubkey);
      _emitPendingActions();

      // Subscribe to database changes
      _dbSubscription = _dao.watchPendingActions(_userPubkey).listen((actions) {
        _cachedPendingActions = actions;
        _emitPendingActions();
        notifyListeners();
      });

      // Listen for connectivity changes
      _connectionStatusService.addListener(_onConnectivityChange);

      _isInitialized = true;

      Log.info(
        'PendingActionService initialized with ${pendingActions.length} '
        'pending actions',
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
    if (!_isInitialized) {
      throw StateError('PendingActionService not initialized');
    }

    // Find opposite action type
    final oppositeType = _getOppositeType(type);

    // Check for cancelling opposite action
    final existingAction = await _dao.findConflictingAction(
      _userPubkey,
      targetId,
      oppositeType,
    );

    if (existingAction != null) {
      // Actions cancel out - remove the existing one
      await _dao.deleteAction(existingAction.id);
      await _refreshCache();
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
      userPubkey: _userPubkey,
      authorPubkey: authorPubkey,
      addressableId: addressableId,
      targetKind: targetKind,
    );

    await _dao.upsertAction(action);
    await _refreshCache();

    Log.info(
      'Queued action: ${action.type} on $targetId',
      name: 'PendingActionService',
      category: LogCategory.system,
    );
  }

  /// Check if there's a pending action for a target
  bool hasPendingAction(String targetId, PendingActionType type) {
    return _cachedPendingActions.any(
      (a) => a.targetId == targetId && a.type == type,
    );
  }

  /// Get pending action for a target if exists
  PendingAction? getPendingAction(String targetId, PendingActionType type) {
    try {
      return _cachedPendingActions.firstWhere(
        (a) => a.targetId == targetId && a.type == type,
      );
    } catch (_) {
      return null;
    }
  }

  /// Cancel a pending action
  Future<void> cancelAction(String actionId) async {
    await _dao.deleteAction(actionId);
    await _refreshCache();
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

    final actions = await _dao.getPendingActions(_userPubkey);
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
    await _refreshCache();
    notifyListeners();

    final remaining = await _dao.getPendingActions(_userPubkey);
    Log.info(
      'Sync complete. Remaining pending: ${remaining.length}',
      name: 'PendingActionService',
      category: LogCategory.system,
    );
  }

  /// Clear completed actions older than specified duration
  Future<void> clearOldCompletedActions({
    Duration olderThan = const Duration(days: 7),
  }) async {
    final deleted = await _dao.deleteOldCompleted(_userPubkey, olderThan);
    if (deleted > 0) {
      await _refreshCache();
      Log.debug(
        'Cleared $deleted old completed actions',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    }
  }

  /// Clear all data (for logout)
  Future<void> clearAll() async {
    await _dao.clearAll(_userPubkey);
    _cachedPendingActions = [];
    _cachedAllActions = [];
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
    _dbSubscription?.cancel();
    _pendingActionsController.close();
    super.dispose();
  }

  // Private methods

  PendingActionType _getOppositeType(PendingActionType type) {
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

  Future<void> _refreshCache() async {
    _cachedPendingActions = await _dao.getPendingActions(_userPubkey);
    _cachedAllActions = await _dao.getAllActions(_userPubkey);
    _emitPendingActions();
  }

  void _emitPendingActions() {
    if (!_pendingActionsController.isClosed) {
      _pendingActionsController.add(_cachedPendingActions);
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
    await _dao.updateStatus(action.id, PendingActionStatus.syncing);

    try {
      await AsyncUtils.retryWithBackoff(
        operation: () => executor(action),
        maxRetries: _retryConfig.maxRetries,
        baseDelay: _retryConfig.initialDelay,
        maxDelay: _retryConfig.maxDelay,
        backoffMultiplier: _retryConfig.backoffMultiplier,
        debugName: 'Sync-${action.type}-${action.targetId}',
        retryWhen: _isRetriableError,
      );

      // Mark as completed
      await _dao.updateStatus(action.id, PendingActionStatus.completed);

      Log.info(
        'Successfully synced action: ${action.type} on ${action.targetId}',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    } catch (e) {
      // Mark as failed or pending for retry
      final newRetryCount = action.retryCount + 1;
      final newStatus = newRetryCount >= PendingAction.maxRetries
          ? PendingActionStatus.failed
          : PendingActionStatus.pending;

      await _dao.updateStatus(
        action.id,
        newStatus,
        lastError: e.toString(),
        retryCount: newRetryCount,
      );

      Log.error(
        'Failed to sync action: ${action.type} on ${action.targetId} - $e',
        name: 'PendingActionService',
        category: LogCategory.system,
      );
    }
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
