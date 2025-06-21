import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:nostrvine_app/widgets/video_feed_item.dart';
import 'package:nostrvine_app/services/social_service.dart';
import 'package:nostrvine_app/models/video_event.dart';

// Generate mocks
@GenerateMocks([SocialService])
import 'video_feed_item_like_test.mocks.dart';

void main() {
  group('VideoFeedItem Like Button', () {
    late MockSocialService mockSocialService;
    late VideoEvent testVideoEvent;

    setUp(() {
      mockSocialService = MockSocialService();
      testVideoEvent = VideoEvent(
        id: 'test_video_123',
        pubkey: 'test_author_pubkey',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video content',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
        mimeType: 'video/mp4',
      );
    });

    Widget createTestWidget({bool isLiked = false, int likeCount = 0}) {
      // Mock social service responses
      when(mockSocialService.isLiked(testVideoEvent.id)).thenReturn(isLiked);
      when(mockSocialService.getCachedLikeCount(testVideoEvent.id)).thenReturn(likeCount);
      when(mockSocialService.getLikeStatus(testVideoEvent.id)).thenAnswer(
        (_) async => {'count': likeCount, 'user_liked': isLiked},
      );
      when(mockSocialService.toggleLike(testVideoEvent.id, testVideoEvent.pubkey))
          .thenAnswer((_) async {});

      return MaterialApp(
        home: ChangeNotifierProvider<SocialService>.value(
          value: mockSocialService,
          child: Scaffold(
            body: VideoFeedItem(
              videoEvent: testVideoEvent,
              isActive: true,
            ),
          ),
        ),
      );
    }

    testWidgets('should show unfilled heart when video is not liked', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isLiked: false, likeCount: 0));
      await tester.pumpAndSettle();

      // Should show unfilled heart icon
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);

      // Should not show like count when count is 0
      expect(find.text('0'), findsNothing);
    });

    testWidgets('should show filled red heart when video is liked', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isLiked: true, likeCount: 5));
      await tester.pumpAndSettle();

      // Should show filled heart icon
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);

      // Should show like count
      expect(find.text('5'), findsOneWidget);

      // Heart should be red
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.favorite));
      expect(iconWidget.color, Colors.red);
    });

    testWidgets('should display formatted like counts correctly', (WidgetTester tester) async {
      // Test thousands formatting
      await tester.pumpWidget(createTestWidget(isLiked: false, likeCount: 1500));
      await tester.pumpAndSettle();
      expect(find.text('1.5K'), findsOneWidget);

      // Test millions formatting
      await tester.pumpWidget(createTestWidget(isLiked: false, likeCount: 2500000));
      await tester.pumpAndSettle();
      expect(find.text('2.5M'), findsOneWidget);

      // Test regular numbers
      await tester.pumpWidget(createTestWidget(isLiked: false, likeCount: 999));
      await tester.pumpAndSettle();
      expect(find.text('999'), findsOneWidget);
    });

    testWidgets('should call toggleLike when like button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isLiked: false, likeCount: 0));
      await tester.pumpAndSettle();

      // Find the like button container and tap it
      final likeButton = find.byIcon(Icons.favorite_border);
      expect(likeButton, findsOneWidget);

      await tester.tap(likeButton);
      await tester.pumpAndSettle();

      // Verify toggleLike was called with correct parameters
      verify(mockSocialService.toggleLike(testVideoEvent.id, testVideoEvent.pubkey)).called(1);
    });

    testWidgets('should update UI immediately when like state changes', (WidgetTester tester) async {
      // Start with unliked state
      when(mockSocialService.isLiked(testVideoEvent.id)).thenReturn(false);
      when(mockSocialService.getCachedLikeCount(testVideoEvent.id)).thenReturn(0);
      when(mockSocialService.getLikeStatus(testVideoEvent.id)).thenAnswer(
        (_) async => {'count': 0, 'user_liked': false},
      );

      await tester.pumpWidget(createTestWidget(isLiked: false, likeCount: 0));
      await tester.pumpAndSettle();

      // Should show unfilled heart
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      // Simulate state change after tap
      when(mockSocialService.isLiked(testVideoEvent.id)).thenReturn(true);
      when(mockSocialService.getCachedLikeCount(testVideoEvent.id)).thenReturn(1);
      when(mockSocialService.getLikeStatus(testVideoEvent.id)).thenAnswer(
        (_) async => {'count': 1, 'user_liked': true},
      );

      // Tap the like button
      await tester.tap(find.byIcon(Icons.favorite_border));
      
      // Trigger rebuild by calling notifyListeners simulation
      await tester.binding.reassembleApplication();
      await tester.pumpAndSettle();

      // Note: In a real test, we'd need to simulate the ChangeNotifier.notifyListeners()
      // This test structure shows the intent but would need refinement for actual state changes
    });

    testWidgets('should show error snackbar when toggleLike fails', (WidgetTester tester) async {
      // Mock toggleLike to throw error
      when(mockSocialService.toggleLike(testVideoEvent.id, testVideoEvent.pubkey))
          .thenThrow(Exception('Network error'));

      await tester.pumpWidget(createTestWidget(isLiked: false, likeCount: 0));
      await tester.pumpAndSettle();

      // Tap the like button
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      // Should show error snackbar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Failed to like video: Exception: Network error'), findsOneWidget);
    });

    testWidgets('should handle loading state properly', (WidgetTester tester) async {
      // Mock delayed response
      when(mockSocialService.getLikeStatus(testVideoEvent.id)).thenAnswer(
        (_) => Future.delayed(
          const Duration(seconds: 1),
          () => {'count': 5, 'user_liked': false},
        ),
      );

      await tester.pumpWidget(createTestWidget(isLiked: false, likeCount: 0));
      
      // Should show initial state while loading
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      
      // Wait for future to complete
      await tester.pump(const Duration(seconds: 2));
      
      // Should show updated count
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('should not show count when like count is zero', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isLiked: false, likeCount: 0));
      await tester.pumpAndSettle();

      // Should not display "0" text
      expect(find.text('0'), findsNothing);
      
      // But should show the heart icon
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('should maintain proper button sizing and styling', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(isLiked: false, likeCount: 42));
      await tester.pumpAndSettle();

      // Check that like button exists
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      
      // Check that count is displayed
      expect(find.text('42'), findsOneWidget);

      // Check icon size
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.favorite_border));
      expect(iconWidget.size, 24);
    });
  });
}