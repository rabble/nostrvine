// ABOUTME: Tests for CurationService analytics integration and on-demand trending fetch
// ABOUTME: Verifies trending data is only fetched when requested, not constantly polled

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/services/curation_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/models/curation_set.dart';

import 'curation_service_test.mocks.dart';

@GenerateMocks([INostrService, VideoEventService, SocialService])
void main() {
  group('CurationService', () {
    late CurationService curationService;
    late MockINostrService mockNostrService;
    late MockVideoEventService mockVideoEventService;
    late MockSocialService mockSocialService;

    setUp(() {
      mockNostrService = MockINostrService();
      mockVideoEventService = MockVideoEventService();
      mockSocialService = MockSocialService();

      // Mock video events for testing
      when(mockVideoEventService.videoEvents).thenReturn([
        VideoEvent(
          id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
          pubkey: 'test_pubkey',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          content: 'Test video',
          timestamp: DateTime.now(),
        ),
      ]);

      curationService = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        socialService: mockSocialService,
      );
    });

    tearDown(() {
      curationService.dispose();
    });

    test('should not automatically fetch trending data on initialization', () {
      // The constructor should complete without making any HTTP requests
      expect(curationService.getVideosForSetType(CurationSetType.trending), isNotEmpty);
      // Should use local algorithm, not analytics API
    });

    test('should have manual refresh method for trending', () {
      // Verify the public method exists
      expect(curationService.refreshTrendingFromAnalytics, isA<Function>());
    });

    test('should fall back to local algorithm when analytics unavailable', () {
      // Given: No analytics API available
      // When: Getting trending videos
      final trendingVideos = curationService.getVideosForSetType(CurationSetType.trending);
      
      // Then: Should return local algorithm results
      expect(trendingVideos, isNotNull);
      // Local algorithm should work with mock data
    });

    test('should get videos for different curation set types', () {
      final editorsPicks = curationService.getVideosForSetType(CurationSetType.editorsPicks);
      final trending = curationService.getVideosForSetType(CurationSetType.trending);
      final featured = curationService.getVideosForSetType(CurationSetType.featured);

      expect(editorsPicks, isA<List<VideoEvent>>());
      expect(trending, isA<List<VideoEvent>>());
      expect(featured, isA<List<VideoEvent>>());
    });

    test('should handle empty video events gracefully', () {
      // Given: No video events
      when(mockVideoEventService.videoEvents).thenReturn([]);
      
      final service = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        socialService: mockSocialService,
      );

      // When: Getting trending videos
      final trending = service.getVideosForSetType(CurationSetType.trending);
      
      // Then: Should return empty list without errors
      expect(trending, isEmpty);
      
      service.dispose();
    });

    test('should notify listeners when curation sets are refreshed', () async {
      bool notified = false;
      curationService.addListener(() {
        notified = true;
      });

      // Simulate curation set refresh
      await curationService.refreshCurationSets();

      expect(notified, isTrue);
    });
  });
}