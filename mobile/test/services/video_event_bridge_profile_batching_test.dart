// ABOUTME: Tests for VideoEventBridge profile batching optimization
// ABOUTME: Verifies that fetchMultipleProfiles is used instead of individual fetchProfile calls

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_event_bridge.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_manager_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/social_service.dart';

// Mock classes for testing
class MockVideoEventService extends VideoEventService {
  List<VideoEvent> _mockEvents = [];
  
  @override
  List<VideoEvent> get videoEvents => _mockEvents;
  
  @override
  bool get hasEvents => _mockEvents.isNotEmpty;
  
  @override
  int get eventCount => _mockEvents.length;
  
  void addMockEvent(VideoEvent event) {
    _mockEvents.add(event);
    notifyListeners();
  }
  
  @override
  Future<void> subscribeToVideoFeed({
    List<String>? authors,
    List<String>? hashtags,
    String? group,
    int? since,
    int? until,
    int limit = 50,
    bool replace = true,
    bool includeReposts = false,
  }) async {
    // No-op for testing
  }
}

class MockUserProfileService extends UserProfileService {
  final Set<String> _cachedProfiles = {};
  int individualFetchProfileCallCount = 0;
  int fetchMultipleProfilesCallCount = 0;
  List<String> lastFetchedPubkeys = [];
  List<List<String>> fetchMultipleProfilesCalls = [];
  
  @override
  bool hasProfile(String pubkey) => _cachedProfiles.contains(pubkey);
  
  @override
  void fetchProfile(String pubkey) {
    individualFetchProfileCallCount++;
    _cachedProfiles.add(pubkey);
  }
  
  @override
  Future<void> fetchMultipleProfiles(List<String> pubkeys, {bool forceRefresh = false}) async {
    fetchMultipleProfilesCallCount++;
    lastFetchedPubkeys = List.from(pubkeys);
    fetchMultipleProfilesCalls.add(List.from(pubkeys));
    _cachedProfiles.addAll(pubkeys);
  }
  
  void reset() {
    _cachedProfiles.clear();
    individualFetchProfileCallCount = 0;
    fetchMultipleProfilesCallCount = 0;
    lastFetchedPubkeys = [];
    fetchMultipleProfilesCalls.clear();
  }
}

class MockSocialService extends SocialService {
  Set<String> _followingPubkeys = {};
  
  @override
  Set<String> get followingPubkeys => _followingPubkeys;
  
  void setFollowing(Set<String> pubkeys) {
    _followingPubkeys = pubkeys;
  }
}

