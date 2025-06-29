// ABOUTME: Test file for ProfileScreen widget functionality
// ABOUTME: Tests profile refresh after setup and refresh button positioning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:openvine/screens/profile_screen.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/profile_videos_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/models/user_profile.dart';

@GenerateMocks([
  AuthService,
  UserProfileService,
  SocialService,
  VideoEventService,
  AnalyticsService,
  ProfileStatsProvider,
  ProfileVideosProvider,
])
import 'profile_screen_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late MockUserProfileService mockUserProfileService;
  late MockSocialService mockSocialService;
  late MockVideoEventService mockVideoEventService;
  late MockAnalyticsService mockAnalyticsService;
  late MockProfileStatsProvider mockProfileStatsProvider;
  late MockProfileVideosProvider mockProfileVideosProvider;

  setUp(() {
    mockAuthService = MockAuthService();
    mockUserProfileService = MockUserProfileService();
    mockSocialService = MockSocialService();
    mockVideoEventService = MockVideoEventService();
    mockAnalyticsService = MockAnalyticsService();
    mockProfileStatsProvider = MockProfileStatsProvider();
    mockProfileVideosProvider = MockProfileVideosProvider();

    // Setup default mock behaviors
    when(mockAuthService.authState).thenReturn(AuthState.authenticated);
    when(mockAuthService.currentPublicKeyHex).thenReturn('79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798');
    when(mockAuthService.currentProfile).thenReturn(null);
    when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
    when(mockUserProfileService.fetchProfile(any)).thenAnswer((_) async {});
    when(mockProfileStatsProvider.isLoading).thenReturn(false);
    when(mockProfileStatsProvider.stats).thenReturn(null);
    when(mockProfileStatsProvider.hasError).thenReturn(false);
    when(mockProfileStatsProvider.hasData).thenReturn(false);
    when(mockProfileStatsProvider.loadProfileStats(any)).thenAnswer((_) async {});
    when(mockProfileVideosProvider.isLoading).thenReturn(false);
    when(mockProfileVideosProvider.hasVideos).thenReturn(false);
    when(mockProfileVideosProvider.hasError).thenReturn(false);
    when(mockProfileVideosProvider.error).thenReturn(null);
    when(mockProfileVideosProvider.videoCount).thenReturn(0);
    when(mockProfileVideosProvider.videos).thenReturn([]);
    when(mockProfileVideosProvider.loadingState).thenReturn(ProfileVideosLoadingState.loaded);
    when(mockProfileVideosProvider.hasMore).thenReturn(false);
    when(mockProfileVideosProvider.loadVideosForUser(any)).thenAnswer((_) async {});
    when(mockProfileVideosProvider.refreshVideos()).thenAnswer((_) async {});
    when(mockSocialService.isFollowing(any)).thenReturn(false);
    when(mockVideoEventService.refreshVideoFeed()).thenAnswer((_) async {});
  });

  Widget createTestWidget({Widget? child}) {
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
        home: child ?? const ProfileScreen(),
      ),
    );
  }

  group('ProfileScreen', () {
    testWidgets('displays profile setup banner when user has default name', (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.currentProfile).thenReturn(
        const UserProfile(
          npub: 'npub1test',
          publicKeyHex: 'test_pubkey_hex',
          displayName: 'npub1test', // Default name format
          picture: null,
          about: null,
        ),
      );

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Complete Your Profile'), findsOneWidget);
      expect(find.text('Add your name, bio, and picture to get started'), findsOneWidget);
      expect(find.text('Set Up'), findsOneWidget);
    });

    testWidgets('navigates to ProfileSetupScreen when Set Up is tapped', (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.currentProfile).thenReturn(
        const UserProfile(
          npub: 'npub1test',
          publicKeyHex: 'test_pubkey_hex',
          displayName: 'npub1test',
          picture: null,
          about: null,
        ),
      );

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Set Up'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
    });

    testWidgets('refreshes profile data when returning from ProfileSetupScreen', (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.currentProfile).thenReturn(
        const UserProfile(
          npub: 'npub1test',
          publicKeyHex: 'test_pubkey_hex',
          displayName: 'npub1test',
          picture: null,
          about: null,
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Navigate to setup screen
      await tester.tap(find.text('Set Up'));
      await tester.pumpAndSettle();

      // Simulate returning from ProfileSetupScreen with success
      Navigator.of(tester.element(find.byType(ProfileSetupScreen))).pop(true);
      await tester.pumpAndSettle();

      // Assert that profile refresh methods were called
      verify(mockUserProfileService.fetchProfile('test_pubkey_hex')).called(greaterThanOrEqualTo(1));
      verify(mockProfileStatsProvider.loadProfileStats('test_pubkey_hex')).called(greaterThanOrEqualTo(1));
      verify(mockProfileVideosProvider.loadVideosForUser('test_pubkey_hex')).called(greaterThanOrEqualTo(1));
    });

    testWidgets('refresh button is positioned correctly to avoid FAB overlap', (WidgetTester tester) async {
      // Arrange
      when(mockProfileVideosProvider.hasVideos).thenReturn(false);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the tab for videos and tap it
      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pumpAndSettle();

      // Assert refresh button exists and check its position
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);

      // Get the position of the refresh button
      final refreshButtonPosition = tester.getTopRight(refreshButton);
      
      // The refresh button should be in the top-right area, not center bottom
      expect(refreshButtonPosition.dx, greaterThan(300)); // Should be on the right side
      expect(refreshButtonPosition.dy, lessThan(500)); // Should be in upper half of screen
    });

    testWidgets('empty state has padding to avoid FAB overlap', (WidgetTester tester) async {
      // Arrange
      when(mockProfileVideosProvider.hasVideos).thenReturn(false);

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the tab for videos and tap it
      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pumpAndSettle();

      // Find the Padding widget that wraps the empty state
      final paddingWidget = find.byWidgetPredicate(
        (widget) => widget is Padding && 
                    widget.padding == const EdgeInsets.only(bottom: 80),
      );

      expect(paddingWidget, findsOneWidget);
    });

    testWidgets('displays updated profile after setup', (WidgetTester tester) async {
      // Arrange - start with default profile
      const defaultProfile = UserProfile(
        npub: 'npub1test',
        publicKeyHex: 'test_pubkey_hex',
        displayName: 'npub1test',
        picture: null,
        about: null,
      );
      
      when(mockAuthService.currentProfile).thenReturn(defaultProfile);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Update the profile
      const updatedProfile = UserProfile(
        npub: 'npub1test',
        publicKeyHex: 'test_pubkey_hex',
        displayName: 'John Doe',
        picture: 'https://example.com/avatar.jpg',
        about: 'Test bio',
      );

      when(mockAuthService.currentProfile).thenReturn(updatedProfile);
      
      // Trigger rebuild
      mockAuthService.notifyListeners();
      await tester.pumpAndSettle();

      // Assert updated profile is displayed
      expect(find.text('John Doe'), findsAtLeastNWidgets(1));
      expect(find.text('Complete Your Profile'), findsNothing);
    });

    testWidgets('refresh button triggers video refresh', (WidgetTester tester) async {
      // Arrange
      when(mockProfileVideosProvider.hasVideos).thenReturn(false);
      when(mockProfileVideosProvider.refreshVideos()).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the tab for videos and tap it
      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pumpAndSettle();

      // Tap the refresh button
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      // Assert
      verify(mockProfileVideosProvider.refreshVideos()).called(1);
    });
  });
}