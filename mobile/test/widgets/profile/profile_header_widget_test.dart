// ABOUTME: Tests for ProfileHeaderWidget
// ABOUTME: Verifies profile header displays avatar, stats, name, bio, and npub correctly

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/widgets/profile/profile_header_widget.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

// Mock for KeycastOAuth used by EmailVerificationCubit
class MockKeycastOAuth extends Mock implements KeycastOAuth {}

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
  MockAuthService({this.isAnonymousValue = false});

  final bool isAnonymousValue;

  @override
  bool get isAnonymous => isAnonymousValue;

  @override
  bool get isAuthenticated => true;

  @override
  String? get currentPublicKeyHex => testUserHex;

  @override
  Stream<AuthState> get authStateStream =>
      Stream.value(AuthState.authenticated);
}

const testUserHex =
    '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';

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
          if (displayName != null) 'display_name': displayName,
          if (name != null) 'name': name,
          if (about != null) 'about': about,
          if (picture != null) 'picture': picture,
          if (nip05 != null) 'nip05': nip05,
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

    ProfileStats createTestStats() {
      return ProfileStats(
        videoCount: 10,
        totalViews: 1000,
        totalLikes: 500,
        followers: 100,
        following: 50,
        lastUpdated: DateTime.now(),
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
      required AsyncValue<ProfileStats> profileStatsAsync,
      int videoCount = 10,
      UserProfile? profile,
      VoidCallback? onSetupProfile,
      bool isAnonymous = false,
      String? displayNameHint,
      String? avatarUrlHint,
    }) {
      final authService = MockAuthService(isAnonymousValue: isAnonymous);
      final mockUserProfileService = createMockUserProfileService();
      return ProviderScope(
        overrides: [
          // Pass test's mock so we don't duplicate nostrServiceProvider override
          ...getStandardTestOverrides(
            mockNostrService: mockNostrClient,
            mockUserProfileService: mockUserProfileService,
          ),
          fetchUserProfileProvider(
            userIdHex,
          ).overrideWith((ref) async => profile),
          followRepositoryProvider.overrideWithValue(mockFollowRepository),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWith(
            (ref) => AuthState.authenticated,
          ),
        ],
        child: BlocProvider<EmailVerificationCubit>(
          create: (_) => EmailVerificationCubit(
            oauthClient: MockKeycastOAuth(),
            authService: authService,
          ),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileHeaderWidget(
                  userIdHex: userIdHex,
                  isOwnProfile: isOwnProfile,
                  videoCount: videoCount,
                  profileStatsAsync: profileStatsAsync,
                  onSetupProfile: onSetupProfile,
                  displayNameHint: displayNameHint,
                  avatarUrlHint: avatarUrlHint,
                ),
              ),
            ),
          ),
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
          profileStatsAsync: AsyncValue.data(createTestStats()),
          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatar), findsOneWidget);
    });

    testWidgets('displays all three stat columns', (tester) async {
      final testProfile = createTestProfile(displayName: 'Test User');

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profileStatsAsync: AsyncValue.data(createTestStats()),
          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
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
          profileStatsAsync: AsyncValue.data(createTestStats()),
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
          profileStatsAsync: AsyncValue.data(createTestStats()),
          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('shows setup banner for own profile without custom name', (
      tester,
    ) async {
      var setupCalled = false;
      final profileWithDefaultName = createTestProfile();

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profileStatsAsync: AsyncValue.data(createTestStats()),
          profile: profileWithDefaultName,
          onSetupProfile: () => setupCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete Your Profile'), findsOneWidget);
      expect(find.text('Set Up'), findsOneWidget);

      await tester.tap(find.text('Set Up'));
      await tester.pump();

      expect(setupCalled, isTrue);
    });

    testWidgets('hides setup banner when profile has custom name', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Test User');

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profileStatsAsync: AsyncValue.data(createTestStats()),
          profile: testProfile,
          onSetupProfile: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete Your Profile'), findsNothing);
    });

    testWidgets('hides setup banner for other profiles', (tester) async {
      final profileWithDefaultName = createTestProfile();

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          profileStatsAsync: AsyncValue.data(createTestStats()),
          profile: profileWithDefaultName,
          onSetupProfile: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete Your Profile'), findsNothing);
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
            profileStatsAsync: AsyncValue.data(createTestStats()),
            profile: null,
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
            profileStatsAsync: AsyncValue.data(createTestStats()),
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
            profileStatsAsync: AsyncValue.data(createTestStats()),
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
            profileStatsAsync: AsyncValue.data(createTestStats()),
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
            profileStatsAsync: AsyncValue.data(createTestStats()),
            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        // First expand
        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();

        // Then collapse
        await tester.tap(find.text('Show less'));
        await tester.pumpAndSettle();

        // Should be back to "Show more"
        expect(find.text('Show more'), findsOneWidget);
        expect(find.text('Show less'), findsNothing);
      });
    });

    group('Secure Account Banner', () {
      testWidgets(
        'shows secure account banner for own profile when anonymous',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Test User');

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profileStatsAsync: AsyncValue.data(createTestStats()),
              profile: testProfile,
              isAnonymous: true,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Secure Your Account'), findsOneWidget);
          expect(find.text('Register'), findsOneWidget);
          expect(
            find.text(
              'Add email & password to recover your account on any device',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'hides secure account banner for own profile when not anonymous',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Test User');

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profileStatsAsync: AsyncValue.data(createTestStats()),
              profile: testProfile,
              isAnonymous: false,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Secure Your Account'), findsNothing);
        },
      );

      testWidgets(
        'hides secure account banner for other profiles even when anonymous',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Test User');

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: false,
              profileStatsAsync: AsyncValue.data(createTestStats()),
              profile: testProfile,
              isAnonymous: true,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Secure Your Account'), findsNothing);
        },
      );

      testWidgets('secure account banner Register button is tappable', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Test User');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profileStatsAsync: AsyncValue.data(createTestStats()),
            profile: testProfile,
            isAnonymous: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Secure Your Account'), findsOneWidget);

        // Verify Register button exists and is an ElevatedButton
        final registerButton = find.widgetWithText(ElevatedButton, 'Register');
        expect(registerButton, findsOneWidget);

        // Verify the button has correct styling
        final button = tester.widget<ElevatedButton>(registerButton);
        expect(button.onPressed, isNotNull);
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
