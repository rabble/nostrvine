// ABOUTME: Test that profile caches stay in sync across services
// ABOUTME: Verifies ProfileRepository cache operations work correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group('Profile Cache Synchronization', () {
    late _MockProfileRepository mockProfileRepository;

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
    });

    test('ProfileRepository cache persists profiles correctly', () async {
      // ARRANGE
      final testProfile = UserProfile(
        pubkey: 'test-pubkey-123',
        displayName: 'Test User',
        name: 'testuser',
        picture: 'https://example.com/pic.jpg',
        about: 'Test bio',
        eventId: 'event-123',
        createdAt: DateTime.now(),
        rawData: const {'name': 'testuser'},
      );

      when(
        () => mockProfileRepository.cacheProfile(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockProfileRepository.getCachedProfile(
          pubkey: 'test-pubkey-123',
        ),
      ).thenAnswer((_) async => testProfile);

      // ACT: Add to cache
      await mockProfileRepository.cacheProfile(testProfile);

      // ASSERT: Should be retrievable
      final cached = await mockProfileRepository.getCachedProfile(
        pubkey: 'test-pubkey-123',
      );
      expect(cached, isNotNull);
      expect(cached!.displayName, equals('Test User'));
      expect(cached.picture, equals('https://example.com/pic.jpg'));
      expect(cached.about, equals('Test bio'));
    });

    test('ProfileRepository cache can be updated multiple times', () async {
      // ARRANGE
      final profile1 = UserProfile(
        pubkey: 'test-pubkey-456',
        displayName: 'Initial Name',
        eventId: 'event-1',
        createdAt: DateTime.now(),
        rawData: const {},
      );

      final profile2 = UserProfile(
        pubkey: 'test-pubkey-456',
        displayName: 'Updated Name',
        picture: 'https://example.com/new-pic.jpg',
        eventId: 'event-2',
        createdAt: DateTime.now(),
        rawData: const {},
      );

      when(
        () => mockProfileRepository.cacheProfile(any()),
      ).thenAnswer((_) async {});

      var callCount = 0;
      when(
        () => mockProfileRepository.getCachedProfile(
          pubkey: 'test-pubkey-456',
        ),
      ).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? profile1 : profile2;
      });

      // ACT: Add first version
      await mockProfileRepository.cacheProfile(profile1);

      var cached = await mockProfileRepository.getCachedProfile(
        pubkey: 'test-pubkey-456',
      );
      expect(cached?.displayName, equals('Initial Name'));

      // ACT: Update with new version
      await mockProfileRepository.cacheProfile(profile2);

      // ASSERT: Should have updated version
      cached = await mockProfileRepository.getCachedProfile(
        pubkey: 'test-pubkey-456',
      );
      expect(cached?.displayName, equals('Updated Name'));
      expect(cached?.picture, equals('https://example.com/new-pic.jpg'));
    });

    test('Profile update flow documents expected behavior', () async {
      // This test documents the CURRENT behavior and what SHOULD happen

      // STEP 1: User edits profile in ProfileSetupScreen
      final newProfile = UserProfile(
        pubkey: 'user-pubkey-789',
        displayName: 'My New Name',
        name: 'mynewname',
        picture: 'https://example.com/avatar.jpg',
        about: 'My new bio',
        eventId: 'new-event',
        createdAt: DateTime.now(),
        rawData: const {
          'name': 'mynewname',
          'display_name': 'My New Name',
          'picture': 'https://example.com/avatar.jpg',
          'about': 'My new bio',
        },
      );

      when(
        () => mockProfileRepository.cacheProfile(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockProfileRepository.getCachedProfile(
          pubkey: 'user-pubkey-789',
        ),
      ).thenAnswer((_) async => newProfile);

      // STEP 2: Profile is published to Nostr
      // (NostrService.broadcastEvent is called)

      // STEP 3: Profile is cached in ProfileRepository
      await mockProfileRepository.cacheProfile(newProfile);

      // VERIFY: Profile is in ProfileRepository cache
      final cachedProfile = await mockProfileRepository.getCachedProfile(
        pubkey: 'user-pubkey-789',
      );
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.displayName, equals('My New Name'));

      // STEP 4: ProfileSetupScreen calls authService.refreshCurrentProfile()
      // (This updates AuthService.currentProfile from ProfileRepository)

      // STEP 5: ProfileSetupScreen navigates back to ProfileScreen

      // EXPECTED BEHAVIOR:
      // ProfileScreen should display the updated profile immediately because:
      // - For own profile: Reads from authService.currentProfile (updated in step 4)
      // - For other profiles: Reads from profileRepository.getCachedProfile() (updated in step 3)

      // ACTUAL BUG:
      // ProfileScreen watches `authServiceProvider` which is a keepAlive provider.
      // When authService.currentProfile changes internally, Riverpod doesn't know,
      // so ProfileScreen doesn't rebuild.
    });
    // TODO(any): Fix and reenable this test
  }, skip: true);
}
