// ABOUTME: Centralized subscription manager to prevent relay overload and optimize Nostr usage
// ABOUTME: Manages all app subscriptions with proper cleanup, rate limiting, and relay balancing

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import '../services/nostr_service_interface.dart';
import '../utils/unified_logger.dart';

/// Centralized subscription manager to prevent relay overload
class SubscriptionManager extends ChangeNotifier {
  final INostrService _nostrService;
  final Map<String, ActiveSubscription> _activeSubscriptions = {};
  final Map<String, Timer> _retryTimers = {};
  
  // Rate limiting  
  static const int _maxConcurrentSubscriptions = 30; // Further increased for proper comment management
  static const int _maxEventsPerMinute = 2000; // Increased to handle profile loads
  static const Duration _subscriptionTimeout = Duration(minutes: 5);
  static const Duration _retryDelay = Duration(seconds: 30);
  
  // Event tracking for rate limiting
  final List<DateTime> _recentEvents = [];
  
  SubscriptionManager(this._nostrService);
  
  /// Create a managed subscription with automatic cleanup and rate limiting
  Future<String> createSubscription({
    required String name,
    required List<Filter> filters,
    required Function(Event) onEvent,
    Function(dynamic)? onError,
    VoidCallback? onComplete,
    Duration? timeout,
    int priority = 5, // 1 = highest, 10 = lowest
  }) async {
    // Check if we have too many active subscriptions
    if (_activeSubscriptions.length >= _maxConcurrentSubscriptions) {
      // Cancel lowest priority subscription
      await _cancelLowestPrioritySubscription();
    }
    
    // Optimize filters to reduce relay load
    final optimizedFilters = _optimizeFilters(filters);
    
    final subscriptionId = '${name}_${DateTime.now().millisecondsSinceEpoch}';
    
    Log.debug('Creating managed subscription: $subscriptionId', name: 'SubscriptionManager', category: LogCategory.system);
    Log.debug('   - Filters: ${optimizedFilters.length}', name: 'SubscriptionManager', category: LogCategory.system);
    Log.debug('   - Priority: $priority', name: 'SubscriptionManager', category: LogCategory.system);
    Log.debug('   - Active subscriptions: ${_activeSubscriptions.length}/$_maxConcurrentSubscriptions', name: 'SubscriptionManager', category: LogCategory.system);
    
    try {
      final eventStream = _nostrService.subscribeToEvents(filters: optimizedFilters, bypassLimits: true);
      
      late StreamSubscription streamSubscription;
      streamSubscription = eventStream.listen(
        (event) {
          Log.debug('� SubscriptionManager received event for $name: ${event.id.substring(0, 8)}, kind: ${event.kind}, author: ${event.pubkey.substring(0, 8)}', name: 'SubscriptionManager', category: LogCategory.system);
          
          // Rate limiting check
          if (!_checkRateLimit()) {
            Log.warning('Rate limit exceeded, dropping event', name: 'SubscriptionManager', category: LogCategory.system);
            return;
          }
          
          _recentEvents.add(DateTime.now());
          onEvent(event);
        },
        onError: (error) {
          Log.error('Subscription error in $subscriptionId: $error', name: 'SubscriptionManager', category: LogCategory.system);
          onError?.call(error);
          _scheduleRetry(subscriptionId, name, filters, onEvent, onError, onComplete, priority);
        },
        onDone: () {
          Log.info('Subscription completed: $subscriptionId', name: 'SubscriptionManager', category: LogCategory.system);
          onComplete?.call();
          _removeSubscription(subscriptionId);
        },
      );
      
      // Set up timeout
      final timeoutDuration = timeout ?? _subscriptionTimeout;
      final timeoutTimer = Timer(timeoutDuration, () {
        Log.debug('⏰ Subscription timeout: $subscriptionId', name: 'SubscriptionManager', category: LogCategory.system);
        streamSubscription.cancel();
        _removeSubscription(subscriptionId);
      });
      
      // Store subscription info
      _activeSubscriptions[subscriptionId] = ActiveSubscription(
        id: subscriptionId,
        name: name,
        subscription: streamSubscription,
        timeoutTimer: timeoutTimer,
        priority: priority,
        createdAt: DateTime.now(),
        filters: optimizedFilters,
      );
      
      Log.info('Subscription created: $subscriptionId (${_activeSubscriptions.length} total)', name: 'SubscriptionManager', category: LogCategory.system);
      return subscriptionId;
      
    } catch (e) {
      Log.error('Failed to create subscription $subscriptionId: $e', name: 'SubscriptionManager', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Cancel a specific subscription
  Future<void> cancelSubscription(String subscriptionId) async {
    final subscription = _activeSubscriptions[subscriptionId];
    if (subscription != null) {
      Log.debug('�️ Cancelling subscription: $subscriptionId', name: 'SubscriptionManager', category: LogCategory.system);
      await subscription.subscription.cancel();
      subscription.timeoutTimer.cancel();
      _removeSubscription(subscriptionId);
    }
  }
  
  /// Cancel all subscriptions with a specific name pattern
  Future<void> cancelSubscriptionsByName(String namePattern) async {
    final toCancel = _activeSubscriptions.entries
        .where((entry) => entry.value.name.contains(namePattern))
        .map((entry) => entry.key)
        .toList();
    
    Log.debug('�️ Cancelling ${toCancel.length} subscriptions matching: $namePattern', name: 'SubscriptionManager', category: LogCategory.system);
    for (final id in toCancel) {
      await cancelSubscription(id);
    }
  }
  
  /// Get subscription statistics
  Map<String, dynamic> getStats() {
    _cleanupOldEvents();
    
    return {
      'activeSubscriptions': _activeSubscriptions.length,
      'maxSubscriptions': _maxConcurrentSubscriptions,
      'eventsLastMinute': _recentEvents.length,
      'maxEventsPerMinute': _maxEventsPerMinute,
      'subscriptionDetails': _activeSubscriptions.map((id, sub) => MapEntry(id, {
        'name': sub.name,
        'priority': sub.priority,
        'age': DateTime.now().difference(sub.createdAt).inSeconds,
        'filterCount': sub.filters.length,
      })),
    };
  }
  
  /// Optimize filters to reduce relay load
  List<Filter> _optimizeFilters(List<Filter> filters) {
    final optimized = <Filter>[];
    
    for (final filter in filters) {
      // Reduce limits for large requests
      var optimizedLimit = filter.limit;
      if (optimizedLimit != null && optimizedLimit > 100) {
        optimizedLimit = 100; // Cap at 100 events per filter
      }
      
      Log.debug('Optimizing filter: kinds=${filter.kinds}, authors=${filter.authors?.map((a) => a.substring(0, 8)).toList()}, limit=$optimizedLimit', name: 'SubscriptionManager', category: LogCategory.system);
      
      // Create optimized filter
      final optimizedFilter = Filter(
        ids: filter.ids,
        authors: filter.authors,
        kinds: filter.kinds,
        e: filter.e,
        p: filter.p,
        since: filter.since,
        until: filter.until,
        limit: optimizedLimit,
        t: filter.t, // Preserve hashtag filters
        h: filter.h, // Preserve group filters (required for vine.hol.is)
      );
      
      optimized.add(optimizedFilter);
    }
    
    Log.debug('Optimized ${filters.length} filters (reduced limits, cleaned params)', name: 'SubscriptionManager', category: LogCategory.system);
    return optimized;
  }
  
  /// Check if we're within rate limits
  bool _checkRateLimit() {
    _cleanupOldEvents();
    return _recentEvents.length < _maxEventsPerMinute;
  }
  
  /// Remove old events from rate limiting tracker
  void _cleanupOldEvents() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    _recentEvents.removeWhere((event) => event.isBefore(cutoff));
  }
  
  /// Cancel the lowest priority subscription
  Future<void> _cancelLowestPrioritySubscription() async {
    if (_activeSubscriptions.isEmpty) return;
    
    // Find subscription with lowest priority (highest number)
    var lowestPriority = 0;
    String? targetId;
    
    for (final entry in _activeSubscriptions.entries) {
      if (entry.value.priority > lowestPriority) {
        lowestPriority = entry.value.priority;
        targetId = entry.key;
      }
    }
    
    if (targetId != null) {
      Log.debug('�️ Cancelling lowest priority subscription: $targetId (priority: $lowestPriority)', name: 'SubscriptionManager', category: LogCategory.system);
      await cancelSubscription(targetId);
    }
  }
  
  /// Schedule retry for failed subscription
  void _scheduleRetry(
    String originalId,
    String name,
    List<Filter> filters,
    Function(Event) onEvent,
    Function(dynamic)? onError,
    VoidCallback? onComplete,
    int priority,
  ) {
    final retryId = '${name}_retry_${DateTime.now().millisecondsSinceEpoch}';
    
    _retryTimers[retryId] = Timer(_retryDelay, () async {
      Log.warning('Retrying subscription: $name', name: 'SubscriptionManager', category: LogCategory.system);
      try {
        await createSubscription(
          name: name,
          filters: filters,
          onEvent: onEvent,
          onError: onError,
          onComplete: onComplete,
          priority: priority,
        );
      } catch (e) {
        Log.error('Retry failed for $name: $e', name: 'SubscriptionManager', category: LogCategory.system);
      }
      _retryTimers.remove(retryId);
    });
  }
  
  /// Remove subscription from tracking
  void _removeSubscription(String subscriptionId) {
    _activeSubscriptions.remove(subscriptionId);
    notifyListeners();
  }
  
  @override
  void dispose() {
    Log.debug('�️ Disposing SubscriptionManager - cancelling all subscriptions', name: 'SubscriptionManager', category: LogCategory.system);
    
    // Cancel all active subscriptions
    for (final subscription in _activeSubscriptions.values) {
      subscription.subscription.cancel();
      subscription.timeoutTimer.cancel();
    }
    _activeSubscriptions.clear();
    
    // Cancel all retry timers
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    
    super.dispose();
  }
}

/// Information about an active subscription
class ActiveSubscription {
  final String id;
  final String name;
  final StreamSubscription subscription;
  final Timer timeoutTimer;
  final int priority;
  final DateTime createdAt;
  final List<Filter> filters;
  
  ActiveSubscription({
    required this.id,
    required this.name,
    required this.subscription,
    required this.timeoutTimer,
    required this.priority,
    required this.createdAt,
    required this.filters,
  });
}