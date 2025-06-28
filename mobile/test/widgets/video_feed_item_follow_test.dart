import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/models/video_state.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_manager_interface.dart';

// Generate mocks
@GenerateMocks([AuthService, SocialService, UserProfileService, IVideoManager])
import 'video_feed_item_follow_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('VideoFeedItem Follow Button Tests', () {
    late MockAuthService mockAuthService;
    late MockSocialService mockSocialService;
    late MockUserProfileService mockUserProfileService;
    late MockIVideoManager mockVideoManager;
    late VideoEvent testVideo;

    setUp(() {
      mockAuthService = MockAuthService();
      mockSocialService = MockSocialService();
      mockUserProfileService = MockUserProfileService();
      mockVideoManager = MockIVideoManager();
      
      testVideo = VideoEvent(
        id: 'test_video_123456',
        pubkey: 'other_user_pubkey_123',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        timestamp: DateTime.now(),
        content: 'Test video content',
        videoUrl: 'https://example.com/test.mp4',
      );

      // Setup common mocks
      when(mockVideoManager.getController(any)).thenReturn(null);
      when(mockVideoManager.getVideoState(any)).thenReturn(VideoState(event: testVideo));
      when(mockVideoManager.preloadVideo(any)).thenAnswer((_) async {});
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
      when(mockUserProfileService.hasProfile(any)).thenReturn(false);
      when(mockUserProfileService.fetchProfile(any)).thenAnswer((_) async => null);
      when(mockSocialService.fetchCommentsForEvent(any)).thenAnswer((_) => Stream.empty());
      when(mockSocialService.getCachedLikeCount(any)).thenReturn(0);
      when(mockSocialService.isLiked(any)).thenReturn(false);
      when(mockSocialService.hasReposted(any)).thenReturn(false);
      when(mockSocialService.isFollowing(any)).thenReturn(false);
      when(mockSocialService.followUser(any)).thenAnswer((_) async {});
      when(mockSocialService.unfollowUser(any)).thenAnswer((_) async {});
    });

    testWidgets('should show follow button for other users video', (WidgetTester tester) async {
      // Setup: user is authenticated but not the video author
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn('current_user_pubkey');
      when(mockSocialService.isFollowing(testVideo.pubkey)).thenReturn(false);
      when(mockVideoManager.getVideoState(any)).thenReturn(VideoState(event: testVideo));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
              ChangeNotifierProvider<SocialService>.value(value: mockSocialService),
              ChangeNotifierProvider<UserProfileService>.value(value: mockUserProfileService),
              Provider<IVideoManager>.value(value: mockVideoManager),
            ],
            child: Scaffold(
              body: VideoFeedItem(
                video: testVideo,
                isActive: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify follow button exists
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Following'), findsNothing);
    });

    testWidgets('should show Following when user is already following', (WidgetTester tester) async {
      // Setup: user is authenticated and already following
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn('current_user_pubkey');
      when(mockSocialService.isFollowing(testVideo.pubkey)).thenReturn(true);
      when(mockVideoManager.getVideoState(any)).thenReturn(VideoState(event: testVideo));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
              ChangeNotifierProvider<SocialService>.value(value: mockSocialService),
              ChangeNotifierProvider<UserProfileService>.value(value: mockUserProfileService),
              Provider<IVideoManager>.value(value: mockVideoManager),
            ],
            child: Scaffold(
              body: VideoFeedItem(
                video: testVideo,
                isActive: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Following button is shown
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
    });

    testWidgets('should not show follow button for own video', (WidgetTester tester) async {
      // Setup: user is authenticated and viewing their own video
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testVideo.pubkey); // Same as video author
      when(mockVideoManager.getVideoState(any)).thenReturn(VideoState(event: testVideo));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
              ChangeNotifierProvider<SocialService>.value(value: mockSocialService),
              ChangeNotifierProvider<UserProfileService>.value(value: mockUserProfileService),
              Provider<IVideoManager>.value(value: mockVideoManager),
            ],
            child: Scaffold(
              body: VideoFeedItem(
                video: testVideo,
                isActive: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify no follow button is shown for own video
      expect(find.text('Follow'), findsNothing);
      expect(find.text('Following'), findsNothing);
    });

    testWidgets('should call followUser when Follow button is tapped', (WidgetTester tester) async {
      // Setup
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn('current_user_pubkey');
      when(mockSocialService.isFollowing(testVideo.pubkey)).thenReturn(false);
      when(mockSocialService.followUser(any)).thenAnswer((_) async {});
      when(mockVideoManager.getVideoState(any)).thenReturn(VideoState(event: testVideo));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
              ChangeNotifierProvider<SocialService>.value(value: mockSocialService),
              ChangeNotifierProvider<UserProfileService>.value(value: mockUserProfileService),
              Provider<IVideoManager>.value(value: mockVideoManager),
            ],
            child: Scaffold(
              body: VideoFeedItem(
                video: testVideo,
                isActive: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the follow button
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      // Verify followUser was called
      verify(mockSocialService.followUser(testVideo.pubkey)).called(1);
    });
  });
}