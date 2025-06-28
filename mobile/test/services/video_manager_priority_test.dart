// ABOUTME: Unit tests for VideoManager priority insertion logic
// ABOUTME: Tests following vs discovery feed ordering behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_manager_service.dart';

void main() {
  group('VideoManager Priority Insertion', () {
    late VideoManagerService videoManager;
    
    setUp(() {
      videoManager = VideoManagerService();
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
    
    test('should insert following videos at front', () async {
      // Set up following list
      const followingPubkey = 'following123';
      const discoveryPubkey = 'discovery456';
      videoManager.updateFollowingList({followingPubkey});
      
      // Add discovery video first
      final discoveryVideo = createTestVideo(
        id: 'discovery1',
        pubkey: discoveryPubkey,
        content: 'Discovery video',
      );
      await videoManager.addVideoEvent(discoveryVideo);
      
      // Add following video second - should go to front
      final followingVideo = createTestVideo(
        id: 'following1', 
        pubkey: followingPubkey,
        content: 'Following video',
      );
      await videoManager.addVideoEvent(followingVideo);
      
      // Following video should be at index 0, discovery at index 1
      final videos = videoManager.videos;
      expect(videos.length, 2);
      expect(videos[0].id, 'following1');
      expect(videos[1].id, 'discovery1');
    });
    
    test('should keep multiple following videos grouped at front', () async {
      const followingPubkey1 = 'following123';
      const followingPubkey2 = 'following456';
      const discoveryPubkey = 'discovery789';
      
      videoManager.updateFollowingList({followingPubkey1, followingPubkey2});
      
      // Add videos in mixed order
      final videos = [
        createTestVideo(id: 'discovery1', pubkey: discoveryPubkey, content: 'Discovery 1'),
        createTestVideo(id: 'following1', pubkey: followingPubkey1, content: 'Following 1'),
        createTestVideo(id: 'discovery2', pubkey: discoveryPubkey, content: 'Discovery 2'),
        createTestVideo(id: 'following2', pubkey: followingPubkey2, content: 'Following 2'),
        createTestVideo(id: 'following3', pubkey: followingPubkey1, content: 'Following 3'),
      ];
      
      for (final video in videos) {
        await videoManager.addVideoEvent(video);
      }
      
      final finalVideos = videoManager.videos;
      expect(finalVideos.length, 5);
      
      // Following videos should be at front
      expect(finalVideos[0].id, 'following1');
      expect(finalVideos[1].id, 'following2'); 
      expect(finalVideos[2].id, 'following3');
      
      // Discovery videos should be at back
      expect(finalVideos[3].id, 'discovery1');
      expect(finalVideos[4].id, 'discovery2');
    });
    
    test('should handle empty following list gracefully', () async {
      // No following list set
      final discoveryVideo = createTestVideo(
        id: 'discovery1',
        pubkey: 'anyone',
        content: 'Discovery video',
      );
      
      await videoManager.addVideoEvent(discoveryVideo);
      
      final videos = videoManager.videos;
      expect(videos.length, 1);
      expect(videos[0].id, 'discovery1');
    });
    
    test('should maintain insertion order within following section', () async {
      const followingPubkey = 'following123';
      videoManager.updateFollowingList({followingPubkey});
      
      // Add multiple following videos
      final video1 = createTestVideo(id: 'f1', pubkey: followingPubkey, content: 'First');
      final video2 = createTestVideo(id: 'f2', pubkey: followingPubkey, content: 'Second');
      final video3 = createTestVideo(id: 'f3', pubkey: followingPubkey, content: 'Third');
      
      await videoManager.addVideoEvent(video1);
      await videoManager.addVideoEvent(video2);
      await videoManager.addVideoEvent(video3);
      
      final videos = videoManager.videos;
      expect(videos.length, 3);
      expect(videos[0].id, 'f1');
      expect(videos[1].id, 'f2');
      expect(videos[2].id, 'f3');
    });
    
    test('should not duplicate videos', () async {
      const followingPubkey = 'following123';
      videoManager.updateFollowingList({followingPubkey});
      
      final video = createTestVideo(
        id: 'duplicate',
        pubkey: followingPubkey,
        content: 'Test video',
      );
      
      // Add same video twice
      await videoManager.addVideoEvent(video);
      await videoManager.addVideoEvent(video);
      
      final videos = videoManager.videos;
      expect(videos.length, 1);
      expect(videos[0].id, 'duplicate');
    });
  });
}