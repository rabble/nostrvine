// ABOUTME: Simplified test for profile tap functionality in VideoFeedItem widget
// ABOUTME: Tests only the gesture detection on profile name without full navigation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:openvine/services/video_manager_interface.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/models/video_state.dart';
import 'package:openvine/models/user_profile.dart';

@GenerateMocks([
  IVideoManager,
  SocialService,
  AuthService,
  UserProfileService,
  AnalyticsService,
])
import 'video_feed_item_profile_tap_simple_test.mocks.dart';

void main() {
  group('VideoFeedItem Profile Tap Simplified', () {
    late MockIVideoManager mockVideoManager;
    late MockSocialService mockSocialService;
    late MockAuthService mockAuthService;
    late MockUserProfileService mockUserProfileService;
    late MockAnalyticsService mockAnalyticsService;
    
    setUp(() {
      mockVideoManager = MockIVideoManager();
      mockSocialService = MockSocialService();
      mockAuthService = MockAuthService();
      mockUserProfileService = MockUserProfileService();
      mockAnalyticsService = MockAnalyticsService();
      
      // Setup default mocks
      when(mockAuthService.currentPublicKeyHex).thenReturn('different_pubkey');
      when(mockSocialService.isFollowing(any)).thenReturn(false);
      when(mockSocialService.isLiked(any)).thenReturn(false);
      when(mockSocialService.hasReposted(any)).thenReturn(false);
      when(mockSocialService.getCachedLikeCount(any)).thenReturn(0);
      // Mock the fetchCommentsForEvent to return an empty stream
      when(mockSocialService.fetchCommentsForEvent(any)).thenAnswer(
        (_) => Stream.fromIterable([]),
      );
      when(mockUserProfileService.hasProfile(any)).thenReturn(true);
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(
        UserProfile(
          pubkey: 'test_pubkey',
          name: 'Test User',
          displayName: 'Test Display Name',
          picture: null,
          about: null,
          nip05: null,
          lud16: null,
          createdAt: DateTime.now(),
          eventId: 'test_event_id',
          rawData: {},
        ),
      );
    });

    Widget createTestWidget(VideoEvent video) {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<IVideoManager>.value(value: mockVideoManager),
            ChangeNotifierProvider<SocialService>.value(value: mockSocialService),
            ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
            ChangeNotifierProvider<UserProfileService>.value(value: mockUserProfileService),
            ChangeNotifierProvider<AnalyticsService>.value(value: mockAnalyticsService),
          ],
          child: Scaffold(
            body: VideoFeedItem(
              video: video,
              isActive: true,
            ),
          ),
        ),
      );
    }

    testWidgets('profile name uses Text widget instead of SelectableText', (WidgetTester tester) async {
      // Create test video
      final testVideo = VideoEvent(
        id: 'test_video_id',
        pubkey: 'creator_pubkey',
        videoUrl: 'https://example.com/video.mp4',
        content: 'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        hashtags: [],
        rawTags: {},
        isRepost: false,
      );
      
      // Setup video state
      when(mockVideoManager.getVideoState('test_video_id')).thenReturn(
        VideoState(
          event: testVideo,
          loadingState: VideoLoadingState.ready,
        ),
      );
      when(mockVideoManager.getController('test_video_id')).thenReturn(null);
      
      // Build widget
      await tester.pumpWidget(createTestWidget(testVideo));
      await tester.pumpAndSettle();
      
      // Verify we're using Text widget for profile name, not SelectableText
      final textWidgetFinder = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Test Display Name',
      );
      expect(textWidgetFinder, findsOneWidget);
      
      // Verify the Text widget is wrapped in a GestureDetector
      final gestureDetectorFinder = find.ancestor(
        of: textWidgetFinder,
        matching: find.byType(GestureDetector),
      );
      expect(gestureDetectorFinder, findsWidgets);
      
      // Verify the profile name is tappable
      await tester.tap(textWidgetFinder);
      await tester.pump();
      
      // We should see the debug print in the console
      // "👤 Navigating to profile: creator_pubkey"
    });

    testWidgets('reposter name also uses Text widget for tap functionality', (WidgetTester tester) async {
      // Create test reposted video
      final testVideo = VideoEvent(
        id: 'test_video_id',
        pubkey: 'original_creator_pubkey',
        videoUrl: 'https://example.com/video.mp4',
        content: 'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        hashtags: [],
        rawTags: {},
        isRepost: true,
        reposterPubkey: 'reposter_pubkey',
      );
      
      // Setup video state
      when(mockVideoManager.getVideoState('test_video_id')).thenReturn(
        VideoState(
          event: testVideo,
          loadingState: VideoLoadingState.ready,
        ),
      );
      when(mockVideoManager.getController('test_video_id')).thenReturn(null);
      
      // Setup reposter profile
      when(mockUserProfileService.getCachedProfile('reposter_pubkey')).thenReturn(
        UserProfile(
          pubkey: 'reposter_pubkey',
          name: 'Reposter',
          displayName: 'Reposter Display Name',
          picture: null,
          about: null,
          nip05: null,
          lud16: null,
          createdAt: DateTime.now(),
          eventId: 'reposter_event_id',
          rawData: {},
        ),
      );
      
      // Build widget
      await tester.pumpWidget(createTestWidget(testVideo));
      await tester.pumpAndSettle();
      
      // Find the reposter name text
      final reposterNameFinder = find.text('Reposted by Reposter Display Name');
      expect(reposterNameFinder, findsOneWidget);
      
      // Verify it's a Text widget, not SelectableText
      final textWidget = tester.widget<Text>(reposterNameFinder);
      expect(textWidget, isA<Text>());
      
      // Tap on the reposter name
      await tester.tap(reposterNameFinder);
      await tester.pump();
      
      // We should see the debug print in the console
      // "👤 Navigating to reposter profile: reposter_pubkey"
    });
  });
}