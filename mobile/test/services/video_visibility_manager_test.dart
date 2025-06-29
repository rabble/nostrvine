// ABOUTME: Comprehensive tests for VideoVisibilityManager
// ABOUTME: Ensures videos NEVER play when not visible across all scenarios

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_visibility_manager.dart';

void main() {
  group('VideoVisibilityManager', () {
    late VideoVisibilityManager manager;
    
    setUp(() {
      manager = VideoVisibilityManager();
    });
    
    tearDown(() {
      manager.dispose();
    });
    
    group('Visibility Threshold', () {
      test('should not allow play when visibility is 0%', () {
        manager.updateVideoVisibility('video1', 0.0);
        expect(manager.shouldVideoPlay('video1'), isFalse);
      });
      
      test('should not allow play when visibility is 49%', () {
        manager.updateVideoVisibility('video1', 0.49);
        expect(manager.shouldVideoPlay('video1'), isFalse);
      });
      
      test('should allow play when visibility is exactly 50%', () {
        manager.updateVideoVisibility('video1', 0.5);
        expect(manager.shouldVideoPlay('video1'), isTrue);
      });
      
      test('should allow play when visibility is 100%', () {
        manager.updateVideoVisibility('video1', 1.0);
        expect(manager.shouldVideoPlay('video1'), isTrue);
      });
    });
    
    group('Multiple Videos', () {
      test('should track multiple videos independently', () {
        manager.updateVideoVisibility('video1', 0.8);
        manager.updateVideoVisibility('video2', 0.3);
        manager.updateVideoVisibility('video3', 0.6);
        
        expect(manager.shouldVideoPlay('video1'), isTrue);
        expect(manager.shouldVideoPlay('video2'), isFalse);
        expect(manager.shouldVideoPlay('video3'), isTrue);
        
        expect(manager.playableVideos, containsAll(['video1', 'video3']));
        expect(manager.playableVideos, isNot(contains('video2')));
      });
      
      test('should update when visibility changes', () {
        manager.updateVideoVisibility('video1', 0.3);
        expect(manager.shouldVideoPlay('video1'), isFalse);
        
        manager.updateVideoVisibility('video1', 0.7);
        expect(manager.shouldVideoPlay('video1'), isTrue);
        
        manager.updateVideoVisibility('video1', 0.2);
        expect(manager.shouldVideoPlay('video1'), isFalse);
      });
    });
    
    group('Video Lifecycle', () {
      test('should remove video when disposed', () {
        manager.updateVideoVisibility('video1', 0.8);
        expect(manager.shouldVideoPlay('video1'), isTrue);
        
        manager.removeVideo('video1');
        expect(manager.shouldVideoPlay('video1'), isFalse);
        expect(manager.visibleVideos, isEmpty);
      });
      
      test('should handle removing non-existent video', () {
        expect(() => manager.removeVideo('nonexistent'), returnsNormally);
      });
    });
    
    group('Pause/Resume All', () {
      test('should pause all videos', () {
        manager.updateVideoVisibility('video1', 0.8);
        manager.updateVideoVisibility('video2', 0.9);
        manager.updateVideoVisibility('video3', 0.7);
        
        expect(manager.playableVideos.length, equals(3));
        
        manager.pauseAllVideos();
        
        expect(manager.playableVideos, isEmpty);
        expect(manager.shouldVideoPlay('video1'), isFalse);
        expect(manager.shouldVideoPlay('video2'), isFalse);
        expect(manager.shouldVideoPlay('video3'), isFalse);
      });
      
      test('should resume visibility-based playback', () {
        manager.updateVideoVisibility('video1', 0.8);
        manager.updateVideoVisibility('video2', 0.3);
        manager.updateVideoVisibility('video3', 0.6);
        
        manager.pauseAllVideos();
        expect(manager.playableVideos, isEmpty);
        
        manager.resumeVisibilityBasedPlayback();
        
        expect(manager.shouldVideoPlay('video1'), isTrue);
        expect(manager.shouldVideoPlay('video2'), isFalse);
        expect(manager.shouldVideoPlay('video3'), isTrue);
      });
    });
    
    group('Edge Cases', () {
      test('should handle rapid visibility changes', () {
        // Simulate scrolling past a video quickly
        for (double visibility = 0.0; visibility <= 1.0; visibility += 0.1) {
          manager.updateVideoVisibility('video1', visibility);
        }
        expect(manager.shouldVideoPlay('video1'), isTrue);
        
        for (double visibility = 1.0; visibility >= 0.0; visibility -= 0.1) {
          manager.updateVideoVisibility('video1', visibility);
        }
        expect(manager.shouldVideoPlay('video1'), isFalse);
      });
      
      test('should handle same visibility update', () {
        manager.updateVideoVisibility('video1', 0.8);
        
        // Update with same visibility
        manager.updateVideoVisibility('video1', 0.8);
        
        // Should still be playable
        expect(manager.shouldVideoPlay('video1'), isTrue);
      });
    });
    
    group('Visibility Info', () {
      test('should provide visibility info for videos', () {
        manager.updateVideoVisibility('video1', 0.75);
        
        final info = manager.getVisibilityInfo('video1');
        expect(info, isNotNull);
        expect(info!.videoId, equals('video1'));
        expect(info.visibilityFraction, equals(0.75));
        expect(info.isVisible, isTrue);
      });
      
      test('should return null for unknown videos', () {
        final info = manager.getVisibilityInfo('unknown');
        expect(info, isNull);
      });
    });
    
    group('Debug Info', () {
      test('should provide debug information', () {
        manager.updateVideoVisibility('video1', 0.8);
        manager.updateVideoVisibility('video2', 0.3);
        
        final debug = manager.debugInfo;
        expect(debug['totalTracked'], equals(2));
        expect(debug['visibleCount'], equals(2));
        expect(debug['playableCount'], equals(1));
        expect(debug['threshold'], equals('50%'));
        
        final videos = debug['videos'] as Map<String, dynamic>;
        expect(videos['video1']['playable'], isTrue);
        expect(videos['video2']['playable'], isFalse);
      });
    });
    
    group('Stream Updates', () {
      test('should emit visibility changes', () async {
        final updates = <VideoVisibilityInfo>[];
        final subscription = manager.visibilityStream.listen(updates.add);
        
        manager.updateVideoVisibility('video1', 0.2);
        manager.updateVideoVisibility('video1', 0.8);
        manager.updateVideoVisibility('video2', 0.6);
        
        // Allow stream to process
        await Future.delayed(Duration.zero);
        
        expect(updates.length, equals(3));
        expect(updates[0].visibilityFraction, equals(0.2));
        expect(updates[1].visibilityFraction, equals(0.8));
        expect(updates[2].videoId, equals('video2'));
        
        await subscription.cancel();
      });
    });
    
    group('Auto-Play Functionality', () {
      test('should not auto-play when auto-play is disabled', () {
        manager.updateVideoVisibility('video1', 0.8);
        expect(manager.shouldAutoPlay('video1'), isFalse);
        expect(manager.isAutoPlayEnabled, isFalse);
      });
      
      test('should enable auto-play when video is set as actively playing', () {
        manager.updateVideoVisibility('video1', 0.8);
        manager.setActivelyPlaying('video1');
        
        expect(manager.isAutoPlayEnabled, isTrue);
        expect(manager.activelyPlayingVideo, equals('video1'));
        expect(manager.shouldAutoPlay('video1'), isTrue);
      });
      
      test('should auto-play next visible video when scrolling', () {
        // Video 1 is playing
        manager.updateVideoVisibility('video1', 0.8);
        manager.setActivelyPlaying('video1');
        
        // Video 2 becomes visible - should auto-play
        manager.updateVideoVisibility('video2', 0.8);
        expect(manager.shouldAutoPlay('video2'), isTrue);
        expect(manager.activelyPlayingVideo, equals('video2'));
        
        // Video 1 goes out of view
        manager.updateVideoVisibility('video1', 0.2);
        expect(manager.shouldVideoPlay('video1'), isFalse);
        expect(manager.shouldAutoPlay('video1'), isFalse);
      });
      
      test('should disable auto-play when explicitly disabled', () {
        manager.updateVideoVisibility('video1', 0.8);
        manager.setActivelyPlaying('video1');
        expect(manager.isAutoPlayEnabled, isTrue);
        
        manager.disableAutoPlay();
        expect(manager.isAutoPlayEnabled, isFalse);
        expect(manager.activelyPlayingVideo, isNull);
        
        // New videos should not auto-play
        manager.updateVideoVisibility('video2', 0.8);
        expect(manager.shouldAutoPlay('video2'), isFalse);
      });
      
      test('should handle multiple videos with auto-play', () {
        // Enable auto-play with first video
        manager.updateVideoVisibility('video1', 0.8);
        manager.setActivelyPlaying('video1');
        
        // Multiple videos become visible
        manager.updateVideoVisibility('video2', 0.8);
        manager.updateVideoVisibility('video3', 0.8);
        
        // Only one should be designated for auto-play
        final autoPlayVideos = ['video1', 'video2', 'video3']
            .where((id) => manager.shouldAutoPlay(id))
            .toList();
        expect(autoPlayVideos.length, equals(1));
      });
      
      test('should transfer auto-play when active video becomes invisible', () {
        // Video 1 is actively playing
        manager.updateVideoVisibility('video1', 0.8);
        manager.setActivelyPlaying('video1');
        
        // Video 2 becomes visible
        manager.updateVideoVisibility('video2', 0.8);
        expect(manager.shouldAutoPlay('video2'), isTrue);
        
        // Video 1 goes out of view
        manager.updateVideoVisibility('video1', 0.2);
        
        // Video 2 should still auto-play
        expect(manager.shouldAutoPlay('video2'), isTrue);
        expect(manager.shouldAutoPlay('video1'), isFalse);
      });
      
      test('should include auto-play info in debug output', () {
        manager.updateVideoVisibility('video1', 0.8);
        manager.setActivelyPlaying('video1');
        manager.updateVideoVisibility('video2', 0.4); // Below threshold, won't auto-play
        
        final debug = manager.debugInfo;
        expect(debug['autoPlayEnabled'], isTrue);
        expect(debug['activelyPlaying'], equals('video1'));
        
        final videos = debug['videos'] as Map<String, dynamic>;
        expect(videos['video1']['shouldAutoPlay'], isTrue);
        expect(videos['video2']['shouldAutoPlay'], isFalse);
      });
    });
  });
}