// ABOUTME: End-to-end test simulating real video arrival scenarios
// ABOUTME: Tests that following videos stay at top regardless of arrival timing

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_manager_service.dart';

void main() {
  group('Mixed Video Arrival Scenarios', () {
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
    
    test('worst case: discovery videos arrive first, following arrive later', () async {
      const followingPubkey = 'user_i_follow';
      const discoveryPubkey1 = 'random_user_1';
      const discoveryPubkey2 = 'random_user_2';
      
      // Set up following list
      videoManager.updateFollowingList({followingPubkey});
      
      // Simulate worst case: discovery content floods in first
      await videoManager.addVideoEvent(createTestVideo(id: 'd1', pubkey: discoveryPubkey1));
      await videoManager.addVideoEvent(createTestVideo(id: 'd2', pubkey: discoveryPubkey2));
      await videoManager.addVideoEvent(createTestVideo(id: 'd3', pubkey: discoveryPubkey1));
      await videoManager.addVideoEvent(createTestVideo(id: 'd4', pubkey: discoveryPubkey2));
      await videoManager.addVideoEvent(createTestVideo(id: 'd5', pubkey: discoveryPubkey1));
      
      // Following videos arrive later
      await videoManager.addVideoEvent(createTestVideo(id: 'f1', pubkey: followingPubkey));
      await videoManager.addVideoEvent(createTestVideo(id: 'f2', pubkey: followingPubkey));
      
      // Following videos should still be at the front
      final videos = videoManager.videos;
      expect(videos.length, 7);
      expect(videos[0].id, 'f1');
      expect(videos[1].id, 'f2');
      
      // All discovery videos should be after following videos
      for (int i = 2; i < videos.length; i++) {
        expect(videos[i].pubkey, isNot(followingPubkey));
      }
    });
    
    test('interleaved arrival: following and discovery mixed together', () async {
      const followingPubkey1 = 'follow1';
      const followingPubkey2 = 'follow2';
      const discoveryPubkey = 'discovery';
      
      videoManager.updateFollowingList({followingPubkey1, followingPubkey2});
      
      // Simulate realistic interleaved arrival
      await videoManager.addVideoEvent(createTestVideo(id: 'd1', pubkey: discoveryPubkey));
      await videoManager.addVideoEvent(createTestVideo(id: 'f1', pubkey: followingPubkey1));
      await videoManager.addVideoEvent(createTestVideo(id: 'd2', pubkey: discoveryPubkey));
      await videoManager.addVideoEvent(createTestVideo(id: 'f2', pubkey: followingPubkey2));
      await videoManager.addVideoEvent(createTestVideo(id: 'd3', pubkey: discoveryPubkey));
      await videoManager.addVideoEvent(createTestVideo(id: 'f3', pubkey: followingPubkey1));
      await videoManager.addVideoEvent(createTestVideo(id: 'd4', pubkey: discoveryPubkey));
      
      final videos = videoManager.videos;
      expect(videos.length, 7);
      
      // First 3 should be following videos in order
      expect(videos[0].id, 'f1');
      expect(videos[1].id, 'f2'); 
      expect(videos[2].id, 'f3');
      
      // Last 4 should be discovery videos in order
      expect(videos[3].id, 'd1');
      expect(videos[4].id, 'd2');
      expect(videos[5].id, 'd3');
      expect(videos[6].id, 'd4');
    });
    
    test('following videos maintain chronological order within their section', () async {
      const followingPubkey = 'following123';
      videoManager.updateFollowingList({followingPubkey});
      
      // Add following videos at different times
      await videoManager.addVideoEvent(createTestVideo(id: 'f1', pubkey: followingPubkey, content: 'First following'));
      await Future.delayed(const Duration(milliseconds: 1));
      
      await videoManager.addVideoEvent(createTestVideo(id: 'f2', pubkey: followingPubkey, content: 'Second following'));
      await Future.delayed(const Duration(milliseconds: 1));
      
      await videoManager.addVideoEvent(createTestVideo(id: 'f3', pubkey: followingPubkey, content: 'Third following'));
      
      final videos = videoManager.videos;
      expect(videos.length, 3);
      expect(videos[0].id, 'f1');
      expect(videos[1].id, 'f2');
      expect(videos[2].id, 'f3');
    });
    
    test('discovery videos maintain chronological order within their section', () async {
      const followingPubkey = 'following123';
      const discoveryPubkey = 'discovery456';
      
      videoManager.updateFollowingList({followingPubkey});
      
      // Add one following video first
      await videoManager.addVideoEvent(createTestVideo(id: 'f1', pubkey: followingPubkey));
      
      // Add discovery videos in order
      await videoManager.addVideoEvent(createTestVideo(id: 'd1', pubkey: discoveryPubkey, content: 'First discovery'));
      await Future.delayed(const Duration(milliseconds: 1));
      
      await videoManager.addVideoEvent(createTestVideo(id: 'd2', pubkey: discoveryPubkey, content: 'Second discovery'));
      await Future.delayed(const Duration(milliseconds: 1));
      
      await videoManager.addVideoEvent(createTestVideo(id: 'd3', pubkey: discoveryPubkey, content: 'Third discovery'));
      
      final videos = videoManager.videos;
      expect(videos.length, 4);
      
      // Following video at front
      expect(videos[0].id, 'f1');
      
      // Discovery videos in order at back
      expect(videos[1].id, 'd1');
      expect(videos[2].id, 'd2');
      expect(videos[3].id, 'd3');
    });
    
    test('empty following list: all videos go to discovery section', () async {
      // No following list set (empty set)
      videoManager.updateFollowingList({});
      
      const pubkey1 = 'user1';
      const pubkey2 = 'user2';
      
      await videoManager.addVideoEvent(createTestVideo(id: 'v1', pubkey: pubkey1));
      await videoManager.addVideoEvent(createTestVideo(id: 'v2', pubkey: pubkey2));
      await videoManager.addVideoEvent(createTestVideo(id: 'v3', pubkey: pubkey1));
      
      final videos = videoManager.videos;
      expect(videos.length, 3);
      
      // All should be in order (no prioritization)
      expect(videos[0].id, 'v1');
      expect(videos[1].id, 'v2');
      expect(videos[2].id, 'v3');
    });
    
    test('large scale scenario: 100 videos mixed arrival', () async {
      const followingPubkey = 'following123';
      videoManager.updateFollowingList({followingPubkey});
      
      // Add videos in completely random order
      final allVideos = <VideoEvent>[];
      
      // Create 30 following videos
      for (int i = 1; i <= 30; i++) {
        allVideos.add(createTestVideo(id: 'f$i', pubkey: followingPubkey));
      }
      
      // Create 70 discovery videos
      for (int i = 1; i <= 70; i++) {
        allVideos.add(createTestVideo(id: 'd$i', pubkey: 'discovery$i'));
      }
      
      // Shuffle them to simulate random arrival
      allVideos.shuffle();
      
      // Add them all
      for (final video in allVideos) {
        await videoManager.addVideoEvent(video);
      }
      
      final finalVideos = videoManager.videos;
      expect(finalVideos.length, 100);
      
      // First 30 should be following videos
      for (int i = 0; i < 30; i++) {
        expect(finalVideos[i].pubkey, followingPubkey);
        expect(finalVideos[i].id, startsWith('f'));
      }
      
      // Last 70 should be discovery videos
      for (int i = 30; i < 100; i++) {
        expect(finalVideos[i].pubkey, isNot(followingPubkey));
        expect(finalVideos[i].id, startsWith('d'));
      }
    });
  });
}