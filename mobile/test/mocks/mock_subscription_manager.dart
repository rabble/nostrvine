// ABOUTME: Mock implementation of SubscriptionManager for testing
// ABOUTME: Provides controlled subscription behavior without real Nostr connections

import 'dart:async';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';

class MockSubscriptionManager extends SubscriptionManager {
  final Map<String, StreamController<Event>> _subscriptions = {};
  final Map<String, Filter> _filters = {};
  int _subscriptionCounter = 0;
  
  MockSubscriptionManager(INostrService nostrService) : super(nostrService);
  
  @override
  Future<String> createSubscription({
    required String name,
    required List<Filter> filters,
    required Function(Event) onEvent,
    Function(dynamic)? onError,
    Function()? onComplete,
    Duration? timeout,
    int priority = 5,
  }) async {
    final id = 'mock_sub_${_subscriptionCounter++}';
    final controller = StreamController<Event>.broadcast();
    
    _subscriptions[id] = controller;
    _filters[id] = filters.first;
    
    // Set up listeners
    controller.stream.listen(
      onEvent,
      onError: onError,
      onDone: onComplete,
    );
    
    // Auto-complete after timeout if specified
    if (timeout != null) {
      Future.delayed(timeout, () {
        if (_subscriptions.containsKey(id)) {
          completeSubscription(id);
        }
      });
    }
    
    return id;
  }
  
  @override
  void cancelSubscription(String subscriptionId) {
    final controller = _subscriptions.remove(subscriptionId);
    controller?.close();
    _filters.remove(subscriptionId);
  }
  
  void completeSubscription(String subscriptionId) {
    final controller = _subscriptions[subscriptionId];
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
  }
  
  void emitEvent(String subscriptionId, Event event) {
    final controller = _subscriptions[subscriptionId];
    if (controller != null && !controller.isClosed) {
      controller.add(event);
    }
  }
  
  @override
  void dispose() {
    for (final controller in _subscriptions.values) {
      controller.close();
    }
    _subscriptions.clear();
    _filters.clear();
    super.dispose();
  }
}