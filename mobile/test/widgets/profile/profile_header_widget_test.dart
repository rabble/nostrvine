// ABOUTME: Tests for ProfileHeaderWidget
// ABOUTME: Verifies profile header displays avatar, stats, name, bio, and npub correctly

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/widgets/profile/profile_header_widget.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockMyProfileBloc extends MockBloc<MyProfileEvent, MyProfileState>
    implements MyProfileBloc {}

class _MockOthersFollowersBloc
    extends MockBloc<OthersFollowersEvent, OthersFollowersState>
    implements OthersFollowersBloc {}

// Mock classes
class MockFollowRepository extends Mock implements FollowRepository {
  @override
  List<String> get followingPubkeys => [];

  @override
  Stream<List<String>> get followingStream => Stream.value([]);

  @override
  bool get isInitialized => true;

  @override
  int get followingCount => 0;

  @override
  Future<List<String>> getMyFollowers() async => [];

  @override
  Future<List<String>> getFollowers(String pubkey) async => [];

  @override
  bool isFollowing(String pubkey) => false;

  @override
  Stream<({List<String> pubkeys, int count})> watchMyFollowers() {
    return Stream.value((pubkeys: <String>[], count: 0));
  }

  @override
  Future<int> getMyFollowerCount() async => 0;

  @override
  Future<int> getFollowerCount(String pubkey) async => 0;
}

class MockNostrClient extends Mock implements NostrClient {
  MockNostrClient({this.testPublicKey = testUserHex});

  final String testPublicKey;

  @override
  bool get hasKeys => true;

  @override
  String get publicKey => testPublicKey;

  @override
  bool get isInitialized => true;

  @override
  int get connectedRelayCount => 1;
}

class MockAuthService extends Mock implements AuthService {
  MockAuthService({
    this.isAnonymousValue = false,
    this.hasExpiredOAuthSessionValue = false,
  });

  final bool isAnonymousValue;
  final bool hasExpiredOAuthSessionValue;

  @override
  bool get isAnonymous => isAnonymousValue;

  @override
  bool get isAuthenticated => true;

  @override
  String? get currentPublicKeyHex => testUserHex;

  @override
  Stream<AuthState> get authStateStream =>
      Stream.value(AuthState.authenticated);

  @override
  bool get hasExpiredOAuthSession => hasExpiredOAuthSessionValue;
}

const testUserHex =
    '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
const _dismissedDivineLoginBannerPrefix = 'dismissed_divine_login_banner_';