void main() {
  group('VideoEventBridge Profile Batching', () {
    late VideoEventBridge bridge;
    late MockVideoEventService mockVideoEventService;
    late VideoManagerService videoManager;
    late MockUserProfileService mockUserProfileService;
    late MockSocialService mockSocialService;
    
    setUp(() {
      mockVideoEventService = MockVideoEventService();
      videoManager = VideoManagerService();
      mockUserProfileService = MockUserProfileService();
      mockSocialService = MockSocialService();
      
      bridge = VideoEventBridge(
        videoEventService: mockVideoEventService,
        videoManager: videoManager,
        userProfileService: mockUserProfileService,
        socialService: mockSocialService,
      );
    });
    
    tearDown(() {
      bridge.dispose();
      videoManager.dispose();
      mockUserProfileService.reset();
    });
    
    VideoEvent createTestVideo({
      required String id,
      required String pubkey,
      String? content,
    }) {
      final now = DateTime.now();
      return VideoEvent(
        id: id,
        pubkey: pubkey,
        content: content ?? 'Test video content',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        videoUrl: 'https://example.com/$id.mp4',
        hashtags: [],
        rawTags: {},
        isRepost: false,
        isFlaggedContent: false,
      );
    }
    
    test('should use fetchMultipleProfiles instead of individual fetchProfile calls', () async {
      // Initialize bridge
      await bridge.initialize();
      
      // Add multiple videos from different authors
      final pubkeys = ['author1', 'author2', 'author3', 'author4', 'author5'];
      
      for (int i = 0; i < pubkeys.length; i++) {
        mockVideoEventService.addMockEvent(
          createTestVideo(id: 'video$i', pubkey: pubkeys[i])
        );
      }
      
      // Wait for processing
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should have called fetchMultipleProfiles once
      expect(mockUserProfileService.fetchMultipleProfilesCallCount, 1);
      
      // Should NOT have called individual fetchProfile
      expect(mockUserProfileService.individualFetchProfileCallCount, 0);
      
      // Should have requested all unique pubkeys
      expect(mockUserProfileService.lastFetchedPubkeys.toSet(), pubkeys.toSet());
    });
    
    test('should not re-fetch already cached profiles', () async {
      await bridge.initialize();
      
      // Pre-cache some profiles
      mockUserProfileService._cachedProfiles.addAll(['cached1', 'cached2']);
      
      // Add videos from both cached and new authors
      final videos = [
        createTestVideo(id: 'v1', pubkey: 'cached1'),
        createTestVideo(id: 'v2', pubkey: 'cached2'),
        createTestVideo(id: 'v3', pubkey: 'new1'),
        createTestVideo(id: 'v4', pubkey: 'new2'),
      ];
      
      for (final video in videos) {
        mockVideoEventService.addMockEvent(video);
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should only fetch new profiles
      expect(mockUserProfileService.fetchMultipleProfilesCallCount, 1);
      expect(mockUserProfileService.lastFetchedPubkeys.toSet(), {'new1', 'new2'});
    });
    
    test('should handle empty pubkey list gracefully', () async {
      await bridge.initialize();
      
      // Pre-cache all profiles
      mockUserProfileService._cachedProfiles.addAll(['author1', 'author2']);
      
      // Add videos from already cached authors
      mockVideoEventService.addMockEvent(createTestVideo(id: 'v1', pubkey: 'author1'));
      mockVideoEventService.addMockEvent(createTestVideo(id: 'v2', pubkey: 'author2'));
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should not call fetchMultipleProfiles with empty list
      expect(mockUserProfileService.fetchMultipleProfilesCallCount, 0);
    });
    
    test('should batch profiles across multiple video additions', () async {
      await bridge.initialize();
      
      // Add videos in two batches
      // First batch
      mockVideoEventService.addMockEvent(createTestVideo(id: 'v1', pubkey: 'author1'));
      mockVideoEventService.addMockEvent(createTestVideo(id: 'v2', pubkey: 'author2'));
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Second batch with some new authors
      mockVideoEventService.addMockEvent(createTestVideo(id: 'v3', pubkey: 'author3'));
      mockVideoEventService.addMockEvent(createTestVideo(id: 'v4', pubkey: 'author4'));
      mockVideoEventService.addMockEvent(createTestVideo(id: 'v5', pubkey: 'author1')); // Duplicate
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should have made two batch calls
      expect(mockUserProfileService.fetchMultipleProfilesCallCount, 2);
      
      // First call should have author1 and author2
      expect(mockUserProfileService.fetchMultipleProfilesCalls[0].toSet(), {'author1', 'author2'});
      
      // Second call should only have new authors (not duplicates)
      expect(mockUserProfileService.fetchMultipleProfilesCalls[1].toSet(), {'author3', 'author4'});
    });
    
    test('should handle large batches efficiently', () async {
      await bridge.initialize();
      
      // Add 100 videos from unique authors
      final pubkeys = List.generate(100, (i) => 'author$i');
      
      for (int i = 0; i < pubkeys.length; i++) {
        mockVideoEventService.addMockEvent(
          createTestVideo(id: 'video$i', pubkey: pubkeys[i])
        );
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Should still use batch fetching
      expect(mockUserProfileService.fetchMultipleProfilesCallCount, greaterThanOrEqualTo(1));
      expect(mockUserProfileService.individualFetchProfileCallCount, 0);
      
      // All profiles should have been requested
      final allRequestedPubkeys = mockUserProfileService.fetchMultipleProfilesCalls
          .expand((calls) => calls)
          .toSet();
      expect(allRequestedPubkeys, pubkeys.toSet());
    });
  });
}