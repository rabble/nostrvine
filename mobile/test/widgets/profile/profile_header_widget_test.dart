// ABOUTME: Tests for ProfileHeaderWidget
// ABOUTME: Verifies profile header displays avatar, stats, name, bio, and npub correctly

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cache_sync/cache_sync.dart';
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
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/people_list_membership_indicator.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/widgets/profile/profile_action_buttons_widget.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockMyProfileBloc extends MockBloc<MyProfileEvent, MyProfileState>
    implements MyProfileBloc {}

class _MockOthersFollowersBloc
    extends MockBloc<OthersFollowersEvent, OthersFollowersState>
    implements OthersFollowersBloc {}

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

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
  Stream<FollowersSnapshot> watchMyFollowers() {
    return Stream.value(const FollowersSnapshot(pubkeys: <String>[], count: 0));
  }

  @override
  Stream<CacheResult<FollowingSnapshot>> watchMyFollowingCached({
    bool forceRefresh = false,
  }) {
    return Stream.value(
      const CacheResult.live(FollowingSnapshot(pubkeys: <String>[], count: 0)),
    );
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

class _FakeCacheDao implements CacheDao {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<int> totalPayloadBytes() async => 0;

  @override
  Future<void> evictOldest(int bytesToFree) async {}
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

    setUp(() async {
      mockFollowRepository = MockFollowRepository();
      mockNostrClient = MockNostrClient();
      await CacheSync.init(dao: _FakeCacheDao());
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
      bool curatedListsEnabled = false,
      PeopleListsState? peopleListsState,
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
        final mockPeopleListsBloc = _MockPeopleListsBloc();
        whenListen(
          mockPeopleListsBloc,
          const Stream<PeopleListsState>.empty(),
          initialState: peopleListsState ?? const PeopleListsState(),
        );
        header = MultiBlocProvider(
          providers: [
            BlocProvider<OthersFollowersBloc>.value(
              value: mockOthersFollowersBloc,
            ),
            BlocProvider<PeopleListsBloc>.value(value: mockPeopleListsBloc),
          ],
          child: header,
        );
      }

      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(
            mockNostrService: mockNostrClient,
            mockSharedPreferences: sharedPreferences,
            mockNip05VerificationService: createMockNip05VerificationService(),
            mockFollowRepository: mockFollowRepository,
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
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWith(
            (ref) => AuthState.authenticated,
          ),
          isFeatureEnabledProvider(
            FeatureFlag.curatedLists,
          ).overrideWith((ref) => curatedListsEnabled),
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

    testWidgets('avatar lightbox seeds placeholder with the pubkey so the '
        'fallback colour matches the rest of the app when the image fails', (
      tester,
    ) async {
      final testProfile = createTestProfile(
        displayName: 'Test User',
        picture: 'https://example.com/broken.jpg',
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      // Only the header avatar is in the tree before the lightbox opens.
      expect(find.byType(UserAvatar), findsOneWidget);

      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();

      // After opening, the lightbox adds a second UserAvatar at size 288.
      final lightboxAvatar = tester
          .widgetList<UserAvatar>(find.byType(UserAvatar))
          .firstWhere((avatar) => avatar.size == 288);
      expect(lightboxAvatar.placeholderSeed, equals(testUserHex));
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

    testWidgets(
      'keeps all stat columns visible with em-dash placeholders once the '
      'skeleton timeout expires and profileStats is still null',
      (tester) async {
        final testProfile = createTestProfile(displayName: 'Test User');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
          ),
        );
        // Advance past the 7-second skeleton timeout, then settle any
        // remaining switch animations.
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();

        // All four labels stay in the tree; counts fall back to '—'.
        expect(find.text('Followers'), findsOneWidget);
        expect(find.text('Following'), findsOneWidget);
        expect(find.text('Likes'), findsOneWidget);
        expect(find.text('Loops'), findsOneWidget);
        expect(find.text('—'), findsNWidgets(4));

        // Stats Skeletonizer (the closest one above a stat label) must
        // be disabled after timeout — data is shown as-is.
        // bySubtype is required because Skeletonizer is abstract; the
        // concrete widget in the tree is the private _Skeletonizer subclass.
        final s = tester.widget<Skeletonizer>(
          find
              .ancestor(
                of: find.text('Followers'),
                matching: find.bySubtype<Skeletonizer>(),
              )
              .first,
        );
        expect(s.enabled, isFalse);
      },
    );

    group('Stats row skeleton timeout', () {
      testWidgets(
        'shows placeholder columns as skeleton while profileStats is null before timeout',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Test User');

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: testProfile,
              // profileStats deliberately omitted (null)
            ),
          );
          // One frame only — the 7-second skeleton timer has not fired yet.
          await tester.pump();

          // All four column labels are in the tree, rendered as skeletons.
          expect(find.text('Followers'), findsOneWidget);
          expect(find.text('Following'), findsOneWidget);
          expect(find.text('Likes'), findsOneWidget);
          expect(find.text('Loops'), findsOneWidget);

          // Stats Skeletonizer (the closest one above a stat label) must
          // be active — not just present in the tree.
          // bySubtype is required because Skeletonizer is abstract; the
          // concrete widget in the tree is the private _Skeletonizer subclass.
          final s = tester.widget<Skeletonizer>(
            find
                .ancestor(
                  of: find.text('Followers'),
                  matching: find.bySubtype<Skeletonizer>(),
                )
                .first,
          );
          expect(s.enabled, isTrue);
        },
      );

      testWidgets(
        'stat columns remain visible once profileStats arrives before timeout',
        (tester) async {
          const stats = ProfileStats(
            pubkey: testUserHex,
            totalLikes: 10,
            totalViews: 20,
          );

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: createTestProfile(displayName: 'Test User'),
              profileStats: stats,
            ),
          );
          await tester.pumpAndSettle();

          // Actual data shown — no timeout was needed.
          expect(find.text('Loops'), findsOneWidget);
          expect(find.text('Likes'), findsOneWidget);
        },
      );
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

    testWidgets('hides action label while profile is still loading', (
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

      // Action label is replaced with SizedBox.shrink() during the loading
      // window so the prompt doesn't flicker between states (#4183 review).
      expect(find.text('Complete your profile'), findsNothing);
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

    testWidgets('renders PeopleListMembershipIndicator for other users', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Other User');

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: testProfile,
          curatedListsEnabled: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PeopleListMembershipIndicator), findsOneWidget);
    });

    testWidgets(
      'does not render PeopleListMembershipIndicator for own profile',
      (tester) async {
        final testProfile = createTestProfile(displayName: 'Self');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            curatedListsEnabled: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PeopleListMembershipIndicator), findsNothing);
      },
    );

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

    group('Identity skeleton (#4163)', () {
      // Asserts the wiring contract from `_ProfileHeaderWidgetState.build`:
      // when the profile is still loading and there is no cached fallback,
      // the avatar + name/bio block is wrapped in an enabled Skeletonizer.
      // Static chrome (stats row, action buttons, people-list pill) sits
      // OUTSIDE the identity Skeletonizer so it stays both visible and
      // interactive during the loading window — pinned at the end of this
      // group.
      //
      // The header subtree always contains 2 Skeletonizers at runtime: the
      // identity one (over avatar + name/bio) and the stats one (inside
      // _ProfileStatsRow, gated on profileStats == null). The identity
      // Skeletonizer is the first one encountered in widget order.

      Skeletonizer findIdentitySkeletonizer(WidgetTester tester) {
        final matches = tester
            .widgetList<Skeletonizer>(
              find.descendant(
                of: find.byType(ProfileHeaderWidget),
                matching: find.bySubtype<Skeletonizer>(),
              ),
            )
            .toList();
        expect(
          matches,
          isNotEmpty,
          reason: 'Expected at least one Skeletonizer in the header subtree',
        );
        return matches.first;
      }

      testWidgets(
        'own profile + MyProfileInitial → Skeletonizer.enabled = true',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              myProfileState: const MyProfileInitial(),
            ),
          );
          await tester.pump();

          expect(findIdentitySkeletonizer(tester).enabled, isTrue);
        },
      );

      testWidgets('own profile + MyProfileLoading(profile: null) → '
          'Skeletonizer.enabled = true', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            myProfileState: const MyProfileLoading(),
          ),
        );
        await tester.pump();

        expect(findIdentitySkeletonizer(tester).enabled, isTrue);
      });

      testWidgets(
        'own profile + MyProfileLoading(profile: cached) → '
        'Skeletonizer.enabled = false (we have data to show, do not skeleton)',
        (tester) async {
          final cached = createTestProfile(displayName: 'Cached Display Name');

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              myProfileState: MyProfileLoading(profile: cached),
            ),
          );
          await tester.pump();

          expect(findIdentitySkeletonizer(tester).enabled, isFalse);
        },
      );

      testWidgets(
        'own profile + MyProfileError(notFound) → Skeletonizer.enabled = false '
        '(steady-state generated fallback path is preserved)',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              myProfileState: const MyProfileError(
                errorType: MyProfileErrorType.notFound,
              ),
            ),
          );
          await tester.pump();

          expect(findIdentitySkeletonizer(tester).enabled, isFalse);
        },
      );

      testWidgets(
        'own profile + MyProfileLoaded(profile) → Skeletonizer.enabled = false',
        (tester) async {
          final loaded = createTestProfile(displayName: 'Loaded Display Name');

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              myProfileState: MyProfileLoaded(profile: loaded, isFresh: true),
            ),
          );
          await tester.pump();

          expect(findIdentitySkeletonizer(tester).enabled, isFalse);
        },
      );

      testWidgets('other profile + suppliedProfile non-null → '
          'Skeletonizer.enabled = false (caller already has data)', (
        tester,
      ) async {
        final supplied = createTestProfile(displayName: 'Bob');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: false,
            suppliedProfile: supplied,
          ),
        );
        await tester.pump();

        expect(findIdentitySkeletonizer(tester).enabled, isFalse);
      });

      testWidgets(
        'skeleton dissolves to fallback after the 7s timeout — even when '
        'the parent still says loading',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              myProfileState: const MyProfileInitial(),
            ),
          );
          await tester.pump();

          // Before timeout — Skeletonizer is enabled.
          expect(findIdentitySkeletonizer(tester).enabled, isTrue);

          // Advance past the 7-second skeleton timeout (mirrors the
          // pattern used by _ProfileStatsRow's existing test).
          await tester.pump(const Duration(seconds: 8));
          await tester.pumpAndSettle();

          // After timeout — Skeletonizer flips back to disabled even
          // though the bloc is still in an initial state. This is what
          // lets users who genuinely have no Kind 0 still see the
          // generated-name fallback rather than an infinite shimmer.
          expect(findIdentitySkeletonizer(tester).enabled, isFalse);
        },
      );

      testWidgets('stats row and action buttons sit outside the identity '
          'Skeletonizer so they stay tappable during the loading window', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            myProfileState: const MyProfileInitial(),
          ),
        );
        await tester.pump();

        // The identity Skeletonizer is the first descendant of the
        // header. Anything that should stay interactive during the
        // loading window must NOT be a descendant of it.
        final identitySkeletonizer = find
            .descendant(
              of: find.byType(ProfileHeaderWidget),
              matching: find.bySubtype<Skeletonizer>(),
            )
            .first;

        expect(
          find.descendant(
            of: identitySkeletonizer,
            matching: find.byType(ProfileActionButtons),
          ),
          findsNothing,
          reason:
              'ProfileActionButtons (Library/edit/share) must live outside '
              'the identity Skeletonizer so the buttons remain tappable '
              'during the loading window (#4183 review).',
        );

        // _ProfileStatsRow is private; the stat columns it renders are
        // the proxy. Their location relative to the identity skeleton
        // is what matters.
        expect(
          find.descendant(
            of: identitySkeletonizer,
            matching: find.byType(ProfileStatColumn),
          ),
          findsNothing,
          reason:
              'Stats columns must live outside the identity Skeletonizer '
              'so the followers/following/likes/loops counts remain '
              'tappable during the loading window (#4183 review).',
        );
      });
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
