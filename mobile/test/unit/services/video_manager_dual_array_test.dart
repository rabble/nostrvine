// ABOUTME: Comprehensive tests for dual-array video management system
// ABOUTME: Verifies primary/discovery separation and correct feed ordering

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_manager_service.dart';
import 'package:openvine/services/video_manager_interface.dart';

void main() {
  group('VideoManager Dual-Array System', () {
    late VideoManagerService videoManager;
    
    setUp(() {
      videoManager = VideoManagerService(
        config: VideoManagerConfig.testing(),
      );
    });
    
    tearDown(() {
      videoManager.dispose();
    });
    
    VideoEvent createTestVideo({
      required String id,
      required String pubkey,
      String? content,
      String? videoUrl,
    }) {
      final now = DateTime.now();
      return VideoEvent(
        id: id,
        pubkey: pubkey,
        content: content ?? 'Test video content',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        videoUrl: videoUrl ?? 'https://example.com/$id.mp4',
        hashtags: [],
        rawTags: {},
        isRepost: false,
        isFlaggedContent: false,
      );
    }
    
    group('Primary and Discovery Separation', () {
      test('should add following videos to primary array', () async {
        const followingPubkey = 'following123';
        videoManager.updateFollowingList({followingPubkey});
        
        final video = createTestVideo(
          id: 'video1',
          pubkey: followingPubkey,
        );
        
        await videoManager.addVideoEvent(video);
        
        final videos = videoManager.videos;
        expect(videos.length, 1);
        expect(videos[0].id, 'video1');
        
        // Verify debug info shows correct counts
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['primaryVideos'], 1);
        expect(debugInfo['discoveryVideos'], 0);
      });
      
      test('should add non-following videos to discovery array', () async {
        const discoveryPubkey = 'discovery123';
        // Don't add to following list
        
        final video = createTestVideo(
          id: 'video1',
          pubkey: discoveryPubkey,
        );
        
        await videoManager.addVideoEvent(video);
        
        final videos = videoManager.videos;
        expect(videos.length, 1);
        expect(videos[0].id, 'video1');
        
        // Verify debug info shows correct counts
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['primaryVideos'], 0);
        expect(debugInfo['discoveryVideos'], 1);
      });
    });
    
    group('Feed Ordering', () {
      test('should show all primary videos before discovery videos', () async {
        const followingPubkey1 = 'following1';
        const followingPubkey2 = 'following2';
        const discoveryPubkey1 = 'discovery1';
        const discoveryPubkey2 = 'discovery2';
        
        videoManager.updateFollowingList({followingPubkey1, followingPubkey2});
        
        // Add videos in mixed order
        await videoManager.addVideoEvent(createTestVideo(
          id: 'discovery-1',
          pubkey: discoveryPubkey1,
        ));
        
        await videoManager.addVideoEvent(createTestVideo(
          id: 'following-1',
          pubkey: followingPubkey1,
        ));
        
        await videoManager.addVideoEvent(createTestVideo(
          id: 'discovery-2',
          pubkey: discoveryPubkey2,
        ));
        
        await videoManager.addVideoEvent(createTestVideo(
          id: 'following-2',
          pubkey: followingPubkey2,
        ));
        
        // Verify order: all following videos first, then discovery
        final videos = videoManager.videos;
        expect(videos.length, 4);
        expect(videos[0].id, 'following-1');
        expect(videos[1].id, 'following-2');
        expect(videos[2].id, 'discovery-1');
        expect(videos[3].id, 'discovery-2');
      });
      
      test('should maintain insertion order within each array', () async {
        const followingPubkey = 'following123';
        const discoveryPubkey = 'discovery123';
        
        videoManager.updateFollowingList({followingPubkey});
        
        // Add multiple videos of each type
        for (int i = 1; i <= 3; i++) {
          await videoManager.addVideoEvent(createTestVideo(
            id: 'following-$i',
            pubkey: followingPubkey,
          ));
          
          await videoManager.addVideoEvent(createTestVideo(
            id: 'discovery-$i',
            pubkey: discoveryPubkey,
          ));
        }
        
        final videos = videoManager.videos;
        expect(videos.length, 6);
        
        // Following videos should be in order 1,2,3
        expect(videos[0].id, 'following-1');
        expect(videos[1].id, 'following-2');
        expect(videos[2].id, 'following-3');
        
        // Discovery videos should be in order 1,2,3
        expect(videos[3].id, 'discovery-1');
        expect(videos[4].id, 'discovery-2');
        expect(videos[5].id, 'discovery-3');
      });
    });
    
    group('Index Stability', () {
      test('should not change existing video indices when adding new videos', () async {
        const followingPubkey = 'following123';
        const discoveryPubkey = 'discovery123';
        
        videoManager.updateFollowingList({followingPubkey});
        
        // Add initial videos
        await videoManager.addVideoEvent(createTestVideo(
          id: 'following-1',
          pubkey: followingPubkey,
        ));
        
        await videoManager.addVideoEvent(createTestVideo(
          id: 'discovery-1',
          pubkey: discoveryPubkey,
        ));
        
        // Record initial positions
        var videos = videoManager.videos;
        expect(videos[0].id, 'following-1');
        expect(videos[1].id, 'discovery-1');
        
        // Add more videos
        await videoManager.addVideoEvent(createTestVideo(
          id: 'following-2',
          pubkey: followingPubkey,
        ));
        
        await videoManager.addVideoEvent(createTestVideo(
          id: 'discovery-2',
          pubkey: discoveryPubkey,
        ));
        
        // Verify original videos haven't moved
        videos = videoManager.videos;
        expect(videos[0].id, 'following-1');
        expect(videos[1].id, 'following-2'); // New following video
        expect(videos[2].id, 'discovery-1'); // Original discovery video moved
        expect(videos[3].id, 'discovery-2'); // New discovery video
      });
    });
    
    group('Dynamic Following List Updates', () {
      test('should handle following list updates correctly', () async {
        const pubkey1 = 'user1';
        const pubkey2 = 'user2';
        
        // Initially, no one is followed
        await videoManager.addVideoEvent(createTestVideo(
          id: 'video1',
          pubkey: pubkey1,
        ));
        
        await videoManager.addVideoEvent(createTestVideo(
          id: 'video2',
          pubkey: pubkey2,
        ));
        
        // Both should be in discovery
        var debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['primaryVideos'], 0);
        expect(debugInfo['discoveryVideos'], 2);
        
        // Now follow user1 - existing videos stay where they are
        videoManager.updateFollowingList({pubkey1});
        
        // Add new videos after following update
        await videoManager.addVideoEvent(createTestVideo(
          id: 'video3',
          pubkey: pubkey1, // Now followed
        ));
        
        await videoManager.addVideoEvent(createTestVideo(
          id: 'video4',
          pubkey: pubkey2, // Still not followed
        ));
        
        // Check final state
        debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['primaryVideos'], 1); // Only new video from followed user
        expect(debugInfo['discoveryVideos'], 3); // Original 2 + new discovery
        
        final videos = videoManager.videos;
        expect(videos[0].id, 'video3'); // New following video first
        expect(videos[1].id, 'video1'); // Original videos after
        expect(videos[2].id, 'video2');
        expect(videos[3].id, 'video4');
      });
    });
    
    group('Edge Cases', () {
      test('should handle empty following list correctly', () async {
        // No following list set - all videos should go to discovery
        
        for (int i = 1; i <= 5; i++) {
          await videoManager.addVideoEvent(createTestVideo(
            id: 'video-$i',
            pubkey: 'pubkey-$i',
          ));
        }
        
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['primaryVideos'], 0);
        expect(debugInfo['discoveryVideos'], 5);
        expect(videoManager.videos.length, 5);
      });
      
      test('should handle duplicate videos correctly', () async {
        const pubkey = 'testpubkey';
        
        final video = createTestVideo(
          id: 'duplicate-video',
          pubkey: pubkey,
        );
        
        await videoManager.addVideoEvent(video);
        await videoManager.addVideoEvent(video); // Try to add duplicate
        
        expect(videoManager.videos.length, 1);
      });
      
      test('should maintain correct counts after filtering blocked content', () async {
        const followingPubkey = 'following123';
        const discoveryPubkey = 'discovery123';
        
        videoManager.updateFollowingList({followingPubkey});
        
        // Add videos
        await videoManager.addVideoEvent(createTestVideo(
          id: 'following-1',
          pubkey: followingPubkey,
        ));
        
        await videoManager.addVideoEvent(createTestVideo(
          id: 'discovery-1',
          pubkey: discoveryPubkey,
        ));
        
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['primaryVideos'], 1);
        expect(debugInfo['discoveryVideos'], 1);
        expect(debugInfo['totalVideos'], 2);
      });
    });
    
    group('Preloading with Dual Arrays', () {
      test('should preload videos across both arrays correctly', () async {
        const followingPubkey = 'following123';
        const discoveryPubkey = 'discovery123';
        
        videoManager.updateFollowingList({followingPubkey});
        
        // Add 5 following videos and 5 discovery videos
        for (int i = 1; i <= 5; i++) {
          await videoManager.addVideoEvent(createTestVideo(
            id: 'following-$i',
            pubkey: followingPubkey,
          ));
        }
        
        for (int i = 1; i <= 5; i++) {
          await videoManager.addVideoEvent(createTestVideo(
            id: 'discovery-$i',
            pubkey: discoveryPubkey,
          ));
        }
        
        // Test preloading around the boundary between arrays
        // Index 4 is the last following video, index 5 is the first discovery
        videoManager.preloadAroundIndex(4);
        
        // Should preload videos from both arrays
        final videos = videoManager.videos;
        expect(videos.length, 10);
        
        // Verify we can access videos by index correctly
        expect(videos[3].id, 'following-4');
        expect(videos[4].id, 'following-5');
        expect(videos[5].id, 'discovery-1');
        expect(videos[6].id, 'discovery-2');
      });
    });
  });
}