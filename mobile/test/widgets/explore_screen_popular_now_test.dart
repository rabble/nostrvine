import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/services/explore_video_manager.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/models/curation_set.dart';

@GenerateMocks([
  ExploreVideoManager,
  CurationService,
  HashtagService,
  VideoEventService,
])
import 'explore_screen_popular_now_test.mocks.dart';

void main() {
  late MockExploreVideoManager mockExploreVideoManager;
  late MockCurationService mockCurationService;
  late MockHashtagService mockHashtagService;
  late MockVideoEventService mockVideoEventService;

  setUp(() {
    mockExploreVideoManager = MockExploreVideoManager();
    mockCurationService = MockCurationService();
    mockHashtagService = MockHashtagService();
    mockVideoEventService = MockVideoEventService();

    // Setup default mocks
    when(mockExploreVideoManager.isLoading).thenReturn(false);
    when(mockCurationService.isLoading).thenReturn(false);
    when(mockHashtagService.getTrendingHashtags(limit: anyNamed('limit'))).thenReturn([]);
    when(mockHashtagService.getEditorsPicks(limit: anyNamed('limit'))).thenReturn([]);
    when(mockVideoEventService.getRecentVideoEvents(hours: anyNamed('hours'))).thenReturn([]);
    
    // Setup default empty video responses for all curation types
    when(mockExploreVideoManager.getVideosForType(any)).thenReturn([]);
    when(mockCurationService.getVideosForSetType(any)).thenReturn([]);
  });

  group('Popular Now Tab Tests', () {
    testWidgets('shows empty state when ExploreVideoManager has no videos despite CurationService having videos', (WidgetTester tester) async {
      // This test demonstrates the bug: CurationService has videos but ExploreVideoManager doesn't
      
      // Mock CurationService to have trending videos (like the real scenario)
      final mockTrendingVideos = [
        VideoEvent(
          id: 'trending1',
          pubkey: 'pubkey1',
          createdAt: 1234567890,
          content: 'Trending video 1',
          timestamp: DateTime.now(),
          title: 'Trending Video 1',
        ),
        VideoEvent(
          id: 'trending2', 
          pubkey: 'pubkey2',
          createdAt: 1234567891,
          content: 'Trending video 2',
          timestamp: DateTime.now(),
          title: 'Trending Video 2',
        ),
      ];
      
      when(mockCurationService.getVideosForSetType(CurationSetType.trending))
          .thenReturn(mockTrendingVideos);
      
      // Mock ExploreVideoManager to have NO videos (this is the bug)
      when(mockExploreVideoManager.getVideosForType(CurationSetType.trending))
          .thenReturn([]);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ExploreVideoManager>.value(value: mockExploreVideoManager),
              ChangeNotifierProvider<CurationService>.value(value: mockCurationService),
              ChangeNotifierProvider<HashtagService>.value(value: mockHashtagService),
              ChangeNotifierProvider<VideoEventService>.value(value: mockVideoEventService),
            ],
            child: const ExploreScreen(),
          ),
        ),
      );

      // Switch to Popular Now tab (index 1)
      await tester.tap(find.text('POPULAR NOW'));
      await tester.pumpAndSettle();

      // EXPECTED BEHAVIOR: Should show the trending videos
      // ACTUAL BEHAVIOR: Shows empty state because ExploreVideoManager has no videos
      
      // This test currently PASSES but demonstrates the bug
      expect(find.text('Popular Now'), findsOneWidget);
      expect(find.text('Videos getting the most likes\nand shares right now.'), findsOneWidget);
      
      // Verify the logs show the disconnect
      verify(mockCurationService.getVideosForSetType(CurationSetType.trending)).called(greaterThan(0));
      verify(mockExploreVideoManager.getVideosForType(CurationSetType.trending)).called(greaterThan(0));
    });

    testWidgets('should show videos when both ExploreVideoManager and CurationService are in sync', (WidgetTester tester) async {
      // This test shows how it SHOULD work when both services are in sync
      
      final mockTrendingVideos = [
        VideoEvent(
          id: 'trending1',
          pubkey: 'pubkey1',
          createdAt: 1234567890,
          content: 'Trending video 1',
          timestamp: DateTime.now(),
          title: 'Trending Video 1',
        ),
        VideoEvent(
          id: 'trending2',
          pubkey: 'pubkey2', 
          createdAt: 1234567891,
          content: 'Trending video 2',
          timestamp: DateTime.now(),
          title: 'Trending Video 2',
        ),
      ];
      
      // Both services should return the same videos
      when(mockCurationService.getVideosForSetType(CurationSetType.trending))
          .thenReturn(mockTrendingVideos);
      when(mockExploreVideoManager.getVideosForType(CurationSetType.trending))
          .thenReturn(mockTrendingVideos);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ExploreVideoManager>.value(value: mockExploreVideoManager),
              ChangeNotifierProvider<CurationService>.value(value: mockCurationService),
              ChangeNotifierProvider<HashtagService>.value(value: mockHashtagService),
              ChangeNotifierProvider<VideoEventService>.value(value: mockVideoEventService),
            ],
            child: const ExploreScreen(),
          ),
        ),
      );

      // Switch to Popular Now tab (index 1)
      await tester.tap(find.text('POPULAR NOW'));
      await tester.pumpAndSettle();

      // Should show video grid when videos are available
      expect(find.byType(GridView), findsOneWidget);
      
      // Should NOT show empty state
      expect(find.text('Videos getting the most likes\nand shares right now.'), findsNothing);
    });
  });
}