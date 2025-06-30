import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/services/explore_video_manager.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:openvine/services/video_manager_interface.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/models/curation_set.dart';

@GenerateMocks([
  CurationService,
  IVideoManager,
])
import 'explore_video_manager_fix_verification_test.mocks.dart';

void main() {
  group('ExploreVideoManager Fix Verification', () {
    test('correctly passes through videos from CurationService without VideoManager filtering', () async {
      final mockCurationService = MockCurationService();
      final mockVideoManager = MockIVideoManager();
      
      // Create test videos that would come from CurationService after relay fetch
      final trendingVideos = [
        VideoEvent(
          id: 'trending1',
          pubkey: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
          createdAt: 1234567890,
          content: 'Trending video 1',
          timestamp: DateTime.now(),
          title: 'Trending Video 1',
          videoUrl: 'https://example.com/video1.mp4',
        ),
        VideoEvent(
          id: 'trending2',
          pubkey: 'fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321',
          createdAt: 1234567891,
          content: 'Trending video 2',
          timestamp: DateTime.now(),
          title: 'Trending Video 2',
          videoUrl: 'https://example.com/video2.mp4',
        ),
      ];

      // Setup mocks - CurationService has trending videos
      when(mockCurationService.isLoading).thenReturn(false);
      when(mockCurationService.error).thenReturn(null);
      when(mockCurationService.getVideosForSetType(CurationSetType.trending))
          .thenReturn(trendingVideos);
      when(mockCurationService.getVideosForSetType(CurationSetType.editorsPicks))
          .thenReturn([]);

      // Create ExploreVideoManager with prepared mocks
      final exploreVideoManager = ExploreVideoManager(
        curationService: mockCurationService,
        videoManager: mockVideoManager,
      );

      // Wait for initialization
      await Future.delayed(Duration(milliseconds: 50));

      // Test the FIX: ExploreVideoManager should return videos directly from CurationService
      // without filtering through VideoManager (which used to cause the empty screen bug)
      final result = exploreVideoManager.getVideosForType(CurationSetType.trending);

      // This should work now with the fix at line 81 in explore_video_manager.dart:
      // _availableCollections[type] = curatedVideos;
      expect(result.length, equals(2), reason: 'Should return all videos from CurationService');
      expect(result[0].id, equals('trending1'));
      expect(result[1].id, equals('trending2'));
      expect(result[0].title, equals('Trending Video 1'));
      expect(result[1].title, equals('Trending Video 2'));

      // Verify CurationService was called (the source of truth)
      verify(mockCurationService.getVideosForSetType(CurationSetType.trending)).called(greaterThan(0));

      exploreVideoManager.dispose();
    });

    test('empty case works correctly', () async {
      final mockCurationService = MockCurationService();
      final mockVideoManager = MockIVideoManager();

      // Setup mocks - no videos
      when(mockCurationService.isLoading).thenReturn(false);
      when(mockCurationService.error).thenReturn(null);
      when(mockCurationService.getVideosForSetType(any)).thenReturn([]);

      final exploreVideoManager = ExploreVideoManager(
        curationService: mockCurationService,
        videoManager: mockVideoManager,
      );

      await Future.delayed(Duration(milliseconds: 50));

      final result = exploreVideoManager.getVideosForType(CurationSetType.trending);
      expect(result, isEmpty);

      exploreVideoManager.dispose();
    });
  });
}