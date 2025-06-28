// ABOUTME: Test for blocklist filtering in VideoManagerService
// ABOUTME: Ensures blocked content is filtered from video feed

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/services/video_manager_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_manager_interface.dart';

@GenerateMocks([ContentBlocklistService, SeenVideosService])
import 'video_manager_blocklist_test.mocks.dart';

void main() {
  group('VideoManagerService Blocklist Tests', () {
    late VideoManagerService videoManager;
    late MockContentBlocklistService mockBlocklistService;
    late MockSeenVideosService mockSeenVideosService;
    
    setUp(() {
      mockBlocklistService = MockContentBlocklistService();
      mockSeenVideosService = MockSeenVideosService();
      
      // Default mock behavior
      when(mockBlocklistService.shouldFilterFromFeeds(any)).thenReturn(false);
      when(mockSeenVideosService.hasSeenVideo(any)).thenReturn(false);
      
      videoManager = VideoManagerService(
        config: const VideoManagerConfig(),
        seenVideosService: mockSeenVideosService,
        blocklistService: mockBlocklistService,
      );
    });
    
    tearDown(() {
      videoManager.dispose();
    });

    test('addVideoEvent filters blocked content', () async {
      // Set up blocked pubkey
      final blockedPubkey = 'blocked_pubkey_12345';
      when(mockBlocklistService.shouldFilterFromFeeds(blockedPubkey)).thenReturn(true);
      
      // Create a video from blocked user
      final blockedVideo = VideoEvent(
        id: 'blocked_video_id',
        pubkey: blockedPubkey,
        videoUrl: 'https://example.com/blocked.mp4',
        content: 'This should be blocked',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        hashtags: [],
        rawTags: {},
      );
      
      // Try to add blocked video
      await videoManager.addVideoEvent(blockedVideo);
      
      // Verify video was not added
      expect(videoManager.videos.length, equals(0));
      expect(videoManager.videos.any((v) => v.id == 'blocked_video_id'), isFalse);
      
      // Verify blocklist service was called
      verify(mockBlocklistService.shouldFilterFromFeeds(blockedPubkey)).called(1);
    });

    test('addVideoEvent allows non-blocked content', () async {
      // Set up non-blocked pubkey
      final allowedPubkey = 'allowed_pubkey_12345';
      when(mockBlocklistService.shouldFilterFromFeeds(allowedPubkey)).thenReturn(false);
      
      // Create a video from allowed user
      final allowedVideo = VideoEvent(
        id: 'allowed_video_id',
        pubkey: allowedPubkey,
        videoUrl: 'https://example.com/allowed.mp4',
        content: 'This should be allowed',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        hashtags: [],
        rawTags: {},
      );
      
      // Add allowed video
      await videoManager.addVideoEvent(allowedVideo);
      
      // Verify video was added
      expect(videoManager.videos.length, equals(1));
      expect(videoManager.videos.first.id, equals('allowed_video_id'));
      
      // Verify blocklist service was called
      verify(mockBlocklistService.shouldFilterFromFeeds(allowedPubkey)).called(1);
    });

    test('filterExistingVideos removes blocked videos from list', () async {
      // First add some videos without blocklist
      final video1 = VideoEvent(
        id: 'video1',
        pubkey: 'pubkey1',
        videoUrl: 'https://example.com/1.mp4',
        content: 'Video 1',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        hashtags: [],
        rawTags: {},
      );
      
      final video2 = VideoEvent(
        id: 'video2',
        pubkey: 'pubkey2',
        videoUrl: 'https://example.com/2.mp4',
        content: 'Video 2',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        hashtags: [],
        rawTags: {},
      );
      
      final video3 = VideoEvent(
        id: 'video3',
        pubkey: 'pubkey3',
        videoUrl: 'https://example.com/3.mp4',
        content: 'Video 3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        hashtags: [],
        rawTags: {},
      );
      
      // Add all videos
      await videoManager.addVideoEvent(video1);
      await videoManager.addVideoEvent(video2);
      await videoManager.addVideoEvent(video3);
      
      expect(videoManager.videos.length, equals(3));
      
      // Now set up blocklist for pubkey2
      when(mockBlocklistService.shouldFilterFromFeeds('pubkey2')).thenReturn(true);
      
      // Filter existing videos
      videoManager.filterExistingVideos();
      
      // Verify video2 was removed
      expect(videoManager.videos.length, equals(2));
      expect(videoManager.videos.any((v) => v.id == 'video2'), isFalse);
      expect(videoManager.videos.any((v) => v.id == 'video1'), isTrue);
      expect(videoManager.videos.any((v) => v.id == 'video3'), isTrue);
    });

    test('filterExistingVideos does nothing when blocklist service is null', () async {
      // Create video manager without blocklist service
      final videoManagerNoBlocklist = VideoManagerService(
        config: const VideoManagerConfig(),
        seenVideosService: mockSeenVideosService,
        blocklistService: null,
      );
      
      // Add a video
      final video = VideoEvent(
        id: 'video1',
        pubkey: 'pubkey1',
        videoUrl: 'https://example.com/1.mp4',
        content: 'Video 1',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        hashtags: [],
        rawTags: {},
      );
      
      await videoManagerNoBlocklist.addVideoEvent(video);
      expect(videoManagerNoBlocklist.videos.length, equals(1));
      
      // Try to filter - should do nothing
      videoManagerNoBlocklist.filterExistingVideos();
      
      // Video should still be there
      expect(videoManagerNoBlocklist.videos.length, equals(1));
      
      videoManagerNoBlocklist.dispose();
    });

    test('blocklist filtering works with specific npubs from ContentBlocklistService', () async {
      // Test with the actual hex pubkeys that should be blocked
      final blockedPubkey1 = 'e6e5a1c05b51c9a1bb8b90df48e4c5e56b2fd9195c7e8b5a3ed61b7e93d55f6d';
      final blockedPubkey2 = '2bfdb6eb6bd4debd24ad568fe9e8e835e76de1b5f73e7b6d5fc85fa373d0a029';
      
      when(mockBlocklistService.shouldFilterFromFeeds(blockedPubkey1)).thenReturn(true);
      when(mockBlocklistService.shouldFilterFromFeeds(blockedPubkey2)).thenReturn(true);
      
      // Create videos from blocked users
      final blockedVideo1 = VideoEvent(
        id: 'blocked1',
        pubkey: blockedPubkey1,
        videoUrl: 'https://example.com/blocked1.mp4',
        content: 'Blocked content 1',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        hashtags: [],
        rawTags: {},
      );
      
      final blockedVideo2 = VideoEvent(
        id: 'blocked2',
        pubkey: blockedPubkey2,
        videoUrl: 'https://example.com/blocked2.mp4',
        content: 'Blocked content 2',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        hashtags: [],
        rawTags: {},
      );
      
      // Try to add blocked videos
      await videoManager.addVideoEvent(blockedVideo1);
      await videoManager.addVideoEvent(blockedVideo2);
      
      // Verify both were filtered out
      expect(videoManager.videos.length, equals(0));
      verify(mockBlocklistService.shouldFilterFromFeeds(blockedPubkey1)).called(1);
      verify(mockBlocklistService.shouldFilterFromFeeds(blockedPubkey2)).called(1);
    });
  });
}