void main() {
  group('ProfileHeaderWidget', () {
    late MockFollowRepository mockFollowRepository;
    late MockNostrClient mockNostrClient;

    UserProfile createTestProfile({
      String? displayName,
      String? name,
      String? about,
      String? picture,
      String? nip05,
    }) {
      return UserProfile(
        pubkey: testUserHex,
        rawData: {
          'display_name': ?displayName,
          'name': ?name,
          'about': ?about,
          'picture': ?picture,
          'nip05': ?nip05,
        },
        displayName: displayName,
        name: name,
        about: about,
        picture: picture,
        nip05: nip05,
        createdAt: DateTime.now(),
        eventId: 'test-event',
      );
    }

    setUp(() {
      mockFollowRepository = MockFollowRepository();
      mockNostrClient = MockNostrClient();
    });

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
    });

    Widget buildTestWidget({
      required String userIdHex,
      required bool isOwnProfile,
      int videoCount = 10,
      UserProfile? profile,
      UserProfile? suppliedProfile,
      ProfileStats? profileStats,
      bool profileIsLoading = false,
      bool isAnonymous = false,
      bool hasExpiredSession = false,
      SharedPreferences? sharedPreferences,
      String? displayNameHint,
      String? avatarUrlHint,
      MyProfileState? myProfileState,
    }) {
      final authService = MockAuthService(
        isAnonymousValue: isAnonymous,
        hasExpiredOAuthSessionValue: hasExpiredSession,
      );

      Widget header = ProfileHeaderWidget(
        userIdHex: userIdHex,
        isOwnProfile: isOwnProfile,
        videoCount: videoCount,
        profile: suppliedProfile,
        profileStats: profileStats,
        displayNameHint: displayNameHint,
        avatarUrlHint: avatarUrlHint,
      );

      if (isOwnProfile) {
        final mockMyProfileBloc = _MockMyProfileBloc();
        final state =
            myProfileState ??
            (profile != null
                ? MyProfileUpdated(profile: profile)
                : const MyProfileInitial());
        when(() => mockMyProfileBloc.state).thenReturn(state);
        header = BlocProvider<MyProfileBloc>.value(
          value: mockMyProfileBloc,
          child: header,
        );
      } else {
        final mockOthersFollowersBloc = _MockOthersFollowersBloc();
        when(
          () => mockOthersFollowersBloc.state,
        ).thenReturn(const OthersFollowersState());
        header = BlocProvider<OthersFollowersBloc>.value(
          value: mockOthersFollowersBloc,
          child: header,
        );
      }

      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(
            mockNostrService: mockNostrClient,
            mockSharedPreferences: sharedPreferences,
            mockNip05VerificationService: createMockNip05VerificationService(),
          ),
          fetchUserProfileProvider(userIdHex).overrideWith(
            profileIsLoading
                ? (ref) => Completer<UserProfile?>().future
                : (ref) async => profile,
          ),
          userProfileStatsReactiveProvider(userIdHex).overrideWith(
            (ref) => profileStats != null
                ? Stream.value(profileStats)
                : const Stream<ProfileStats?>.empty(),
          ),
          followRepositoryProvider.overrideWithValue(mockFollowRepository),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWith(
            (ref) => AuthState.authenticated,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: header)),
        ),
      );
    }

    testWidgets('displays user avatar when profile is loaded', (tester) async {
      final testProfile = createTestProfile(
        displayName: 'Test User',
        name: 'testuser',
        about: 'This is my bio',
        picture: 'https://example.com/avatar.jpg',
        nip05: 'test@example.com',
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,

          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatar), findsOneWidget);
    });

    testWidgets(
      'uses parent-supplied profile for other users while fallback provider is unresolved',
      (tester) async {
        final suppliedProfile = createTestProfile(
          displayName: 'Cached Classic',
          about: 'Seeded bio',
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: false,
            suppliedProfile: suppliedProfile,
            profileIsLoading: true,
          ),
        );
        await tester.pump();

        expect(find.text('Cached Classic'), findsOneWidget);
        expect(find.text('Seeded bio'), findsOneWidget);
      },
    );

    testWidgets('displays stats from ProfileStats when provided', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Counted User');
      const profileStats = ProfileStats(
        pubkey: testUserHex,
        videoCount: 42,
        totalLikes: 100,
        totalViews: 5000,
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: testProfile,
          profileStats: profileStats,
          videoCount: 3,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Likes'), findsOneWidget);
      expect(find.text('Loops'), findsOneWidget);
    });

    testWidgets('displays all four stat columns when stats are available', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Test User');
      const profileStats = ProfileStats(pubkey: testUserHex);

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profile: testProfile,
          profileStats: profileStats,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Likes'), findsOneWidget);
      expect(find.text('Loops'), findsOneWidget);
    });

    testWidgets('hides all stat columns when profileStats is null', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Test User');

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Followers'), findsNothing);
      expect(find.text('Following'), findsNothing);
      expect(find.text('Likes'), findsNothing);
      expect(find.text('Loops'), findsNothing);
    });

    testWidgets('displays user bio when present', (tester) async {
      final testProfile = createTestProfile(
        displayName: 'Test User',
        about: 'This is my bio',
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,

          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This is my bio'), findsOneWidget);
    });

    testWidgets('displays NIP-05 when present', (tester) async {
      final testProfile = createTestProfile(
        displayName: 'Test User',
        nip05: 'test@example.com',
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,

          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets(
      'shows Complete your profile label for own profile without custom name',
      (tester) async {
        final profileWithDefaultName = createTestProfile();

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: profileWithDefaultName,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Complete your profile'), findsOneWidget);
      },
    );

    testWidgets('shows Complete your profile while profile is still loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profileIsLoading: true,
        ),
      );
      // Do not pumpAndSettle — provider never resolves
      await tester.pump();

      // No profile info available yet → prompt should show
      expect(find.text('Complete your profile'), findsOneWidget);
    });

    testWidgets('hides action label when profile has custom name', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Test User');

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete your profile'), findsNothing);
    });

    testWidgets('hides action label for other profiles', (tester) async {
      final profileWithDefaultName = createTestProfile();

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          profile: profileWithDefaultName,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete your profile'), findsNothing);
    });

    testWidgets(
      'renders fallback content for others profile with null profile',
      (tester) async {
        // With the classic Viners feature, profiles without Kind 0 events
        // can still be displayed using hint values as fallbacks
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: false,

            displayNameHint: 'Unknown',
            avatarUrlHint: 'https://example.com/fallback.png',
          ),
        );
        await tester.pumpAndSettle();

        // Should render with fallback/default avatar (not empty)
        expect(find.byType(ProfileHeaderWidget), findsOneWidget);
        expect(find.byType(UserAvatar), findsOneWidget);
      },
    );

    group('Expandable Bio', () {
      // Create a bio that will definitely exceed 3 lines on a phone screen
      // Using many short words to ensure wrapping at narrow widths
      final longBio = List.generate(
        20,
        (i) => 'This is line $i of the bio.',
      ).join(' ');

      testWidgets('short bio does not show "Show more" button', (tester) async {
        final testProfile = createTestProfile(
          displayName: 'Test User',
          about: 'Short bio',
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,

            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Short bio'), findsOneWidget);
        expect(find.text('Show more'), findsNothing);
        expect(find.text('Show less'), findsNothing);
      });

      testWidgets('long bio shows "Show more" button and truncates', (
        tester,
      ) async {
        // Set a phone-like screen size to ensure text wraps
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final testProfile = createTestProfile(
          displayName: 'Test User',
          about: longBio,
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,

            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Show more'), findsOneWidget);
        expect(find.text('Show less'), findsNothing);
      });

      testWidgets('tapping "Show more" expands bio and shows "Show less"', (
        tester,
      ) async {
        // Set a phone-like screen size to ensure text wraps
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final testProfile = createTestProfile(
          displayName: 'Test User',
          about: longBio,
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,

            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        // Tap "Show more"
        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();

        // Should now show "Show less"
        expect(find.text('Show less'), findsOneWidget);
        expect(find.text('Show more'), findsNothing);
      });

      testWidgets('tapping "Show less" collapses bio and shows "Show more"', (
        tester,
      ) async {
        // Use a taller viewport so expanded bio content stays in bounds
        tester.view.physicalSize = const Size(400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final testProfile = createTestProfile(
          displayName: 'Test User',
          about: longBio,
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        // First expand
        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();

        // Scroll down to reveal "Show less" if needed
        await tester.ensureVisible(find.text('Show less'));
        await tester.pumpAndSettle();

        // Then collapse
        await tester.tap(find.text('Show less'));
        await tester.pumpAndSettle();

        // Should be back to "Show more"
        expect(find.text('Show more'), findsOneWidget);
        expect(find.text('Show less'), findsNothing);
      });
    });

    group('Action Label', () {
      testWidgets('shows Secure label when anonymous with custom name', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Test User');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            isAnonymous: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Secure your account'), findsOneWidget);
        // 1 action — badge shows "1"
        expect(find.text('1'), findsOneWidget);
      });

      testWidgets(
        'shows Secure label with count badge when anonymous and no name',
        (tester) async {
          final profileWithDefaultName = createTestProfile();

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: profileWithDefaultName,
              isAnonymous: true,
            ),
          );
          await tester.pumpAndSettle();

          // Secure takes precedence
          expect(find.text('Secure your account'), findsOneWidget);
          // 2 actions — red badge with "2"
          expect(find.text('2'), findsOneWidget);
        },
      );

      testWidgets('hides label when not anonymous and has custom name', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Test User');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Secure your account'), findsNothing);
        expect(find.text('Complete your profile'), findsNothing);
      });

      testWidgets('hides label for other profiles even when anonymous', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Test User');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: false,
            profile: testProfile,
            isAnonymous: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Secure your account'), findsNothing);
      });

      testWidgets('tapping label opens actions bottom sheet', (tester) async {
        final profileWithDefaultName = createTestProfile();

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: profileWithDefaultName,
            isAnonymous: true,
          ),
        );
        await tester.pumpAndSettle();

        // Tap on the action label
        await tester.tap(find.text('Secure your account'));
        await tester.pumpAndSettle();

        // The bottom sheet should show the first action
        expect(find.text('Secure Your Account'), findsOneWidget);
        expect(find.text('Add Email & Password'), findsOneWidget);
        expect(find.text('Maybe Later'), findsOneWidget);
      });
    });

    group('Session Expired', () {
      testWidgets(
        'shows session expired bottom sheet when session is expired',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Test User');
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: testProfile,
              hasExpiredSession: true,
              sharedPreferences: prefs,
            ),
          );
          await tester.pumpAndSettle();

          // Bottom sheet shows session expired prompt (button copy sourced
          // from the existing profileSignInButton ARB key, which is "Sign in").
          // The action-button pill in the header also surfaces "Session
          // Expired" / "Sign in" / "Maybe Later" via the actions list, so
          // assert at least one of each — finding all three at the same time
          // confirms the sheet itself opened.
          expect(find.text('Session Expired'), findsWidgets);
          expect(find.text('Sign in'), findsWidgets);
          expect(find.text('Maybe Later'), findsWidgets);
        },
      );

      testWidgets(
        'does not show session expired sheet when dismissed within 30 days',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Test User');
          final dismissedAt = DateTime.now()
              .subtract(const Duration(days: 29))
              .millisecondsSinceEpoch;

          SharedPreferences.setMockInitialValues({
            '$_dismissedDivineLoginBannerPrefix$testUserHex': dismissedAt,
          });
          final prefs = await SharedPreferences.getInstance();

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: testProfile,
              hasExpiredSession: true,
              sharedPreferences: prefs,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Session Expired'), findsNothing);
        },
      );

      testWidgets(
        'shows secure account label for anonymous users with expired session',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Test User');
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: testProfile,
              isAnonymous: true,
              hasExpiredSession: true,
              sharedPreferences: prefs,
            ),
          );
          await tester.pumpAndSettle();

          // Anonymous users see the action label pill, not session expired
          expect(find.text('Secure your account'), findsOneWidget);
          expect(find.text('Session Expired'), findsNothing);
        },
      );
    });

    group('MyProfile state fallbacks (own profile)', () {
      testWidgets('reads profile from MyProfileLoaded', (tester) async {
        final loadedProfile = createTestProfile(
          displayName: 'Loaded User',
          about: 'Bio from MyProfileLoaded',
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            myProfileState: MyProfileLoaded(
              profile: loadedProfile,
              isFresh: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Loaded User'), findsOneWidget);
        expect(find.text('Bio from MyProfileLoaded'), findsOneWidget);
      });

      testWidgets('reads cached profile from MyProfileLoading', (tester) async {
        final cachedProfile = createTestProfile(
          displayName: 'Cached While Loading',
          about: 'Cached bio',
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            myProfileState: MyProfileLoading(profile: cachedProfile),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cached While Loading'), findsOneWidget);
        expect(find.text('Cached bio'), findsOneWidget);
      });

      testWidgets(
        'falls back to widget.profile when MyProfile state has no profile',
        (tester) async {
          // Bug fix: previously only MyProfileUpdated was read; with
          // MyProfileLoading(profile: null) the header rendered an empty
          // shell even though the parent already had a cached profile.
          final fallbackProfile = createTestProfile(
            displayName: 'From Widget Param',
            about: 'Parent-supplied bio',
          );

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              suppliedProfile: fallbackProfile,
              myProfileState: const MyProfileLoading(),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('From Widget Param'), findsOneWidget);
          expect(find.text('Parent-supplied bio'), findsOneWidget);
        },
      );
    });

    group('Profile content fade-in', () {
      // The fade-in AnimatedOpacity wraps the avatar/name/bio/stats column
      // and uses an 80ms duration. Other AnimatedOpacity widgets in the
      // subtree (e.g. action label pill at 150ms) are filtered out by
      // matching on duration.
      AnimatedOpacity readFadeOpacity(WidgetTester tester) {
        final matches = tester
            .widgetList<AnimatedOpacity>(
              find.descendant(
                of: find.byType(ProfileHeaderWidget),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .where((w) => w.duration == const Duration(milliseconds: 80))
            .toList();
        expect(
          matches,
          hasLength(1),
          reason: 'Expected exactly one fade-in AnimatedOpacity (80ms)',
        );
        return matches.single;
      }

      testWidgets('opens immediately when profile is already available', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Fade Target');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
          ),
        );

        // First frame — _profileVisible is still false, but profile is
        // non-null so the AnimatedOpacity opens at full opacity.
        final opacity = readFadeOpacity(tester);
        expect(opacity.opacity, equals(1.0));
        expect(opacity.duration, equals(const Duration(milliseconds: 80)));

        await tester.pumpAndSettle();
        expect(find.text('Fade Target'), findsOneWidget);
      });

      testWidgets(
        'stays visible once the post-frame callback flips _profileVisible',
        (tester) async {
          // Start without profile data — the post-frame callback should
          // still flip _profileVisible to true so the header reveals even
          // when the upstream state never carries a profile.
          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              myProfileState: const MyProfileInitial(),
            ),
          );

          // Pump enough frames for the post-frame callback to run.
          await tester.pump();
          await tester.pump();

          final opacity = readFadeOpacity(tester);
          expect(opacity.opacity, equals(1.0));
        },
      );
    });
  });

  group('buildProfileUrl', () {
    const testNpub =
        'npub10z98cqe5kehs5wfnax59vqzuyd7puhr2dyy0g5ha5kxc83h38yts0z3mgg';

    test('returns subdomain URL for divine.video NIP-05', () {
      expect(
        buildProfileUrl('_@thomassanders.divine.video', testNpub),
        equals('https://thomassanders.divine.video'),
      );
    });

    test('returns subdomain URL for user@subdomain.divine.video NIP-05', () {
      expect(
        buildProfileUrl('user@rabble.divine.video', testNpub),
        equals('https://rabble.divine.video'),
      );
    });

    test('returns npub profile URL for non-divine.video NIP-05', () {
      expect(
        buildProfileUrl('alice@example.com', testNpub),
        equals('https://divine.video/profile/$testNpub'),
      );
    });

    test('returns npub profile URL when NIP-05 is null', () {
      expect(
        buildProfileUrl(null, testNpub),
        equals('https://divine.video/profile/$testNpub'),
      );
    });

    test('returns npub profile URL when NIP-05 is empty', () {
      expect(
        buildProfileUrl('', testNpub),
        equals('https://divine.video/profile/$testNpub'),
      );
    });
  });
}
