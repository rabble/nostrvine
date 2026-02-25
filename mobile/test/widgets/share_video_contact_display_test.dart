// ABOUTME: Tests for contact display in SendToUserDialog
// ABOUTME: Verifies npub/nip05 is shown instead of raw hex pubkey

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mocktail/mocktail.dart' as mocktail;
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/widgets/send_to_user_dialog.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:rxdart/rxdart.dart';

import '../helpers/test_provider_overrides.dart';
import '../helpers/test_provider_overrides.mocks.dart';

/// Mocktail mock for FollowRepository
class _MockFollowRepository extends mocktail.Mock implements FollowRepository {}

/// Mocktail mock for ProfileRepository
class _MockProfileRepository extends mocktail.Mock
    implements ProfileRepository {}

/// Creates a mock FollowRepository with the given following pubkeys
_MockFollowRepository _createMockFollowRepository(
  List<String> followingPubkeys,
) {
  final mock = _MockFollowRepository();
  mocktail.when(() => mock.followingPubkeys).thenReturn(followingPubkeys);
  mocktail
      .when(() => mock.followingStream)
      .thenAnswer(
        (_) => BehaviorSubject<List<String>>.seeded(followingPubkeys).stream,
      );
  mocktail.when(() => mock.isInitialized).thenReturn(true);
  mocktail.when(() => mock.followingCount).thenReturn(followingPubkeys.length);
  return mock;
}

void main() {
  group('SendToUserDialog Contact Display', () {
    late MockUserProfileService mockUserProfileService;
    late _MockFollowRepository mockFollowRepository;
    late _MockProfileRepository mockProfileRepository;

    final testVideo = VideoEvent(
      id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      pubkey:
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      content: 'Test video',
      timestamp: DateTime.now(),
      title: 'Test',
      videoUrl: 'https://example.com/video.mp4',
    );

    final testPubkey =
        '2646f4c01362b3b48d4b4e31d9c96a4eabe06c4eb971e1a482ef651f1bf023b7';

    setUp(() {
      mockUserProfileService = createMockUserProfileService();
      mockFollowRepository = _createMockFollowRepository([testPubkey]);
      mockProfileRepository = _MockProfileRepository();
    });

    Widget buildSubject() => testProviderScope(
      mockUserProfileService: mockUserProfileService,
      additionalOverrides: [
        followRepositoryProvider.overrideWithValue(mockFollowRepository),
        profileRepositoryProvider.overrideWithValue(mockProfileRepository),
      ],
      child: MaterialApp(
        home: Scaffold(body: SendToUserDialog(video: testVideo)),
      ),
    );

    testWidgets('shows npub instead of raw hex', (tester) async {
      final testProfile = UserProfile(
        pubkey: testPubkey,
        displayName: 'Test User',
        name: 'testuser',
        about: null,
        picture: null,
        banner: null,
        website: null,
        nip05: null,
        lud16: null,
        lud06: null,
        createdAt: DateTime.now(),
        eventId: 'profile-event-id',
        rawData: {},
      );

      when(mockUserProfileService.hasProfile(testPubkey)).thenReturn(true);
      when(
        mockUserProfileService.getCachedProfile(testPubkey),
      ).thenReturn(testProfile);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify contact list loads
      expect(find.text('Your Contacts'), findsOneWidget);

      // CRITICAL: Verify raw hex is NOT shown
      expect(find.textContaining(testPubkey), findsNothing);

      // CRITICAL: Verify npub format IS shown (starts with npub1)
      expect(find.textContaining('npub1'), findsOneWidget);
    });

    testWidgets('shows nip05 when available', (tester) async {
      final testProfile = UserProfile(
        pubkey: testPubkey,
        displayName: 'Test User',
        name: 'testuser',
        about: null,
        picture: null,
        banner: null,
        website: null,
        nip05: 'testuser@example.com',
        lud16: null,
        lud06: null,
        createdAt: DateTime.now(),
        eventId: 'profile-event-id',
        rawData: {},
      );

      when(mockUserProfileService.hasProfile(testPubkey)).thenReturn(true);
      when(
        mockUserProfileService.getCachedProfile(testPubkey),
      ).thenReturn(testProfile);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify contact list loads
      expect(find.text('Your Contacts'), findsOneWidget);

      // CRITICAL: Verify nip05 is shown (preferred over npub)
      expect(find.text('testuser@example.com'), findsOneWidget);

      // CRITICAL: Verify raw hex is NOT shown
      expect(find.textContaining(testPubkey), findsNothing);
    });

    testWidgets('shows npub fallback when no profile data', (tester) async {
      when(mockUserProfileService.hasProfile(testPubkey)).thenReturn(false);
      when(
        mockUserProfileService.getCachedProfile(testPubkey),
      ).thenReturn(null);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // CRITICAL: Even without profile data, npub is shown, not raw hex
      expect(find.textContaining('npub1'), findsWidgets);
      expect(find.textContaining(testPubkey), findsNothing);
    });

    testWidgets('renders search and message fields', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify dialog title
      expect(find.text('Share with user'), findsOneWidget);

      // Verify search field
      expect(
        find.widgetWithText(TextField, 'Search by name, npub, or pubkey...'),
        findsOneWidget,
      );

      // Verify message field
      expect(
        find.widgetWithText(TextField, 'Add a personal message (optional)'),
        findsOneWidget,
      );
    });
  });
}
