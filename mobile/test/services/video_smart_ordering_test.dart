import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_manager_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_manager_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Video Smart Ordering', () {
    late VideoManagerService videoManager;
    late SeenVideosService seenVideosService;

    setUp(() async {
      seenVideosService = SeenVideosService();
      await seenVideosService.initialize();
      videoManager = VideoManagerService(
        config: VideoManagerConfig.testing(),
        seenVideosService: seenVideosService,
      );
    });

    tearDown(() {
      videoManager.dispose();
    });

    test('should prioritize unseen videos over seen videos', () async {
      // Create test videos
      final unseenVideo = VideoEvent(
        id: 'unseen_video_12345678',
        pubkey: 'test_pubkey_12345678',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        timestamp: DateTime.now(),
        content: 'Test unseen video',
        videoUrl: 'https://example.com/unseen.mp4',
      );

      final seenVideo = VideoEvent(
        id: 'seen_video_87654321', 
        pubkey: 'test_pubkey_87654321',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        timestamp: DateTime.now(),
        content: 'Test seen video',
        videoUrl: 'https://example.com/seen.mp4',
      );

      // Mark one video as seen
      seenVideosService.markVideoAsSeen(seenVideo.id);

      // Add seen video first
      await videoManager.addVideoEvent(seenVideo);
      
      // Add unseen video second
      await videoManager.addVideoEvent(unseenVideo);

      // Verify unseen video is at the beginning (higher priority)
      final videos = videoManager.videos;
      expect(videos.length, equals(2));
      expect(videos.first.id, equals('unseen_video_12345678'));
      expect(videos.last.id, equals('seen_video_87654321'));
    });

    test('should maintain order for multiple unseen videos', () async {
      final video1 = VideoEvent(
        id: 'unseen_video_111111',
        pubkey: 'test_pubkey_111111',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        timestamp: DateTime.now(),
        content: 'First unseen',
        videoUrl: 'https://example.com/1.mp4',
      );

      final video2 = VideoEvent(
        id: 'unseen_video_222222',
        pubkey: 'test_pubkey_222222', 
        createdAt: DateTime.now().millisecondsSinceEpoch,
        timestamp: DateTime.now(),
        content: 'Second unseen',
        videoUrl: 'https://example.com/2.mp4',
      );

      // Add videos in order
      await videoManager.addVideoEvent(video1);
      await videoManager.addVideoEvent(video2);

      // Both are unseen, so second should be first (newest-first within unseen)
      final videos = videoManager.videos;
      expect(videos.length, equals(2));
      expect(videos[0].id, equals('unseen_video_222222'));
      expect(videos[1].id, equals('unseen_video_111111'));
    });

    test('should handle mixed seen and unseen videos correctly', () async {
      // Create test videos with proper IDs (8+ chars)
      final video1 = VideoEvent(
        id: 'unseen_video_111',
        pubkey: 'test_pubkey_111',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        timestamp: DateTime.now(),
        content: 'Test video 1',
        videoUrl: 'https://example.com/1.mp4',
      );
      
      final video2 = VideoEvent(
        id: 'seen_video_2222',
        pubkey: 'test_pubkey_222',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        timestamp: DateTime.now(),
        content: 'Test video 2',
        videoUrl: 'https://example.com/2.mp4',
      );

      // Mark video 2 as seen
      await seenVideosService.markVideoAsSeen('seen_video_2222');

      // Add seen video first, then unseen video
      await videoManager.addVideoEvent(video2);
      await videoManager.addVideoEvent(video1);

      // Expected order: unseen video first, then seen video
      final resultVideos = videoManager.videos;
      expect(resultVideos.length, equals(2));
      
      // First should be unseen video
      expect(resultVideos[0].id, equals('unseen_video_111'));
      
      // Second should be seen video
      expect(resultVideos[1].id, equals('seen_video_2222'));
    });
  });
}