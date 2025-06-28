// ABOUTME: Integration tests for VideoEventBridge event-driven loading
// ABOUTME: Tests following vs discovery feed sequencing and triggers

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
  int _subscribeCallCount = 0;
  List<Map<String, dynamic>> _subscribeCallLog = [];
  
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
    DateTime? since,
    DateTime? until,
    int? limit,
    bool replace = false,
  }) async {
    _subscribeCallCount++;
    _subscribeCallLog.add({
      'authors': authors,
      'hashtags': hashtags,
      'group': group,
      'since': since,
      'until': until,
      'limit': limit,
      'replace': replace,
      'callNumber': _subscribeCallCount,
    });
    
    // Simulate async behavior
    await Future.delayed(const Duration(milliseconds: 10));
  }
  
  List<Map<String, dynamic>> get subscribeCallLog => _subscribeCallLog;
  int get subscribeCallCount => _subscribeCallCount;
  
  void reset() {
    _mockEvents.clear();
    _subscribeCallCount = 0;
    _subscribeCallLog.clear();
  }
}

class MockUserProfileService extends UserProfileService {
  @override
  bool hasProfile(String pubkey) => true;
  
  @override
  void fetchProfile(String pubkey) {}
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
  group('VideoEventBridge Integration', () {
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
    
    test('should load following feed first when user has follows', () async {
      // Set up following list
      const followingPubkey1 = 'following123';
      const followingPubkey2 = 'following456';
      mockSocialService.setFollowing({followingPubkey1, followingPubkey2});
      
      // Initialize bridge
      await bridge.initialize();
      
      // Should have made initial subscription for following content
      expect(mockVideoEventService.subscribeCallCount, 1);
      final firstCall = mockVideoEventService.subscribeCallLog[0];
      expect(firstCall['replace'], true);
      expect(firstCall['authors'], contains(followingPubkey1));
      expect(firstCall['authors'], contains(followingPubkey2));
      
      // Classic vines should be included in following for now
      expect(firstCall['authors'], contains('25315276cbaeb8f2ed998ed55d15ef8c9cf2027baea191d1253d9a5c69a2b856'));
    });
    
    test('should trigger discovery feed after following content arrives', () async {
      const followingPubkey = 'following123';
      mockSocialService.setFollowing({followingPubkey});
      
      await bridge.initialize();
      
      // Initially only one call for following content
      expect(mockVideoEventService.subscribeCallCount, 1);
      
      // Add some following videos to trigger discovery feed
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f1', pubkey: followingPubkey));
      await Future.delayed(const Duration(milliseconds: 20));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f2', pubkey: followingPubkey));
      await Future.delayed(const Duration(milliseconds: 20));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f3', pubkey: followingPubkey));
      await Future.delayed(const Duration(milliseconds: 20));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f4', pubkey: followingPubkey));
      await Future.delayed(const Duration(milliseconds: 20));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f5', pubkey: followingPubkey));
      await Future.delayed(const Duration(milliseconds: 20));
      
      // Should have triggered discovery feed after reaching 5+ following videos
      expect(mockVideoEventService.subscribeCallCount, greaterThan(1));
      
      // Check the discovery feed call
      final discoveryCall = mockVideoEventService.subscribeCallLog.last;
      expect(discoveryCall['replace'], false);
      expect(discoveryCall['authors'], isNull); // Open feed for discovery
    });
    
    test('should load discovery feed directly when no follows', () async {
      // No following list
      mockSocialService.setFollowing({});
      
      await bridge.initialize();
      
      // Should have made discovery feed call directly
      expect(mockVideoEventService.subscribeCallCount, 1);
      final firstCall = mockVideoEventService.subscribeCallLog[0];
      expect(firstCall['authors'], isNull); // Open feed
    });
    
    test('should properly prioritize videos in manager', () async {
      const followingPubkey = 'following123';
      const discoveryPubkey = 'discovery456';
      mockSocialService.setFollowing({followingPubkey});
      
      await bridge.initialize();
      
      // Add videos in mixed order to simulate real-world scenario
      mockVideoEventService.addMockEvent(createTestVideo(id: 'd1', pubkey: discoveryPubkey));
      await Future.delayed(const Duration(milliseconds: 10));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f1', pubkey: followingPubkey));
      await Future.delayed(const Duration(milliseconds: 10));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'd2', pubkey: discoveryPubkey));
      await Future.delayed(const Duration(milliseconds: 10));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f2', pubkey: followingPubkey));
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Following videos should be at front, discovery at back
      final videos = videoManager.videos;
      expect(videos.length, 4);
      
      // Find following vs discovery videos
      final followingVideos = videos.where((v) => v.pubkey == followingPubkey).toList();
      final discoveryVideos = videos.where((v) => v.pubkey == discoveryPubkey).toList();
      
      expect(followingVideos.length, 2);
      expect(discoveryVideos.length, 2);
      
      // Following videos should come before discovery videos
      final firstFollowingIndex = videos.indexWhere((v) => v.pubkey == followingPubkey);
      final firstDiscoveryIndex = videos.indexWhere((v) => v.pubkey == discoveryPubkey);
      
      expect(firstFollowingIndex, lessThan(firstDiscoveryIndex));
    });
    
    test('should not trigger discovery feed multiple times', () async {
      const followingPubkey = 'following123';
      mockSocialService.setFollowing({followingPubkey});
      
      await bridge.initialize();
      
      // Add many following videos
      for (int i = 1; i <= 10; i++) {
        mockVideoEventService.addMockEvent(createTestVideo(id: 'f$i', pubkey: followingPubkey));
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      // Should have triggered discovery feed only once
      final discoveryFeedCalls = mockVideoEventService.subscribeCallLog
          .where((call) => call['replace'] == false && call['authors'] == null)
          .length;
      
      expect(discoveryFeedCalls, 1);
    });
  });
}