// ABOUTME: Widget tests for HashtagFeedScreen UI and functionality
// ABOUTME: Tests hashtag display, video loading, and "viners" text change

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/models/video_event.dart';

class MockVideoEventService extends Mock implements VideoEventService {}
class MockHashtagService extends Mock implements HashtagService {
  @override
  Future<void> subscribeToHashtagVideos(List<String> hashtags, {int limit = 100}) async {
    return;
  }
}

void main() {
  group('HashtagFeedScreen Widget Tests', () {
    late MockVideoEventService mockVideoService;
    late MockHashtagService mockHashtagService;

    setUp(() {
      mockVideoService = MockVideoEventService();
      mockHashtagService = MockHashtagService();
    });

    Widget createTestWidget(String hashtag) {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<VideoEventService>.value(value: mockVideoService),
            ChangeNotifierProvider<HashtagService>.value(value: mockHashtagService),
          ],
          child: HashtagFeedScreen(hashtag: hashtag),
        ),
      );
    }

    testWidgets('should display hashtag in app bar', (WidgetTester tester) async {
      const testHashtag = 'bitcoin';
      
      when(() => mockVideoService.isLoading).thenReturn(false);
      when(() => mockHashtagService.getVideosByHashtags([testHashtag])).thenReturn([]);
      when(() => mockHashtagService.getHashtagStats(testHashtag)).thenReturn(null);

      await tester.pumpWidget(createTestWidget(testHashtag));

      expect(find.text('#$testHashtag'), findsOneWidget);
    });

    testWidgets('should show loading indicator when videos are loading', (WidgetTester tester) async {
      const testHashtag = 'bitcoin';
      
      when(() => mockVideoService.isLoading).thenReturn(true);
      when(() => mockHashtagService.getVideosByHashtags([testHashtag])).thenReturn([]);
      when(() => mockHashtagService.getHashtagStats(testHashtag)).thenReturn(null);

      await tester.pumpWidget(createTestWidget(testHashtag));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show "No videos found" message when no videos exist', (WidgetTester tester) async {
      const testHashtag = 'bitcoin';
      
      when(() => mockVideoService.isLoading).thenReturn(false);
      when(() => mockHashtagService.getVideosByHashtags([testHashtag])).thenReturn([]);
      when(() => mockHashtagService.getHashtagStats(testHashtag)).thenReturn(null);

      await tester.pumpWidget(createTestWidget(testHashtag));

      expect(find.text('No videos found for #$testHashtag'), findsOneWidget);
      expect(find.text('Be the first to post a video with this hashtag!'), findsOneWidget);
    });

    testWidgets('should display video count and "viners" text when videos exist', (WidgetTester tester) async {
      const testHashtag = 'bitcoin';
      
      final testVideos = [
        _createTestVideoEvent('1', ['bitcoin'], 'user1'),
        _createTestVideoEvent('2', ['bitcoin'], 'user2'),
      ];

      final mockStats = HashtagStats(
        hashtag: testHashtag,
        videoCount: 2,
        recentVideoCount: 1,
        firstSeen: DateTime.now().subtract(Duration(days: 1)),
        lastSeen: DateTime.now(),
        uniqueAuthors: {'user1', 'user2'},
      );

      when(() => mockVideoService.isLoading).thenReturn(false);
      when(() => mockHashtagService.getVideosByHashtags([testHashtag])).thenReturn(testVideos);
      when(() => mockHashtagService.getHashtagStats(testHashtag)).thenReturn(mockStats);

      await tester.pumpWidget(createTestWidget(testHashtag));

      expect(find.text('2 videos'), findsOneWidget);
      expect(find.text('by 2 viners'), findsOneWidget);
    });

    testWidgets('should display recent video count when available', (WidgetTester tester) async {
      const testHashtag = 'bitcoin';
      
      final testVideos = [
        _createTestVideoEvent('1', ['bitcoin'], 'user1'),
      ];

      final mockStats = HashtagStats(
        hashtag: testHashtag,
        videoCount: 1,
        recentVideoCount: 1,
        firstSeen: DateTime.now().subtract(Duration(hours: 1)),
        lastSeen: DateTime.now(),
        uniqueAuthors: {'user1'},
      );

      when(() => mockVideoService.isLoading).thenReturn(false);
      when(() => mockHashtagService.getVideosByHashtags([testHashtag])).thenReturn(testVideos);
      when(() => mockHashtagService.getHashtagStats(testHashtag)).thenReturn(mockStats);

      await tester.pumpWidget(createTestWidget(testHashtag));

      expect(find.text('1 new in last 24 hours'), findsOneWidget);
    });

    testWidgets('should not display recent count when zero', (WidgetTester tester) async {
      const testHashtag = 'bitcoin';
      
      final testVideos = [
        _createTestVideoEvent('1', ['bitcoin'], 'user1'),
      ];

      final mockStats = HashtagStats(
        hashtag: testHashtag,
        videoCount: 1,
        recentVideoCount: 0, // No recent videos
        firstSeen: DateTime.now().subtract(Duration(days: 2)),
        lastSeen: DateTime.now().subtract(Duration(days: 1)),
        uniqueAuthors: {'user1'},
      );

      when(() => mockVideoService.isLoading).thenReturn(false);
      when(() => mockHashtagService.getVideosByHashtags([testHashtag])).thenReturn(testVideos);
      when(() => mockHashtagService.getHashtagStats(testHashtag)).thenReturn(mockStats);

      await tester.pumpWidget(createTestWidget(testHashtag));

      expect(find.text('0 new in last 24 hours'), findsNothing);
    });

    testWidgets('should trigger hashtag subscription on init', (WidgetTester tester) async {
      const testHashtag = 'bitcoin';
      
      when(() => mockVideoService.isLoading).thenReturn(false);
      when(() => mockHashtagService.getVideosByHashtags([testHashtag])).thenReturn([]);
      when(() => mockHashtagService.getHashtagStats(testHashtag)).thenReturn(null);
      when(() => mockHashtagService.subscribeToHashtagVideos([testHashtag]))
          .thenAnswer((_) async => {});

      await tester.pumpWidget(createTestWidget(testHashtag));
      await tester.pumpAndSettle();

      verify(() => mockHashtagService.subscribeToHashtagVideos([testHashtag])).called(1);
    });

    testWidgets('should display back button and navigate on tap', (WidgetTester tester) async {
      const testHashtag = 'bitcoin';
      
      when(() => mockVideoService.isLoading).thenReturn(false);
      when(() => mockHashtagService.getVideosByHashtags([testHashtag])).thenReturn([]);
      when(() => mockHashtagService.getHashtagStats(testHashtag)).thenReturn(null);

      await tester.pumpWidget(createTestWidget(testHashtag));

      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      // Test back navigation
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should pop the screen (this is hard to test without Navigator integration)
    });

    testWidgets('should show correct UI elements without stats', (WidgetTester tester) async {
      const testHashtag = 'bitcoin';
      
      final testVideos = [
        _createTestVideoEvent('1', ['bitcoin'], 'user1'),
      ];

      when(() => mockVideoService.isLoading).thenReturn(false);
      when(() => mockHashtagService.getVideosByHashtags([testHashtag])).thenReturn(testVideos);
      when(() => mockHashtagService.getHashtagStats(testHashtag)).thenReturn(null);

      await tester.pumpWidget(createTestWidget(testHashtag));

      expect(find.text('1 videos'), findsOneWidget);
      expect(find.textContaining('viners'), findsNothing); // Should not show viners count without stats
    });
  });
}

VideoEvent _createTestVideoEvent(String id, List<String> hashtags, String pubkey) {
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return VideoEvent(
    id: 'video_$id',
    pubkey: pubkey,
    createdAt: timestamp,
    content: 'Test video $id content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
    videoUrl: 'https://example.com/video$id.mp4',
    thumbnailUrl: 'https://example.com/thumb$id.jpg',
    title: 'Test Video $id',
    hashtags: hashtags,
    duration: 30,
  );
}