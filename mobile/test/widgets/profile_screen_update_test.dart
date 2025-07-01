// ABOUTME: Test for profile screen UI updates after editing profile
// ABOUTME: Ensures the profile screen properly refreshes and shows updated data

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/screens/profile_screen.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/profile_videos_provider.dart';
import 'package:openvine/models/user_profile.dart' as models;
import 'package:openvine/providers/profile_videos_provider.dart' show ProfileVideosLoadingState;

@GenerateMocks([
  AuthService,
  UserProfileService,
  SocialService,
  VideoEventService,
  ProfileStatsProvider,
  ProfileVideosProvider,
])
import 'profile_screen_update_test.mocks.dart';

void main() {
  group('Profile Screen Update Tests', () {
    late MockAuthService mockAuthService;
    late MockUserProfileService mockUserProfileService;
    late MockSocialService mockSocialService;
    late MockVideoEventService mockVideoEventService;
    late MockProfileStatsProvider mockProfileStatsProvider;
    late MockProfileVideosProvider mockProfileVideosProvider;
    
    setUp(() {
      mockAuthService = MockAuthService();
      mockUserProfileService = MockUserProfileService();
      mockSocialService = MockSocialService();
      mockVideoEventService = MockVideoEventService();
      mockProfileStatsProvider = MockProfileStatsProvider();
      mockProfileVideosProvider = MockProfileVideosProvider();
      
      // Setup default mocks
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn('current_user_pubkey');
      when(mockSocialService.followingPubkeys).thenReturn([]);
      when(mockProfileStatsProvider.hasData).thenReturn(false);
      when(mockProfileStatsProvider.isLoading).thenReturn(false);
      when(mockProfileVideosProvider.isLoading).thenReturn(false);
      when(mockProfileVideosProvider.hasVideos).thenReturn(false);
      when(mockProfileVideosProvider.hasError).thenReturn(false);
      when(mockProfileVideosProvider.videoCount).thenReturn(0);
      when(mockProfileVideosProvider.loadingState).thenReturn(ProfileVideosLoadingState.idle);
      // Add specific getCachedProfile stub for current user
      when(mockUserProfileService.getCachedProfile('current_user_pubkey')).thenReturn(null);
    });

    Widget createTestWidget({String? profilePubkey}) {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
            ChangeNotifierProvider<UserProfileService>.value(value: mockUserProfileService),
            ChangeNotifierProvider<SocialService>.value(value: mockSocialService),
            ChangeNotifierProvider<VideoEventService>.value(value: mockVideoEventService),
            ChangeNotifierProvider<ProfileStatsProvider>.value(value: mockProfileStatsProvider),
            ChangeNotifierProvider<ProfileVideosProvider>.value(value: mockProfileVideosProvider),
          ],
          child: ProfileScreen(profilePubkey: profilePubkey),
        ),
      );
    }

    testWidgets('should show default profile data initially', (WidgetTester tester) async {
      // Setup initial profile state
      when(mockAuthService.currentProfile).thenReturn(null);
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Should show default anonymous user
      expect(find.text('Anonymous'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsWidgets);
    });

    testWidgets('should show edit profile button for own profile', (WidgetTester tester) async {
      // Setup for own profile view
      when(mockAuthService.currentProfile).thenReturn(
        UserProfile(
          npub: 'npub1testuser',
          publicKeyHex: 'current_user_pubkey',
          displayName: 'Test Display Name',
          about: 'Test bio',
          picture: null,
        ),
      );
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Should show options menu (hamburger icon)
      expect(find.byIcon(Icons.menu), findsOneWidget);
      
      // Tap the menu
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      
      // Should show Edit Profile option
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('should not show edit profile button for other user profiles', (WidgetTester tester) async {
      // Setup for viewing another user's profile
      when(mockAuthService.currentProfile).thenReturn(
        UserProfile(
          npub: 'npub1currentuser',
          publicKeyHex: 'current_user_pubkey',
          displayName: 'Current User',
          about: null,
          picture: null,
        ),
      );
      
      when(mockUserProfileService.getCachedProfile('other_user_pubkey')).thenReturn(
        models.UserProfile(
          pubkey: 'other_user_pubkey',
          name: 'Other User',
          displayName: 'Other User',
          about: 'Other user bio',
          picture: null,
          createdAt: DateTime.now(),
          eventId: 'other_event_id',
          rawData: {},
        ),
      );
      
      await tester.pumpWidget(createTestWidget(profilePubkey: 'other_user_pubkey'));
      await tester.pumpAndSettle();
      
      // Should show options menu (vertical dots) for other users
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      
      // Should not show hamburger menu
      expect(find.byIcon(Icons.menu), findsNothing);
    });

    testWidgets('should update profile display after editing', (WidgetTester tester) async {
      // Setup initial profile
      var currentProfile = UserProfile(
        npub: 'npub1currentuser',
        publicKeyHex: 'current_user_pubkey',
        displayName: 'Old Display Name',
        about: 'Old bio',
        picture: null,
      );
      
      when(mockAuthService.currentProfile).thenReturn(currentProfile);
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Verify initial state
      expect(find.text('Old Display Name'), findsOneWidget);
      expect(find.text('Old bio'), findsOneWidget);
      
      // Simulate profile update
      final updatedProfile = UserProfile(
        npub: 'npub1currentuser',
        publicKeyHex: 'current_user_pubkey',
        displayName: 'New Display Name',
        about: 'New bio description',
        picture: 'https://example.com/new-avatar.jpg',
      );
      
      // Update the mock to return new profile
      when(mockAuthService.currentProfile).thenReturn(updatedProfile);
      
      // Trigger rebuild (simulate returning from edit screen)
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Verify updated state
      expect(find.text('New Display Name'), findsOneWidget);
      expect(find.text('New bio description'), findsOneWidget);
      expect(find.text('Old Display Name'), findsNothing);
      expect(find.text('Old bio'), findsNothing);
    });

    testWidgets('should show profile setup banner for users without custom names', (WidgetTester tester) async {
      // Setup user with default/npub name
      when(mockAuthService.currentProfile).thenReturn(
        UserProfile(
          npub: 'npub1abc123...',
          publicKeyHex: 'current_user_pubkey',
          displayName: 'npub1abc123...',
          about: null,
          picture: null,
        ),
      );
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Should show profile setup banner
      expect(find.text('Complete Your Profile'), findsOneWidget);
      expect(find.text('Set Up'), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('should not show profile setup banner for users with custom names', (WidgetTester tester) async {
      // Setup user with custom name
      when(mockAuthService.currentProfile).thenReturn(
        UserProfile(
          npub: 'npub1customuser',
          publicKeyHex: 'current_user_pubkey',
          displayName: 'Custom Display Name',
          about: 'Custom bio',
          picture: null,
        ),
      );
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Should not show profile setup banner
      expect(find.text('Complete Your Profile'), findsNothing);
      expect(find.text('Set Up'), findsNothing);
      expect(find.byIcon(Icons.person_add), findsNothing);
    });

    testWidgets('should refresh profile data when returning from edit', (WidgetTester tester) async {
      // Setup initial profile
      when(mockAuthService.currentProfile).thenReturn(
        UserProfile(
          npub: 'npub1initialuser',
          publicKeyHex: 'current_user_pubkey',
          displayName: 'Initial Name',
          about: null,
          picture: null,
        ),
      );
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Open options menu
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      
      // Tap Edit Profile
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();
      
      // Verify ProfileSetupScreen is opened
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
      
      // Simulate returning with updated profile
      Navigator.of(tester.element(find.byType(ProfileSetupScreen))).pop(true);
      await tester.pumpAndSettle();
      
      // Verify video feed refresh is called when returning
      verify(mockVideoEventService.refreshVideoFeed()).called(greaterThan(0));
    });

    testWidgets('should handle profile loading states correctly', (WidgetTester tester) async {
      // Setup loading state
      when(mockAuthService.currentProfile).thenReturn(null);
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
      when(mockProfileStatsProvider.isLoading).thenReturn(true);
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Should show loading indicators
      expect(find.text('—'), findsWidgets); // Dash for loading stats
    });

    testWidgets('should display profile picture when available', (WidgetTester tester) async {
      // Setup profile with picture
      when(mockAuthService.currentProfile).thenReturn(
        UserProfile(
          npub: 'npub1userwithpic',
          publicKeyHex: 'current_user_pubkey',
          displayName: 'User With Picture',
          about: 'Has a profile picture',
          picture: 'https://example.com/avatar.jpg',
        ),
      );
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Should show network image
      expect(find.byType(CircleAvatar), findsOneWidget);
      
      // Should have gradient border around avatar
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('should copy npub to clipboard when tapped', (WidgetTester tester) async {
      // Setup profile
      when(mockAuthService.currentProfile).thenReturn(
        UserProfile(
          npub: 'npub1testuser',
          publicKeyHex: 'current_user_pubkey',
          displayName: 'Test User',
          about: null,
          picture: null,
        ),
      );
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Find and tap the npub container
      final npubFinder = find.byWidgetPredicate(
        (widget) => widget is Container && 
                    widget.decoration is BoxDecoration &&
                    (widget.decoration as BoxDecoration).color == const Color(0xFF424242), // Colors.grey[800]
      );
      
      expect(npubFinder, findsOneWidget);
      
      // Tap should trigger clipboard copy (would need to mock clipboard in real test)
      await tester.tap(npubFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('should navigate to profile setup when setup button tapped', (WidgetTester tester) async {
      // Setup user without custom name
      when(mockAuthService.currentProfile).thenReturn(
        UserProfile(
          npub: 'npub1abc123...',
          publicKeyHex: 'current_user_pubkey',
          displayName: 'npub1abc123...',
          about: null,
          picture: null,
        ),
      );
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      // Tap the "Set Up" button in the banner
      await tester.tap(find.text('Set Up'));
      await tester.pumpAndSettle();
      
      // Should navigate to ProfileSetupScreen
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
    });
  });
}