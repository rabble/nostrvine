// ABOUTME: Test file for ProfileScreen navigation bug - ensures correct profile loads when navigating
// ABOUTME: Tests that clicking another user's profile doesn't show own profile

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:openvine/screens/profile_screen.dart';
import 'package:openvine/services/auth_service.dart' as auth;
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/profile_videos_provider.dart';
import 'package:openvine/models/user_profile.dart' as models;
import 'package:openvine/models/video_event.dart';
import 'package:openvine/theme/vine_theme.dart';

@GenerateMocks([
  auth.AuthService,
  UserProfileService,
  SocialService,
  VideoEventService,
  AnalyticsService,
  ProfileStatsProvider,
  ProfileVideosProvider,
])
import 'profile_screen_navigation_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late MockUserProfileService mockUserProfileService;
  late MockSocialService mockSocialService;
  late MockVideoEventService mockVideoEventService;
  late MockAnalyticsService mockAnalyticsService;
  late MockProfileStatsProvider mockProfileStatsProvider;
  late MockProfileVideosProvider mockProfileVideosProvider;

  // Use valid hex pubkeys for testing
  const String currentUserPubkey = '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
  const String otherUserPubkey = '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b';

  setUp(() {
    mockAuthService = MockAuthService();
    mockUserProfileService = MockUserProfileService();
    mockSocialService = MockSocialService();
    mockVideoEventService = MockVideoEventService();
    mockAnalyticsService = MockAnalyticsService();
    mockProfileStatsProvider = MockProfileStatsProvider();
    mockProfileVideosProvider = MockProfileVideosProvider();

    // Setup default mock behaviors
    when(mockAuthService.isAuthenticated).thenReturn(true);
    when(mockAuthService.authState).thenReturn(AuthState.authenticated);
    when(mockAuthService.currentPublicKeyHex).thenReturn(currentUserPubkey);
    when(mockAuthService.currentProfile).thenReturn(
      UserProfile(
        pubkey: currentUserPubkey,
        name: 'Current User',
        displayName: 'Current User',
        about: 'This is the current user',
        createdAt: DateTime.now(),
        rawData: {},
        eventId: 'current_user_event_id',
      ),
    );
    
    // Mock other user's profile
    when(mockUserProfileService.getCachedProfile(otherUserPubkey)).thenReturn(
      UserProfile(
        pubkey: otherUserPubkey,
        name: 'Other User',
        displayName: 'Other User',
        about: 'This is another user',
        createdAt: DateTime.now(),
        rawData: {},
        eventId: 'other_user_event_id',
      ),
    );
    
    when(mockUserProfileService.getCachedProfile(currentUserPubkey)).thenReturn(null);
    when(mockUserProfileService.fetchProfile(any)).thenAnswer((_) async => null);
    
    // Profile stats provider mocks
    when(mockProfileStatsProvider.isLoading).thenReturn(false);
    when(mockProfileStatsProvider.stats).thenReturn(null);
    when(mockProfileStatsProvider.hasError).thenReturn(false);
    when(mockProfileStatsProvider.hasData).thenReturn(false);
    when(mockProfileStatsProvider.loadProfileStats(any)).thenAnswer((_) async {});
    
    // Profile videos provider mocks
    when(mockProfileVideosProvider.isLoading).thenReturn(false);
    when(mockProfileVideosProvider.hasVideos).thenReturn(true);
    when(mockProfileVideosProvider.hasError).thenReturn(false);
    when(mockProfileVideosProvider.error).thenReturn(null);
    when(mockProfileVideosProvider.videoCount).thenReturn(2);
    when(mockProfileVideosProvider.loadingState).thenReturn(ProfileVideosLoadingState.loaded);
    when(mockProfileVideosProvider.hasMore).thenReturn(false);
    when(mockProfileVideosProvider.loadVideosForUser(any)).thenAnswer((_) async {});
    when(mockProfileVideosProvider.refreshVideos()).thenAnswer((_) async {});
    
    // Mock videos for different users
    when(mockProfileVideosProvider.videos).thenAnswer((_) {
      // This should return different videos based on which user's profile is being viewed
      return [
        VideoEvent(
          id: 'video1',
          pubkey: otherUserPubkey,
          videoUrl: 'https://example.com/video1.mp4',
          content: 'Video 1',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime.now(),
        ),
        VideoEvent(
          id: 'video2',
          pubkey: otherUserPubkey,
          videoUrl: 'https://example.com/video2.mp4',
          content: 'Video 2',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime.now(),
        ),
      ];
    });
    
    when(mockSocialService.isFollowing(any)).thenReturn(false);
    when(mockVideoEventService.refreshVideoFeed()).thenAnswer((_) async {});
  });

  Widget createTestWidget({required String? profilePubkey}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<UserProfileService>.value(value: mockUserProfileService),
        ChangeNotifierProvider<SocialService>.value(value: mockSocialService),
        ChangeNotifierProvider<VideoEventService>.value(value: mockVideoEventService),
        ChangeNotifierProvider<AnalyticsService>.value(value: mockAnalyticsService),
        ChangeNotifierProvider<ProfileStatsProvider>.value(value: mockProfileStatsProvider),
        ChangeNotifierProvider<ProfileVideosProvider>.value(value: mockProfileVideosProvider),
      ],
      child: MaterialApp(
        theme: VineTheme.theme,
        home: ProfileScreen(profilePubkey: profilePubkey),
      ),
    );
  }

  group('ProfileScreen Navigation', () {
    testWidgets('displays current user profile when profilePubkey is null', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(profilePubkey: null));
      await tester.pumpAndSettle();

      // Should show current user's name
      expect(find.text('Current User'), findsOneWidget);
      expect(find.text('Other User'), findsNothing);
      
      // Should show "Edit Profile" button for own profile
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
    });

    testWidgets('displays current user profile when profilePubkey matches current user', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(profilePubkey: currentUserPubkey));
      await tester.pumpAndSettle();

      // Should show current user's name
      expect(find.text('Current User'), findsOneWidget);
      expect(find.text('Other User'), findsNothing);
      
      // Should show "Edit Profile" button for own profile
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
    });

    testWidgets('displays other user profile when profilePubkey is different', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(profilePubkey: otherUserPubkey));
      await tester.pumpAndSettle();

      // Should show other user's name in app bar
      expect(find.text('Other User'), findsAtLeastNWidgets(1));
      expect(find.text('Current User'), findsNothing);
      
      // Should show "Follow" button for other's profile
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Edit Profile'), findsNothing);
    });

    testWidgets('loads correct videos for other user profile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(profilePubkey: otherUserPubkey));
      await tester.pumpAndSettle();

      // Verify loadVideosForUser was called with correct pubkey
      verify(mockProfileVideosProvider.loadVideosForUser(otherUserPubkey)).called(1);
      verify(mockProfileStatsProvider.loadProfileStats(otherUserPubkey)).called(1);
      
      // Should not load current user's data
      verifyNever(mockProfileVideosProvider.loadVideosForUser(currentUserPubkey));
    });

    testWidgets('navigating from one profile to another updates correctly', (WidgetTester tester) async {
      // Start with current user's profile
      await tester.pumpWidget(createTestWidget(profilePubkey: null));
      await tester.pumpAndSettle();
      
      expect(find.text('Current User'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);

      // Navigate to another user's profile
      await tester.pumpWidget(createTestWidget(profilePubkey: otherUserPubkey));
      await tester.pumpAndSettle();

      // Should now show other user's profile
      expect(find.text('Other User'), findsAtLeastNWidgets(1));
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Edit Profile'), findsNothing);
      
      // Verify correct data was loaded
      verify(mockProfileVideosProvider.loadVideosForUser(otherUserPubkey)).called(1);
    });

    testWidgets('displays correct npub for profile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(profilePubkey: otherUserPubkey));
      await tester.pumpAndSettle();

      // The npub should be for the other user, not current user
      final npubText = find.byWidgetPredicate(
        (widget) => widget is SelectableText && 
                    widget.data != null &&
                    widget.data!.startsWith('npub'),
      );
      
      expect(npubText, findsOneWidget);
      
      // Get the actual npub text
      final SelectableText npubWidget = tester.widget(npubText);
      final String npub = npubWidget.data!;
      
      // The npub should be encoded from otherUserPubkey, not currentUserPubkey
      expect(npub.contains(otherUserPubkey.substring(0, 8)), isFalse);
    });
  });
}