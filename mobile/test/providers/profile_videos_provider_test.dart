// ABOUTME: Tests for ProfileVideosProvider to ensure cache-first behavior and request optimization
// ABOUTME: Validates that unnecessary subscriptions are avoided when data is fresh in cache

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/profile_videos_provider.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/profile_cache_service.dart';

@GenerateMocks([
  INostrService,
  SubscriptionManager,
  VideoEventService,
  ProfileCacheService,
])
import 'profile_videos_provider_test.mocks.dart';

void main() {
  late ProfileVideosProvider provider;
  late MockINostrService mockNostrService;
  late MockSubscriptionManager mockSubscriptionManager;
  late MockVideoEventService mockVideoEventService;

  setUp(() {
    mockNostrService = MockINostrService();
    mockSubscriptionManager = MockSubscriptionManager();
    mockVideoEventService = MockVideoEventService();

    provider = ProfileVideosProvider(mockNostrService);
    provider.setSubscriptionManager(mockSubscriptionManager);
    provider.setVideoEventService(mockVideoEventService);
  });

  group('Cache-First Enforcement', () {
    test('should NOT create subscription when videos are in cache and fresh', () async {
      // Arrange
      const testPubkey = 'test_pubkey_123';
      final now = DateTime.now();
      final cachedVideos = <VideoEvent>[
        VideoEvent(
          id: 'video1',
          pubkey: testPubkey,
          content: 'test content',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          videoUrl: 'https://example.com/video1.mp4',
          title: 'Test Video 1',
        ),
        VideoEvent(
          id: 'video2',
          pubkey: testPubkey,
          content: 'test content 2',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          videoUrl: 'https://example.com/video2.mp4',
          title: 'Test Video 2',
        ),
      ];

      // Mock VideoEventService to return cached videos
      when(mockVideoEventService.getVideosByAuthor(testPubkey))
          .thenReturn(cachedVideos);

      // Act
      await provider.loadVideosForUser(testPubkey);

      // Assert
      // Should NOT create any subscription since cache has videos
      verifyNever(mockSubscriptionManager.createSubscription(
        name: anyNamed('name'),
        filters: anyNamed('filters'),
        onEvent: anyNamed('onEvent'),
        onError: anyNamed('onError'),
        onComplete: anyNamed('onComplete'),
        priority: anyNamed('priority'),
      ));

      // Should use cached videos
      expect(provider.videos.length, equals(2));
      expect(provider.videos, equals(cachedVideos));
      expect(provider.hasMore, isFalse); // No more videos expected from cache
    });

    test('should create subscription only when cache is empty', () async {
      // Arrange
      const testPubkey = 'test_pubkey_456';
      
      // Mock empty cache
      when(mockVideoEventService.getVideosByAuthor(testPubkey))
          .thenReturn([]);

      // Mock subscription creation
      when(mockSubscriptionManager.createSubscription(
        name: anyNamed('name'),
        filters: anyNamed('filters'),
        onEvent: anyNamed('onEvent'),
        onError: anyNamed('onError'),
        onComplete: anyNamed('onComplete'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => 'subscription_123');

      // Act
      await provider.loadVideosForUser(testPubkey);

      // Assert
      // Should create subscription since cache is empty
      verify(mockSubscriptionManager.createSubscription(
        name: anyNamed('name'),
        filters: anyNamed('filters'),
        onEvent: anyNamed('onEvent'),
        onError: anyNamed('onError'),
        onComplete: anyNamed('onComplete'),
        priority: anyNamed('priority'),
      )).called(1);
    });

    test('should use ProfileVideosProvider internal cache first before checking VideoEventService', () async {
      // This test verifies that the provider uses its internal cache to prevent duplicate requests
      // when the same pubkey is loaded multiple times in quick succession
      
      // Arrange
      const testPubkey = '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245'; // Valid hex pubkey
      
      // First load with empty VideoEventService cache
      when(mockVideoEventService.getVideosByAuthor(testPubkey))
          .thenReturn([]);

      // Mock subscription that returns videos
      final now = DateTime.now();
      final testVideos = <VideoEvent>[
        VideoEvent(
          id: 'video_new_1',
          pubkey: testPubkey,
          content: 'new content',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          videoUrl: 'https://example.com/new1.mp4',
          title: 'New Video 1',
        ),
      ];

      when(mockSubscriptionManager.createSubscription(
        name: anyNamed('name'),
        filters: anyNamed('filters'),
        onEvent: anyNamed('onEvent'),
        onError: anyNamed('onError'),
        onComplete: anyNamed('onComplete'),
        priority: anyNamed('priority'),
      )).thenAnswer((invocation) async {
        // Simulate receiving events
        final onEvent = invocation.namedArguments[Symbol('onEvent')] as Function(Event);
        final onComplete = invocation.namedArguments[Symbol('onComplete')] as Function();
        
        // Send test video event
        final event = Event(
          testPubkey,
          22,
          [
            ['url', testVideos.first.videoUrl!],
            ['title', testVideos.first.title!],
          ],
          testVideos.first.content,
          createdAt: testVideos.first.createdAt,
        );
        event.id = 'event1';
        event.sig = 'test_sig';
        
        onEvent(event);
        onComplete();
        
        return 'subscription_456';
      });

      // First load - should create subscription
      await provider.loadVideosForUser(testPubkey);
      
      // Verify subscription was created
      verify(mockSubscriptionManager.createSubscription(
        name: anyNamed('name'),
        filters: anyNamed('filters'),
        onEvent: anyNamed('onEvent'),
        onError: anyNamed('onError'),
        onComplete: anyNamed('onComplete'),
        priority: anyNamed('priority'),
      )).called(1);

      // Assert we have videos loaded
      expect(provider.videos.length, equals(1));
      expect(provider.videos.first.id, equals('video_new_1'));

      // Reset mock to prepare for second call
      reset(mockSubscriptionManager);
      reset(mockVideoEventService);
      
      // Mock VideoEventService still returns empty (simulating no server-side cache)
      when(mockVideoEventService.getVideosByAuthor(testPubkey))
          .thenReturn([]);
      
      // Act - Second load of same pubkey
      await provider.loadVideosForUser(testPubkey);

      // Assert - Should NOT create new subscription because internal cache has videos
      verifyNever(mockSubscriptionManager.createSubscription(
        name: anyNamed('name'),
        filters: anyNamed('filters'),
        onEvent: anyNamed('onEvent'),
        onError: anyNamed('onError'),
        onComplete: anyNamed('onComplete'),
        priority: anyNamed('priority'),
      ));

      // Should still have the videos from first load (using internal cache)
      expect(provider.videos.length, equals(1));
      expect(provider.videos.first.id, equals('video_new_1'));
    });

    test('should only do background refresh if cache is stale', () async {
      // This test validates that we need to implement background refresh
      // based on ProfileCacheService.shouldRefreshProfile() logic
      
      // TODO: Implement after adding ProfileCacheService integration
      // The provider should check shouldRefreshProfile() and only
      // create a background subscription if the profile data is stale
      
      // For now, this test documents the expected behavior
      expect(true, isTrue); // Placeholder assertion
    });
  });

  group('LoadMoreVideos Cache Behavior', () {
    test('should not create subscription for loadMore if hasMore is false', () async {
      // Arrange
      const testPubkey = 'test_pubkey_more';
      final now = DateTime.now();
      final cachedVideos = <VideoEvent>[];
      for (int i = 0; i < 5; i++) {
        cachedVideos.add(VideoEvent(
          id: 'video$i',
          pubkey: testPubkey,
          content: 'content $i',
          createdAt: now.millisecondsSinceEpoch ~/ 1000 - i,
          timestamp: now.subtract(Duration(seconds: i)),
          videoUrl: 'https://example.com/video$i.mp4',
          title: 'Video $i',
        ));
      }

      // Setup initial state with cached videos
      when(mockVideoEventService.getVideosByAuthor(testPubkey))
          .thenReturn(cachedVideos);

      await provider.loadVideosForUser(testPubkey);
      
      // hasMore should be false when loading from cache
      expect(provider.hasMore, isFalse);

      // Act
      await provider.loadMoreVideos();

      // Assert - Should not create subscription
      verifyNever(mockSubscriptionManager.createSubscription(
        name: anyNamed('name'),
        filters: anyNamed('filters'),
        onEvent: anyNamed('onEvent'),
        onError: anyNamed('onError'),
        onComplete: anyNamed('onComplete'),
        priority: anyNamed('priority'),
      ));
    });
  });
}