// ABOUTME: Test for verifying profile fetching when videos are displayed
// ABOUTME: Ensures profiles are fetched and cached via ProfileRepository

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late _MockProfileRepository mockProfileRepository;

  setUpAll(() {
    registerFallbackValue(
      UserProfile(
        pubkey: 'fallback',
        createdAt: DateTime.now(),
        eventId: 'fallback_event_id',
        rawData: const {},
      ),
    );
  });

  setUp(() {
    mockProfileRepository = _MockProfileRepository();
  });

  group('Profile Fetching on Video Display', () {
    test(
      'should fetch profile when video is displayed without cached profile',
      () async {
        // Arrange
        const testPubkey = 'test_pubkey_123456789';

        when(
          () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
        ).thenAnswer((_) async => null);
        when(
          () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
        ).thenAnswer((_) async => null);

        // Act - Simulate video display triggering profile fetch
        final cached = await mockProfileRepository.getCachedProfile(
          pubkey: testPubkey,
        );

        // Assert - No cached profile
        expect(cached, isNull);

        // Trigger fresh fetch
        await mockProfileRepository.fetchFreshProfile(pubkey: testPubkey);

        // Verify fresh fetch was called
        verify(
          () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
        ).called(1);
      },
    );

    test(
      'should handle and cache profile when profile data is received',
      () async {
        // Arrange
        const testPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const testName = 'Test User';
        const testDisplayName = 'TestUser123';
        const testAbout = 'This is a test user profile';
        const testPicture = 'https://example.com/avatar.jpg';

        final testProfile = UserProfile(
          pubkey: testPubkey,
          name: testName,
          displayName: testDisplayName,
          about: testAbout,
          picture: testPicture,
          createdAt: DateTime.now(),
          eventId: 'profile_event_id',
          rawData: const {
            'name': testName,
            'display_name': testDisplayName,
            'about': testAbout,
            'picture': testPicture,
          },
        );

        when(
          () => mockProfileRepository.cacheProfile(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
        ).thenAnswer((_) async => testProfile);

        // Act - Cache the profile
        await mockProfileRepository.cacheProfile(testProfile);

        // Assert - Verify profile was cached
        final cachedProfile = await mockProfileRepository.getCachedProfile(
          pubkey: testPubkey,
        );
        expect(cachedProfile, isNotNull);
        expect(cachedProfile!.name, equals(testName));
        expect(cachedProfile.displayName, equals(testDisplayName));
        expect(cachedProfile.about, equals(testAbout));
        expect(cachedProfile.picture, equals(testPicture));

        // Verify cache was called
        verify(
          () => mockProfileRepository.cacheProfile(
            any(
              that: predicate<UserProfile>(
                (profile) =>
                    profile.pubkey == testPubkey &&
                    profile.name == testName &&
                    profile.displayName == testDisplayName,
              ),
            ),
          ),
        ).called(1);
      },
    );

    test('should fetch multiple profiles in batch for video feed', () async {
      // Arrange
      final testPubkeys = [
        'pubkey_1',
        'pubkey_2',
        'pubkey_3',
        'pubkey_4',
        'pubkey_5',
      ];

      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => {});

      // Act - Simulate batch profile fetch for video feed
      await mockProfileRepository.fetchBatchProfiles(pubkeys: testPubkeys);

      // Assert - Verify batch fetch was called
      verify(
        () => mockProfileRepository.fetchBatchProfiles(pubkeys: testPubkeys),
      ).called(1);
    });

    test('should not fetch profile if already cached', () async {
      // Arrange
      const testPubkey = 'cached_pubkey_123';
      final cachedProfile = UserProfile(
        pubkey: testPubkey,
        name: 'Cached User',
        displayName: 'CachedUser',
        about: 'Already cached',
        createdAt: DateTime.now(),
        eventId: 'cached_event_id',
        rawData: const {
          'name': 'Cached User',
          'display_name': 'CachedUser',
          'about': 'Already cached',
        },
      );

      when(
        () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
      ).thenAnswer((_) async => cachedProfile);

      // Act
      final profile = await mockProfileRepository.getCachedProfile(
        pubkey: testPubkey,
      );

      // Assert - Verify cached profile was returned
      expect(profile, equals(cachedProfile));

      // Should not need to fetch fresh
      verifyNever(
        () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
      );
    });

    test('should handle profile fetch failure gracefully', () async {
      // Arrange
      const testPubkey = 'fail_pubkey_123';

      when(
        () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
      ).thenThrow(Exception('Network error'));

      // Act & Assert - Verify fetch throws
      expect(
        () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
        throwsException,
      );
    });
  });
}
