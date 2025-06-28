// ABOUTME: Unit tests for VideoEventService subscription duplicate checking
// ABOUTME: Tests that different subscription parameters are properly allowed and not wrongly rejected as duplicates

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';

// Mock classes
class MockNostrService extends Mock implements INostrService {}
class MockEvent extends Mock implements Event {}

// Fake classes for setUpAll
class FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeFilter());
  });

  group('VideoEventService Subscription Duplicate Checking', () {
    late VideoEventService videoEventService;
    late MockNostrService mockNostrService;
    late StreamController<Event> eventStreamController;

    setUp(() {
      mockNostrService = MockNostrService();
      eventStreamController = StreamController<Event>.broadcast();
      
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((_) => eventStreamController.stream);
      
      videoEventService = VideoEventService(mockNostrService);
    });

    tearDown(() async {
      await eventStreamController.close();
    });

    test('should allow different subscriptions with different parameters', () async {
      // Track subscription calls
      final subscriptionCalls = <List<Filter>>[];
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((invocation) {
            final filters = invocation.namedArguments[const Symbol('filters')] as List<Filter>;
            subscriptionCalls.add(filters);
            return eventStreamController.stream;
          });

      // First subscription: Classic vines from specific author
      await videoEventService.subscribeToVideoFeed(
        authors: ['25315276cbaeb8f2ed998ed55d15ef8c9cf2027baea191d1253d9a5c69a2b856'],
        limit: 100,
        replace: true,
      );

      // Should have created one subscription
      expect(subscriptionCalls.length, equals(1));
      expect(videoEventService.isSubscribed, isTrue);

      // Second subscription: Open feed (all videos, no author filter)
      await videoEventService.subscribeToVideoFeed(
        limit: 300,
        replace: false,
      );

      // Should have created a second subscription with different parameters
      expect(subscriptionCalls.length, equals(2), 
        reason: 'Should allow subscription with different parameters (no authors vs specific authors)');
      
      // Verify the subscriptions have different filters
      final firstFilter = subscriptionCalls[0][0];
      final secondFilter = subscriptionCalls[1][0];
      
      expect(firstFilter.authors, isNotNull);
      expect(firstFilter.authors!.length, equals(1));
      expect(secondFilter.authors, isNull);
    });

    test('should reject truly duplicate subscriptions', () async {
      final subscriptionCalls = <List<Filter>>[];
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((invocation) {
            final filters = invocation.namedArguments[const Symbol('filters')] as List<Filter>;
            subscriptionCalls.add(filters);
            return eventStreamController.stream;
          });

      // First subscription
      await videoEventService.subscribeToVideoFeed(
        authors: ['testauthor123'],
        limit: 50,
      );

      expect(subscriptionCalls.length, equals(1));

      // Exact same subscription
      await videoEventService.subscribeToVideoFeed(
        authors: ['testauthor123'],
        limit: 50,
      );

      // Should still have only one subscription
      expect(subscriptionCalls.length, equals(1),
        reason: 'Should reject truly duplicate subscriptions');
    });

    test('should allow multiple author-specific subscriptions', () async {
      final subscriptionCalls = <List<Filter>>[];
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((invocation) {
            final filters = invocation.namedArguments[const Symbol('filters')] as List<Filter>;
            subscriptionCalls.add(filters);
            return eventStreamController.stream;
          });

      // Classic vines subscription
      await videoEventService.subscribeToVideoFeed(
        authors: ['25315276cbaeb8f2ed998ed55d15ef8c9cf2027baea191d1253d9a5c69a2b856'],
        limit: 100,
        replace: true,
      );

      expect(subscriptionCalls.length, equals(1));

      // Editor picks subscription (different author)
      await videoEventService.subscribeToVideoFeed(
        authors: ['70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082'],
        limit: 50,
        replace: false,
      );

      // Should have created a second subscription
      expect(subscriptionCalls.length, equals(2),
        reason: 'Should allow subscriptions with different author lists');
    });

    test('should correctly handle replace parameter', () async {
      final subscriptionCalls = <List<Filter>>[];
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((invocation) {
            final filters = invocation.namedArguments[const Symbol('filters')] as List<Filter>;
            subscriptionCalls.add(filters);
            return eventStreamController.stream;
          });

      // Add some test events
      final event1 = Event(
        'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        22,
        [['url', 'https://example.com/video1.mp4'], ['m', 'video/mp4']],
        'Video 1',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event1.id = 'video-1';

      // First subscription
      await videoEventService.subscribeToVideoFeed(limit: 50);
      await Future.delayed(Duration(milliseconds: 10));
      
      eventStreamController.add(event1);
      await Future.delayed(Duration(milliseconds: 10));
      
      expect(videoEventService.videoEvents.length, equals(1));

      // Second subscription with replace=true should clear existing videos
      await videoEventService.subscribeToVideoFeed(
        limit: 100,
        replace: true,
      );

      expect(videoEventService.videoEvents.length, equals(0),
        reason: 'replace=true should clear existing videos');
      expect(subscriptionCalls.length, equals(2));
    });

    test('should track active subscription parameters', () async {
      // This test exposes the current bug where subscription parameters aren't tracked
      final subscriptionCalls = <List<Filter>>[];
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((invocation) {
            final filters = invocation.namedArguments[const Symbol('filters')] as List<Filter>;
            subscriptionCalls.add(filters);
            return eventStreamController.stream;
          });

      // Subscription with specific parameters
      await videoEventService.subscribeToVideoFeed(
        authors: ['author1', 'author2'],
        hashtags: ['nostr', 'video'],
        limit: 75,
      );

      expect(subscriptionCalls.length, equals(1));

      // Different parameters - should be allowed
      await videoEventService.subscribeToVideoFeed(
        authors: ['author3'],
        hashtags: ['vine'],
        limit: 50,
      );

      expect(subscriptionCalls.length, equals(2),
        reason: 'Should allow subscriptions with different hashtags and authors');
    });

    test('should handle the classic vines -> open feed sequence correctly', () async {
      // This is the exact sequence that's failing in production
      final subscriptionCalls = <List<Filter>>[];
      when(() => mockNostrService.subscribeToEvents(filters: any(named: 'filters')))
          .thenAnswer((invocation) {
            final filters = invocation.namedArguments[const Symbol('filters')] as List<Filter>;
            subscriptionCalls.add(filters);
            return eventStreamController.stream;
          });

      // Step 1: Load classic vines (specific author)
      await videoEventService.subscribeToVideoFeed(
        authors: ['25315276cbaeb8f2ed998ed55d15ef8c9cf2027baea191d1253d9a5c69a2b856'],
        limit: 100,
        replace: true,
      );

      expect(subscriptionCalls.length, equals(1));
      expect(subscriptionCalls[0][0].authors, isNotNull);
      expect(subscriptionCalls[0][0].authors!.length, equals(1));

      // Step 2: Load open feed (no author filter) - THIS IS BEING WRONGLY REJECTED
      await videoEventService.subscribeToVideoFeed(
        limit: 300,
        replace: false,
      );

      expect(subscriptionCalls.length, equals(2),
        reason: 'Open feed subscription should not be rejected as duplicate of author-specific subscription');
      expect(subscriptionCalls[1][0].authors, isNull,
        reason: 'Open feed should have no author filter');

      // Step 3: Load editor picks (different specific author)
      await videoEventService.subscribeToVideoFeed(
        authors: ['70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082'],
        limit: 50,
        replace: false,
      );

      expect(subscriptionCalls.length, equals(3),
        reason: 'All three subscriptions should be allowed as they have different parameters');
    });
  });
}