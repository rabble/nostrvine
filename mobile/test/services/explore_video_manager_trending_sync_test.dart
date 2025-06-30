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
import 'explore_video_manager_trending_sync_test.mocks.dart';

void main() {
  late MockCurationService mockCurationService;
  late MockIVideoManager mockVideoManager;
  late ExploreVideoManager exploreVideoManager;

  setUp(() {
    mockCurationService = MockCurationService();
    mockVideoManager = MockIVideoManager();
    
    // Setup default mocks
    when(mockCurationService.isLoading).thenReturn(false);
    when(mockCurationService.error).thenReturn(null);
    when(mockCurationService.getVideosForSetType(any)).thenReturn([]);
    
    exploreVideoManager = ExploreVideoManager(
      curationService: mockCurationService,
      videoManager: mockVideoManager,
    );
  });

  tearDown(() {
    // Don't dispose immediately - let async operations complete first
  });

  group('ExploreVideoManager Trending Sync Tests', () {
    test('syncs trending videos directly from CurationService without VideoManager filtering', () async {
      // Create mock trending videos that would come from relay fetching
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

      // Mock CurationService to return trending videos (like after relay fetch)
      when(mockCurationService.getVideosForSetType(CurationSetType.trending))
          .thenReturn(trendingVideos);

      // Wait for initialization to complete first
      await Future.delayed(Duration(milliseconds: 100));
      
      // Now update the mock to return trending videos
      when(mockCurationService.getVideosForSetType(CurationSetType.trending))
          .thenReturn(trendingVideos);
      
      // Trigger sync by calling refreshCollections
      await exploreVideoManager.refreshCollections();

      // ExploreVideoManager should now return the same videos directly from CurationService
      final result = exploreVideoManager.getVideosForType(CurationSetType.trending);

      expect(result.length, equals(2));
      expect(result[0].id, equals('trending1'));
      expect(result[1].id, equals('trending2'));
      expect(result[0].title, equals('Trending Video 1'));
      expect(result[1].title, equals('Trending Video 2'));

      // Verify CurationService was called
      verify(mockCurationService.getVideosForSetType(CurationSetType.trending)).called(greaterThan(0));
    });

    test('reflects CurationService changes when listener is triggered', () async {
      // Initially no videos
      when(mockCurationService.getVideosForSetType(CurationSetType.trending))
          .thenReturn([]);

      // Initialize and verify empty
      await exploreVideoManager.refreshCollections();
      expect(exploreVideoManager.getVideosForType(CurationSetType.trending), isEmpty);

      // Now simulate CurationService gets trending videos (e.g., from analytics API + relay fetch)
      final newTrendingVideos = [
        VideoEvent(
          id: 'new_trending',
          pubkey: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
          createdAt: 1234567892,
          content: 'New trending video',
          timestamp: DateTime.now(),
          title: 'New Trending Video',
          videoUrl: 'https://example.com/new_video.mp4',
        ),
      ];

      when(mockCurationService.getVideosForSetType(CurationSetType.trending))
          .thenReturn(newTrendingVideos);

      // Simulate CurationService notifying listeners (which would happen after relay fetch)
      // Since we can't easily trigger the private _onCurationChanged method,
      // we'll call refreshCollections which does the same sync
      await exploreVideoManager.refreshCollections();

      // ExploreVideoManager should now reflect the new videos
      final result = exploreVideoManager.getVideosForType(CurationSetType.trending);
      expect(result.length, equals(1));
      expect(result[0].id, equals('new_trending'));
      expect(result[0].title, equals('New Trending Video'));
    });

    test('handles empty trending videos gracefully', () async {
      // Mock empty trending videos
      when(mockCurationService.getVideosForSetType(CurationSetType.trending))
          .thenReturn([]);

      await exploreVideoManager.refreshCollections();

      final result = exploreVideoManager.getVideosForType(CurationSetType.trending);
      expect(result, isEmpty);
    });

    test('works for all curation types, not just trending', () async {
      final editorsPicks = [
        VideoEvent(
          id: 'editors1',
          pubkey: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
          createdAt: 1234567890,
          content: 'Editors pick video',
          timestamp: DateTime.now(),
          title: 'Editors Pick',
          videoUrl: 'https://example.com/editors.mp4',
        ),
      ];

      when(mockCurationService.getVideosForSetType(CurationSetType.editorsPicks))
          .thenReturn(editorsPicks);
      when(mockCurationService.getVideosForSetType(CurationSetType.trending))
          .thenReturn([]);

      await exploreVideoManager.refreshCollections();

      final editorsResult = exploreVideoManager.getVideosForType(CurationSetType.editorsPicks);
      final trendingResult = exploreVideoManager.getVideosForType(CurationSetType.trending);

      expect(editorsResult.length, equals(1));
      expect(editorsResult[0].id, equals('editors1'));
      expect(trendingResult, isEmpty);
    });
  });
}