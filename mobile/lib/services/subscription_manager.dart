// ABOUTME: Centralized subscription manager to prevent relay overload and optimize Nostr usage
// ABOUTME: Manages all app subscriptions with proper cleanup, rate limiting, and relay balancing

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import '../services/nostr_service_interface.dart';

/// Centralized subscription manager to prevent relay overload
class SubscriptionManager extends ChangeNotifier {
  final INostrService _nostrService;
  final Map<String, ActiveSubscription> _activeSubscriptions = {};
  final Map<String, Timer> _retryTimers = {};
  
  // Rate limiting
  static const int _maxConcurrentSubscriptions = 5;
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
    
    debugPrint('📡 Creating managed subscription: $subscriptionId');
    debugPrint('   - Filters: ${optimizedFilters.length}');
    debugPrint('   - Priority: $priority');
    debugPrint('   - Active subscriptions: ${_activeSubscriptions.length}/$_maxConcurrentSubscriptions');
    
    try {
      final eventStream = _nostrService.subscribeToEvents(filters: optimizedFilters, bypassLimits: true);
      
      late StreamSubscription streamSubscription;
      streamSubscription = eventStream.listen(
        (event) {
          debugPrint('📨 SubscriptionManager received event for $name: ${event.id.substring(0, 8)}, kind: ${event.kind}, author: ${event.pubkey.substring(0, 8)}');
          
          // Rate limiting check
          if (!_checkRateLimit()) {
            debugPrint('⚠️ Rate limit exceeded, dropping event');
            return;
          }
          
          _recentEvents.add(DateTime.now());
          onEvent(event);
        },
        onError: (error) {
          debugPrint('❌ Subscription error in $subscriptionId: $error');
          onError?.call(error);
          _scheduleRetry(subscriptionId, name, filters, onEvent, onError, onComplete, priority);
        },
        onDone: () {
          debugPrint('✅ Subscription completed: $subscriptionId');
          onComplete?.call();
          _removeSubscription(subscriptionId);
        },
      );
      
      // Set up timeout
      final timeoutDuration = timeout ?? _subscriptionTimeout;
      final timeoutTimer = Timer(timeoutDuration, () {
        debugPrint('⏰ Subscription timeout: $subscriptionId');
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
      
      debugPrint('✅ Subscription created: $subscriptionId (${_activeSubscriptions.length} total)');
      return subscriptionId;
      
    } catch (e) {
      debugPrint('❌ Failed to create subscription $subscriptionId: $e');
      rethrow;
    }
  }
  
  /// Cancel a specific subscription
  Future<void> cancelSubscription(String subscriptionId) async {
    final subscription = _activeSubscriptions[subscriptionId];
    if (subscription != null) {
      debugPrint('🗑️ Cancelling subscription: $subscriptionId');
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
    
    debugPrint('🗑️ Cancelling ${toCancel.length} subscriptions matching: $namePattern');
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
      
      debugPrint('🔍 Optimizing filter: kinds=${filter.kinds}, authors=${filter.authors?.map((a) => a.substring(0, 8)).toList()}, limit=$optimizedLimit');
      
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
        // Remove any other parameters that might cause issues
      );
      
      optimized.add(optimizedFilter);
    }
    
    debugPrint('🔧 Optimized ${filters.length} filters (reduced limits, cleaned params)');
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
      debugPrint('🗑️ Cancelling lowest priority subscription: $targetId (priority: $lowestPriority)');
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
      debugPrint('🔄 Retrying subscription: $name');
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
        debugPrint('❌ Retry failed for $name: $e');
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
    debugPrint('🗑️ Disposing SubscriptionManager - cancelling all subscriptions');
    
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