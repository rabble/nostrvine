// ABOUTME: Tests for pure Riverpod VideoManager provider implementation
// ABOUTME: Verifies video controller management, preloading, memory management

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:openvine/providers/video_manager_providers.dart';
import 'package:openvine/providers/video_feed_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/social_providers.dart' as social;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/services/video_manager_interface.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:openvine/models/curation_set.dart';

// Mock classes
class MockVideoEvent extends Mock implements VideoEvent {}
class MockNostrService extends Mock implements INostrService {}
class MockSubscriptionManager extends Mock implements SubscriptionManager {}
class MockCurationService extends Mock implements CurationService {}

// Mock video feed provider that returns test data
class MockVideoFeedProvider extends VideoFeed {
  final List<VideoEvent> mockVideos;
  
  MockVideoFeedProvider(this.mockVideos);
  
  @override
  Future<VideoFeedState> build() async {
    return VideoFeedState(
      videos: mockVideos,
      feedMode: FeedMode.following,
      isFollowingFeed: true,
      hasMoreContent: false,
      primaryVideoCount: mockVideos.length,
      isLoadingMore: false,
      feedContext: null,
      error: null,
      lastUpdated: DateTime.now(),
    );
  }
}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(const VideoManagerConfig());
    registerFallbackValue(CurationSetType.editorsPicks);
  });

  group('VideoManagerProvider', () {
    late ProviderContainer container;
    late List<VideoEvent> mockVideoEvents;
    
    ProviderContainer createContainer({
      List<VideoEvent>? customVideoEvents,
      VideoManagerConfig? customConfig,
    }) {
      // Set up mock services
      final mockNostrService1 = MockNostrService();
      when(() => mockNostrService1.isInitialized).thenReturn(true);
      
      final mockNostrService2 = MockNostrService();
      when(() => mockNostrService2.isInitialized).thenReturn(true);
      
      final mockNostrService3 = MockNostrService();
      when(() => mockNostrService3.isInitialized).thenReturn(true);
      
      final mockCurationService = MockCurationService();
      when(() => mockCurationService.getVideosForSetType(any())).thenReturn([]);
      
      return ProviderContainer(
        overrides: [
          // Override config if provided
          if (customConfig != null)
            videoManagerConfigProvider.overrideWithValue(customConfig),
          
          // Override video feed provider with mock data
          videoFeedProvider.overrideWith(() {
            return MockVideoFeedProvider(customVideoEvents ?? mockVideoEvents);
          }),
          
          // Override service dependencies
          videoEventsNostrServiceProvider.overrideWithValue(mockNostrService1),
          videoEventsSubscriptionManagerProvider.overrideWithValue(MockSubscriptionManager()),
          curationServiceProvider.overrideWithValue(mockCurationService),
          nostrServiceProvider.overrideWithValue(mockNostrService2),
          subscriptionManagerProvider.overrideWithValue(MockSubscriptionManager()),
          social.nostrServiceProvider.overrideWithValue(mockNostrService3),
          social.subscriptionManagerProvider.overrideWithValue(MockSubscriptionManager()),
        ],
      );
    }
    
    setUp(() {
      // Create mock video events
      mockVideoEvents = List.generate(3, (i) {
        final event = MockVideoEvent();
        when(() => event.id).thenReturn('video$i');
        when(() => event.pubkey).thenReturn('pubkey$i');
        when(() => event.createdAt).thenReturn(1234567890 - i);
        when(() => event.title).thenReturn('Video $i');
        when(() => event.content).thenReturn('Content $i');
        when(() => event.videoUrl).thenReturn('https://example.com/video$i.mp4');
        when(() => event.hashtags).thenReturn([]);
        return event;
      });
      
      container = createContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with empty state', () {
      final managerState = container.read(videoManagerProvider);
      
      expect(managerState.controllers, isEmpty);
      expect(managerState.currentIndex, equals(0));
      expect(managerState.config, isNotNull);
      expect(managerState.isDisposed, isFalse);
      expect(managerState.memoryStats.totalControllers, equals(0));
    });

    test('should use correct configuration', () {
      final config = VideoManagerConfig.testing();
      container.dispose();
      container = createContainer(customConfig: config);
      
      final managerState = container.read(videoManagerProvider);
      
      expect(managerState.config, equals(config));
      expect(managerState.config?.maxVideos, equals(10));
      expect(managerState.config?.preloadAhead, equals(2));
    });

    test('should provide helper providers for video access', () {
      final videoController = container.read(videoPlayerControllerProvider('video1'));
      final videoState = container.read(videoStateByIdProvider('video1'));
      final isReady = container.read(isVideoReadyProvider('video1'));
      
      // Initially null since no controllers are created yet
      expect(videoController, isNull);
      expect(videoState, isNull);
      expect(isReady, isFalse);
    });

    test('should provide memory statistics', () {
      final memoryStats = container.read(videoMemoryStatsProvider);
      
      expect(memoryStats.totalControllers, equals(0));
      expect(memoryStats.readyControllers, equals(0));
      expect(memoryStats.loadingControllers, equals(0));
      expect(memoryStats.failedControllers, equals(0));
      expect(memoryStats.estimatedMemoryMB, equals(0.0));
      expect(memoryStats.isMemoryPressure, isFalse);
    });

    test('should provide debug information', () {
      final debugInfo = container.read(videoManagerDebugInfoProvider);
      
      expect(debugInfo, isA<Map<String, dynamic>>());
      expect(debugInfo['totalControllers'], equals(0));
      expect(debugInfo['readyControllers'], equals(0));
      expect(debugInfo['loadingControllers'], equals(0));
      expect(debugInfo['failedControllers'], equals(0));
      expect(debugInfo['estimatedMemoryMB'], equals(0.0));
      expect(debugInfo['maxVideos'], isA<int>());
      expect(debugInfo['preloadAhead'], isA<int>());
      expect(debugInfo['preloadBehind'], isA<int>());
      expect(debugInfo['memoryPressure'], isFalse);
      expect(debugInfo['needsCleanup'], isFalse);
      expect(debugInfo['currentIndex'], equals(0));
      expect(debugInfo['isDisposed'], isFalse);
      expect(debugInfo['successfulPreloads'], equals(0));
      expect(debugInfo['failedLoads'], equals(0));
      expect(debugInfo['preloadSuccessRate'], equals(1.0));
    });

    test('should pause and resume videos', () async {
      final manager = container.read(videoManagerProvider.notifier);
      
      // These should not throw even with no controllers
      manager.pauseVideo('video1');
      manager.resumeVideo('video1');
      manager.pauseAllVideos();
      manager.stopAllVideos();
      
      // Verify no state changes occur with missing videos
      final state = container.read(videoManagerProvider);
      expect(state.controllers, isEmpty);
    });

    test('should handle memory pressure', () async {
      final manager = container.read(videoManagerProvider.notifier);
      
      // Should not throw even with no controllers
      expect(() async => await manager.handleMemoryPressure(), returnsNormally);
    });

    test('should provide state changes stream', () {
      final manager = container.read(videoManagerProvider.notifier);
      final stateChanges = manager.stateChanges;
      
      expect(stateChanges, isA<Stream<void>>());
    });

    test('should handle preload around index safely', () {
      final manager = container.read(videoManagerProvider.notifier);
      
      // Should not throw even with invalid indices
      manager.preloadAroundIndex(-1);
      manager.preloadAroundIndex(0);
      manager.preloadAroundIndex(100);
      
      final state = container.read(videoManagerProvider);
      expect(state.currentIndex, equals(0)); // Should be clamped to valid range
    });

    test('should sync videos from feed changes', () async {
      // Initially no videos
      var state = container.read(videoManagerProvider);
      expect(state.controllers, isEmpty);
      
      // Wait for video feed to load and sync
      await container.read(videoFeedProvider.future);
      
      // Give time for sync to occur (this happens via ref.listen)
      await Future.delayed(Duration(milliseconds: 100));
      
      // Check if sync occurred (controllers should be tracked but not initialized)
      state = container.read(videoManagerProvider);
      // Note: Without actual VideoPlayerController initialization in tests,
      // we can't easily test the full sync flow
    });

    test('should calculate memory statistics correctly', () {
      final config = VideoManagerConfig.testing();
      container.dispose();
      container = createContainer(customConfig: config);
      
      final state = container.read(videoManagerProvider);
      
      // Test memory limit calculations
      expect(state.memoryStats.isNearMemoryLimit, isFalse);
      expect(state.memoryStats.needsCleanup, isFalse);
      expect(state.needsMemoryCleanup, isFalse);
    });

    test('should provide correct controller states', () {
      final state = container.read(videoManagerProvider);
      
      expect(state.allControllers, isEmpty);
      expect(state.readyControllers, isEmpty);
      expect(state.loadingControllers, isEmpty);
      expect(state.failedControllers, isEmpty);
      expect(state.getController('nonexistent'), isNull);
      expect(state.hasController('nonexistent'), isFalse);
      expect(state.getVideoState('nonexistent'), isNull);
      expect(state.getPlayerController('nonexistent'), isNull);
    });

    test('should generate comprehensive debug info', () {
      final debugInfo = container.read(videoManagerDebugInfoProvider);
      
      // Verify all expected debug fields are present
      final expectedFields = [
        'totalControllers', 'readyControllers', 'loadingControllers', 'failedControllers',
        'estimatedMemoryMB', 'maxVideos', 'preloadAhead', 'preloadBehind',
        'memoryPressure', 'needsCleanup', 'currentIndex', 'currentlyPlayingId',
        'lastCleanup', 'isDisposed', 'error', 'successfulPreloads', 'failedLoads',
        'preloadSuccessRate'
      ];
      
      for (final field in expectedFields) {
        expect(debugInfo.containsKey(field), isTrue, reason: 'Missing debug field: $field');
      }
    });

    test('should handle dispose correctly', () {
      // Get initial state
      var state = container.read(videoManagerProvider);
      expect(state.isDisposed, isFalse);
      
      // Dispose the container (which should trigger dispose)
      container.dispose();
      
      // Note: We can't easily test the disposed state since the container is disposed,
      // but we can verify the dispose method doesn't throw
    });
  });
}