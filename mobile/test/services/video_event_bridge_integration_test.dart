// ABOUTME: Integration tests for VideoEventBridge event-driven loading
// ABOUTME: Tests following vs discovery feed sequencing and triggers

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_event_bridge.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_manager_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/models/user_profile.dart' as models;
import 'package:openvine/services/nostr_key_manager.dart';

// Mock classes for testing
class MockVideoEventService extends VideoEventService {
  List<VideoEvent> _mockEvents = [];
  int _subscribeCallCount = 0;
  List<Map<String, dynamic>> _subscribeCallLog = [];
  
  MockVideoEventService(INostrService nostrService, SubscriptionManager subscriptionManager) 
    : super(nostrService, subscriptionManager: subscriptionManager);
  
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
    int? limit,
    bool replace = false,
    bool includeReposts = false,
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
      'includeReposts': includeReposts,
      'callNumber': _subscribeCallCount,
    });
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
  MockUserProfileService(INostrService nostrService, SubscriptionManager subscriptionManager) 
    : super(nostrService, subscriptionManager: subscriptionManager);
    
  @override
  bool hasProfile(String pubkey) => true;
  
  @override
  Future<models.UserProfile?> fetchProfile(String pubkey, {bool forceRefresh = false}) async {
    return null;
  }
}

class MockSocialService extends SocialService {
  Set<String> _followingPubkeys = {};
  
  MockSocialService(INostrService nostrService, AuthService authService, SubscriptionManager subscriptionManager) 
    : super(nostrService, authService, subscriptionManager: subscriptionManager);
  
  @override
  List<String> get followingPubkeys => _followingPubkeys.toList();
  
  void setFollowing(Set<String> pubkeys) {
    _followingPubkeys = pubkeys;
  }
}

// Simple mock implementations for testing
class MockNostrService implements INostrService {
  @override
  bool get isInitialized => true;
  
  @override
  bool get isDisposed => false;
  
  @override
  List<String> get connectedRelays => ['wss://test.relay'];
  
  @override
  String? get publicKey => null;
  
  @override
  bool get hasKeys => false;
  
  @override
  NostrKeyManager get keyManager => throw UnimplementedError();
  
  @override
  int get relayCount => 1;
  
  @override
  int get connectedRelayCount => 1;
  
  @override
  List<String> get relays => ['wss://test.relay'];
  
  @override
  Map<String, dynamic> get relayStatuses => {};
  
  @override
  void addListener(listener) {}
  
  @override
  void removeListener(listener) {}
  
  @override
  void dispose() {}
  
  @override
  bool get hasListeners => false;
  
  @override
  void notifyListeners() {}
  
  @override
  Future<void> initialize({List<String>? customRelays}) async {}
  
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockAuthService implements AuthService {
  @override
  bool get isAuthenticated => false;
  
  @override
  String? get currentPublicKeyHex => null;
  
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('VideoEventBridge Integration', () {
    late VideoEventBridge bridge;
    late MockVideoEventService mockVideoEventService;
    late VideoManagerService videoManager;
    late MockUserProfileService mockUserProfileService;
    late MockSocialService mockSocialService;
    late INostrService mockNostrService;
    late AuthService mockAuthService;
    late SubscriptionManager mockSubscriptionManager;
    
    setUp(() {
      mockNostrService = MockNostrService();
      mockAuthService = MockAuthService();
      mockSubscriptionManager = SubscriptionManager(mockNostrService);
      
      mockVideoEventService = MockVideoEventService(mockNostrService, mockSubscriptionManager);
      videoManager = VideoManagerService();
      mockUserProfileService = MockUserProfileService(mockNostrService, mockSubscriptionManager);
      mockSocialService = MockSocialService(mockNostrService, mockAuthService, mockSubscriptionManager);
      
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
      mockSubscriptionManager.dispose();
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
      
      // When user has follows, classic vines should NOT be included (only fallback when no follows)
      expect(firstCall['authors'], hasLength(2));
      expect(firstCall['authors'], isNot(contains('25315276cbaeb8f2ed998ed55d15ef8c9cf2027baea191d1253d9a5c69a2b856')));
    });
    
    test('should trigger discovery feed after following content arrives', () async {
      const followingPubkey = 'following123';
      mockSocialService.setFollowing({followingPubkey});
      
      await bridge.initialize();
      
      // Initially only one call for following content
      expect(mockVideoEventService.subscribeCallCount, 1);
      
      // Add some following videos to trigger discovery feed
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f1000000000000000000000000000000000000000000000000000000000001', pubkey: followingPubkey));
      await Future.delayed(const Duration(milliseconds: 20));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f2000000000000000000000000000000000000000000000000000000000002', pubkey: followingPubkey));
      await Future.delayed(const Duration(milliseconds: 20));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f3000000000000000000000000000000000000000000000000000000000003', pubkey: followingPubkey));
      await Future.delayed(const Duration(milliseconds: 20));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f4000000000000000000000000000000000000000000000000000000000004', pubkey: followingPubkey));
      await Future.delayed(const Duration(milliseconds: 20));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f5000000000000000000000000000000000000000000000000000000000005', pubkey: followingPubkey));
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
      
      // Should have made classic vines fallback call
      expect(mockVideoEventService.subscribeCallCount, 1);
      final firstCall = mockVideoEventService.subscribeCallLog[0];
      expect(firstCall['authors'], contains('033877f4080835f162880482590762c0a7508851e88fe164dd89028743914da5')); // Classic vines fallback
    });
    
    test('should properly prioritize videos in manager', () async {
      const followingPubkey = 'following123';
      const discoveryPubkey = 'discovery456';
      mockSocialService.setFollowing({followingPubkey});
      
      await bridge.initialize();
      
      // Add videos in mixed order to simulate real-world scenario
      mockVideoEventService.addMockEvent(createTestVideo(id: 'd1000000000000000000000000000000000000000000000000000000000001', pubkey: discoveryPubkey));
      await Future.delayed(const Duration(milliseconds: 10));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f1000000000000000000000000000000000000000000000000000000000001', pubkey: followingPubkey));
      await Future.delayed(const Duration(milliseconds: 10));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'd2000000000000000000000000000000000000000000000000000000000002', pubkey: discoveryPubkey));
      await Future.delayed(const Duration(milliseconds: 10));
      
      mockVideoEventService.addMockEvent(createTestVideo(id: 'f2000000000000000000000000000000000000000000000000000000000002', pubkey: followingPubkey));
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
        final paddedId = i.toString().padLeft(4, '0');
        mockVideoEventService.addMockEvent(createTestVideo(id: 'f${paddedId}00000000000000000000000000000000000000000000000000000000$paddedId', pubkey: followingPubkey));
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