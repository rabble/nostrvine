// ABOUTME: Tests for ProfileHeaderWidget
// ABOUTME: Verifies profile header displays avatar, stats, name, bio, and npub correctly

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

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
      UserProfile? profile,
      VoidCallback? onSetupProfile,
    }) {
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          fetchUserProfileProvider(
            userIdHex,
          ).overrideWith((ref) async => profile),
          followRepositoryProvider.overrideWithValue(mockFollowRepository),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileHeaderWidget(
                userIdHex: userIdHex,
                isOwnProfile: isOwnProfile,
                profileStatsAsync: profileStatsAsync,
                onSetupProfile: onSetupProfile,
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

    testWidgets('returns empty widget for others profile with null profile', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          profileStatsAsync: AsyncValue.data(createTestStats()),
          profile: null,
        ),
      );
      await tester.pumpAndSettle();

      // Should render SizedBox.shrink() - no UserAvatar visible
      expect(find.byType(ProfileHeaderWidget), findsOneWidget);
      expect(find.byType(UserAvatar), findsNothing);
    });
  });
}
