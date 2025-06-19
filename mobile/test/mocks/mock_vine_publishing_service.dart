// ABOUTME: Mock implementation of vine publishing service for testing camera screen
// ABOUTME: Simulates offline queue behavior and publishing states for UI testing

import 'package:nostrvine_app/services/vine_publishing_service.dart';

class MockVinePublishingService implements VinePublishingService {
  bool _hasOfflineContent = false;
  int _offlineQueueCount = 0;

  @override
  bool get hasOfflineContent => _hasOfflineContent;

  @override
  int get offlineQueueCount => _offlineQueueCount;

  @override
  Future<void> clearOfflineQueue() async {
    _offlineQueueCount = 0;
    _hasOfflineContent = false;
  }

  @override
  Future<void> retryOfflineQueue() async {
    // Simulate retry process
    await Future.delayed(const Duration(milliseconds: 100));
    _offlineQueueCount = 0;
    _hasOfflineContent = false;
  }

  // Mock control methods
  void setOfflineContent(int count) {
    _offlineQueueCount = count;
    _hasOfflineContent = count > 0;
  }

  // Implement other required interface methods as no-ops for testing
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}