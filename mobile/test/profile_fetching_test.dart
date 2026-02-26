// ABOUTME: Test for verifying profile fetching when videos are displayed
// ABOUTME: Ensures Kind 0 events are fetched and cached when viewing videos

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/profile_cache_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/user_profile_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

class _MockProfileCacheService extends Mock implements ProfileCacheService {}

void main() {
  late UserProfileService profileService;
  late _MockNostrClient mockNostrService;
  late _MockSubscriptionManager mockSubscriptionManager;
  late _MockProfileCacheService mockCacheService;

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
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
    mockNostrService = _MockNostrClient();
    mockSubscriptionManager = _MockSubscriptionManager();
    mockCacheService = _MockProfileCacheService();

    // Set up default mock behaviors
    when(() => mockNostrService.isInitialized).thenReturn(true);
    when(() => mockCacheService.isInitialized).thenReturn(true);
    when(() => mockCacheService.getCachedProfile(any())).thenReturn(null);
    when(() => mockCacheService.shouldRefreshProfile(any())).thenReturn(false);

    profileService = UserProfileService(
      mockNostrService,
      subscriptionManager: mockSubscriptionManager,
      skipIndexerFallback: true, // Avoid real WebSocket in tests
    );
    profileService.setPersistentCache(mockCacheService);
  });

  group('Profile Fetching on Video Display', () {
    test(
      'should fetch profile when video is displayed without cached profile',
      () async {
        // Arrange
        const testPubkey = 'test_pubkey_123456789';
        const testSubscriptionId = 'sub_123';

        // Mock subscription creation
        when(
          () => mockSubscriptionManager.createSubscription(
            name: any(named: 'name'),
            filters: any(named: 'filters'),
            onEvent: any(named: 'onEvent'),
            onError: any(named: 'onError'),
            onComplete: any(named: 'onComplete'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((_) async => testSubscriptionId);

        // Act - Simulate video display triggering profile fetch
        await profileService.initialize();
        // fetchProfile adds the pubkey to a batch queue with a 100ms debounce
        profileService.fetchProfile(testPubkey);

        // Wait for the debounce timer to fire and execute the batch fetch
        await Future.delayed(const Duration(milliseconds: 200));

        // Assert - Verify a batch subscription was created for Kind 0 event
        verify(
          () => mockSubscriptionManager.createSubscription(
            name: any(that: contains('profile'), named: 'name'),
            filters: any(
              that: predicate<List<Filter>>((filters) {
                if (filters.isEmpty) return false;
                final filter = filters.first;
                return filter.kinds!.contains(0) &&
                    filter.authors!.contains(testPubkey);
              }),
              named: 'filters',
            ),
            onEvent: any(named: 'onEvent'),
            onError: any(named: 'onError'),
            onComplete: any(named: 'onComplete'),
            priority: any(named: 'priority'),
          ),
        ).called(1);

        // Verify profile is not yet available (batch fetch hasn't completed)
        expect(profileService.hasProfile(testPubkey), isFalse);
      },
    );

    test(
      'should handle and cache profile when Kind 0 event is received',
      () async {
        // Arrange
        const testPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; // Valid 64-char hex pubkey
        const testName = 'Test User';
        const testDisplayName = 'TestUser123';
        const testAbout = 'This is a test user profile';
        const testPicture = 'https://example.com/avatar.jpg';

        // Create Kind 0 profile event
        final profileContent = jsonEncode({
          'name': testName,
          'display_name': testDisplayName,
          'about': testAbout,
          'picture': testPicture,
        });

        final profileEvent = Event(
          testPubkey,
          0, // kind
          [], // tags
          profileContent,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        // Set the id and sig manually since they're calculated fields
        profileEvent.id = 'profile_event_id';
        profileEvent.sig = 'profile_sig';

        // Act - Process the profile event
        await profileService.initialize();
        profileService.handleProfileEventForTesting(profileEvent);

        // Assert - Verify profile was cached
        final cachedProfile = profileService.getCachedProfile(testPubkey);
        expect(cachedProfile, isNotNull);
        expect(cachedProfile!.name, equals(testName));
        expect(cachedProfile.displayName, equals(testDisplayName));
        expect(cachedProfile.about, equals(testAbout));
        expect(cachedProfile.picture, equals(testPicture));
        expect(cachedProfile.bestDisplayName, equals(testDisplayName));

        // Verify persistent cache was updated
        verify(
          () => mockCacheService.cacheProfile(
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
      const testSubscriptionId = 'batch_sub_123';

      // Mock subscription creation for batch
      when(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((_) async => testSubscriptionId);

      // Act - Simulate batch profile fetch for video feed
      await profileService.initialize();
      await profileService.fetchMultipleProfiles(testPubkeys);

      // Small delay to allow debouncing
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - Verify batch subscription was created
      verify(
        () => mockSubscriptionManager.createSubscription(
          name: any(that: contains('profile_batch'), named: 'name'),
          filters: any(
            that: predicate<List<Filter>>((filters) {
              if (filters.isEmpty) return false;
              final filter = filters.first;
              return filter.kinds!.contains(0) &&
                  filter.authors!.length == testPubkeys.length &&
                  testPubkeys.every((pk) => filter.authors!.contains(pk));
            }),
            named: 'filters',
          ),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
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

      // Mock cached profile
      when(
        () => mockCacheService.getCachedProfile(testPubkey),
      ).thenReturn(cachedProfile);

      // Act
      await profileService.initialize();
      final profile = await profileService.fetchProfile(testPubkey);

      // Assert - Verify no subscription was created
      verifyNever(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      );

      // Verify cached profile was returned
      expect(profile, equals(cachedProfile));
      expect(profileService.hasProfile(testPubkey), isTrue);
    });

    test('should handle profile fetch failure gracefully', () async {
      // Arrange
      const testPubkey = 'fail_pubkey_123';

      // Mock subscription creation that will fail
      when(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      ).thenThrow(Exception('Network error'));

      // Act
      await profileService.initialize();
      final profile = await profileService.fetchProfile(testPubkey);

      // Assert - Verify profile fetch returned null on error
      expect(profile, isNull);
      expect(profileService.hasProfile(testPubkey), isFalse);
    });

    test(
      'should provide fallback display name when profile not available',
      () async {
        // Arrange - Use valid 64-char hex pubkey for realistic testing
        const testPubkey =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

        // Act
        await profileService.initialize();
        final displayName = profileService.getDisplayName(testPubkey);

        // Assert - Verify fallback display name is a generated name
        expect(displayName, equals('Integral Cicada 66'));
        expect(profileService.hasProfile(testPubkey), isFalse);
      },
    );
  });
}
