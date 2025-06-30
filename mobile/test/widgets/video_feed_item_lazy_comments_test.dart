// ABOUTME: Test for lazy comment loading behavior - comments should only load when user taps comment icon
// ABOUTME: Ensures TDD implementation that comments are not fetched automatically for video feed items

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_manager_interface.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/models/video_state.dart';

@GenerateMocks([
  SocialService,
  IVideoManager,
  UserProfileService,
  AuthService,
])
import 'video_feed_item_lazy_comments_test.mocks.dart';

void main() {
  group('VideoFeedItem Lazy Comment Loading', () {
    late MockSocialService mockSocialService;
    late MockIVideoManager mockVideoManager;
    late MockUserProfileService mockUserProfileService;
    late MockAuthService mockAuthService;
    late VideoEvent testVideo;

    setUp(() {
      mockSocialService = MockSocialService();
      mockVideoManager = MockIVideoManager();
      mockUserProfileService = MockUserProfileService();
      mockAuthService = MockAuthService();
      
      testVideo = VideoEvent(
        id: 'test_video_id',
        pubkey: 'test_pubkey',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video content',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/test.mp4',
        mimeType: 'video/mp4',
        title: 'Test Video',
        hashtags: ['test'],
      );

      // Setup default mock behavior
      final testVideoState = VideoState(
        event: testVideo,
        loadingState: VideoLoadingState.ready,
      );
      when(mockVideoManager.getVideoState('test_video_id')).thenReturn(testVideoState);
      when(mockVideoManager.getController('test_video_id')).thenReturn(null);
      
      when(mockSocialService.isLiked(any)).thenReturn(false);
      when(mockSocialService.getCachedLikeCount(any)).thenReturn(0);
      when(mockSocialService.hasReposted(any)).thenReturn(false);
      when(mockSocialService.fetchCommentsForEvent(any)).thenAnswer((_) => Stream.empty());
      
      when(mockUserProfileService.fetchProfile(any)).thenAnswer((_) async => null);
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
      when(mockAuthService.isAuthenticated).thenReturn(false);
      when(mockAuthService.currentPublicKeyHex).thenReturn(null);
    });

    testWidgets('should NOT call fetchCommentsForEvent when video is displayed', (WidgetTester tester) async {
      // Setup: Mock should never be called for comment fetching during initial display
      when(mockSocialService.fetchCommentsForEvent(any)).thenAnswer((_) => Stream.empty());
      
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SocialService>.value(value: mockSocialService),
              Provider<IVideoManager>.value(value: mockVideoManager),
              ChangeNotifierProvider<UserProfileService>.value(value: mockUserProfileService),
              ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
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

      // Wait for widget to build
      await tester.pumpAndSettle();

      // Verify: fetchCommentsForEvent should NOT be called during initial display (after implementing lazy loading)
      verifyNever(mockSocialService.fetchCommentsForEvent('test_video_id'));
    });

  });
}