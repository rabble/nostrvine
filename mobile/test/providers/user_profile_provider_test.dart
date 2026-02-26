// ABOUTME: Tests for Riverpod UserProfileProvider state management and profile caching
// ABOUTME: Verifies reactive user profile updates and proper cache management

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/state/user_profile_state.dart';
import 'package:profile_repository/profile_repository.dart';

// Mock classes
class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

class _MockEvent extends Mock implements Event {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockUserProfileService extends Mock implements UserProfileService {}

void main() {
  setUpAll(() {
    registerFallbackValue(_MockEvent());
  });

  group(UserProfileNotifier, () {
    late ProviderContainer container;
    late _MockNostrClient mockNostrService;
    late _MockSubscriptionManager mockSubscriptionManager;
    late UserProfileService userProfileService;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();

      // Default mock for subscription creation: simulates no profile found
      when(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((invocation) async {
        final onComplete =
            invocation.namedArguments[const Symbol('onComplete')]
                as void Function()?;
        if (onComplete != null) {
          Future.delayed(const Duration(milliseconds: 50), onComplete);
        }
        return 'test-subscription-id';
      });

      when(
        () => mockSubscriptionManager.cancelSubscription(any()),
      ).thenAnswer((_) async {});

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);

      // Create a real UserProfileService with mocked dependencies,
      // bypassing the provider chain that requires analyticsApiService etc.
      userProfileService = UserProfileService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
        skipIndexerFallback: true,
      );

      container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
          userProfileServiceProvider.overrideWithValue(userProfileService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      userProfileService.dispose();
    });

    test('should start with initial state', () {
      final state = container.read(userProfileProvider);

      expect(state, equals(UserProfileState.initial));
      expect(state.pendingRequests, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('should initialize properly', () async {
      await container.read(userProfileProvider.notifier).initialize();

      final state = container.read(userProfileProvider);
      expect(state.isInitialized, isTrue);
    });

    test('should use notifier for basic profile management', () async {
      const pubkey = 'test-pubkey-456';

      final mockEvent = _MockEvent();
      when(() => mockEvent.kind).thenReturn(0);
      when(() => mockEvent.pubkey).thenReturn(pubkey);
      when(() => mockEvent.id).thenReturn('event-id-456');
      when(() => mockEvent.createdAt).thenReturn(1234567890);
      when(() => mockEvent.content).thenReturn('{"name":"Notifier Test User"}');
      when(() => mockEvent.tags).thenReturn([]);

      // Override subscription manager to deliver the profile event
      when(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((invocation) async {
        final onEvent =
            invocation.namedArguments[const Symbol('onEvent')]
                as void Function(Event)?;
        final onComplete =
            invocation.namedArguments[const Symbol('onComplete')]
                as void Function()?;

        if (onEvent != null) {
          Future.delayed(
            const Duration(milliseconds: 10),
            () => onEvent(mockEvent),
          );
        }
        if (onComplete != null) {
          Future.delayed(const Duration(milliseconds: 50), onComplete);
        }
        return 'test-subscription-id';
      });

      final profile = await container
          .read(userProfileProvider.notifier)
          .fetchProfile(pubkey);

      expect(profile, isNotNull);
      expect(profile!.pubkey, equals(pubkey));
      expect(profile.name, equals('Notifier Test User'));

      final cachedProfile = container
          .read(userProfileProvider.notifier)
          .getCachedProfile(pubkey);
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.name, equals('Notifier Test User'));
    });

    test('should return cached profile without fetching', () async {
      const pubkey = 'test-pubkey-123';

      final testProfile = UserProfile(
        pubkey: pubkey,
        name: 'Cached User',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'cached-event-id',
      );

      await container
          .read(userProfileProvider.notifier)
          .updateCachedProfile(testProfile);

      final profile = await container
          .read(userProfileProvider.notifier)
          .fetchProfile(pubkey);

      expect(profile, isNotNull);
      expect(profile!.name, equals('Cached User'));
      // Verify no subscription was created (profile was cached)
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
    });

    test('should handle multiple individual profile fetches', () async {
      final pubkeys = ['pubkey1', 'pubkey2', 'pubkey3'];

      for (var i = 0; i < pubkeys.length; i++) {
        final pubkey = pubkeys[i];

        final mockEvent = _MockEvent();
        when(() => mockEvent.kind).thenReturn(0);
        when(() => mockEvent.pubkey).thenReturn(pubkey);
        when(() => mockEvent.id).thenReturn('event-$pubkey');
        when(() => mockEvent.createdAt).thenReturn(1234567890);
        when(() => mockEvent.content).thenReturn('{"name":"User $pubkey"}');
        when(() => mockEvent.tags).thenReturn([]);

        when(
          () => mockSubscriptionManager.createSubscription(
            name: any(named: 'name'),
            filters: any(named: 'filters'),
            onEvent: any(named: 'onEvent'),
            onError: any(named: 'onError'),
            onComplete: any(named: 'onComplete'),
            priority: any(named: 'priority'),
          ),
        ).thenAnswer((invocation) async {
          final onEvent =
              invocation.namedArguments[const Symbol('onEvent')]
                  as void Function(Event)?;
          final onComplete =
              invocation.namedArguments[const Symbol('onComplete')]
                  as void Function()?;

          if (onEvent != null) {
            Future.delayed(
              const Duration(milliseconds: 10),
              () => onEvent(mockEvent),
            );
          }
          if (onComplete != null) {
            Future.delayed(const Duration(milliseconds: 50), onComplete);
          }
          return 'test-subscription-id-$i';
        });

        final profile = await container
            .read(userProfileProvider.notifier)
            .fetchProfile(pubkey);

        expect(profile, isNotNull);
        expect(profile!.pubkey, equals(pubkey));
        expect(profile.name, equals('User $pubkey'));

        final cachedProfile = container
            .read(userProfileProvider.notifier)
            .getCachedProfile(pubkey);
        expect(cachedProfile, isNotNull);
        expect(cachedProfile!.name, equals('User $pubkey'));
      }
    });

    test('should handle profile not found', () async {
      const pubkey = 'non-existent-pubkey';

      // Default mock already simulates no profile found (only calls onComplete)

      final profile = await container
          .read(userProfileProvider.notifier)
          .fetchProfile(pubkey);

      expect(profile, isNull);
    });

    test('should force refresh cached profile', () async {
      const pubkey = 'test-pubkey-123';

      // Pre-populate cache with old profile
      final oldProfile = UserProfile(
        pubkey: pubkey,
        name: 'Old Name',
        rawData: const {},
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        eventId: 'old-event-id',
      );

      await container
          .read(userProfileProvider.notifier)
          .updateCachedProfile(oldProfile);

      // Setup new profile event
      final mockEvent = _MockEvent();
      when(() => mockEvent.kind).thenReturn(0);
      when(() => mockEvent.pubkey).thenReturn(pubkey);
      when(() => mockEvent.id).thenReturn('new-event-id');
      when(
        () => mockEvent.createdAt,
      ).thenReturn(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      when(() => mockEvent.content).thenReturn('{"name":"New Name"}');
      when(() => mockEvent.tags).thenReturn([]);

      when(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      ).thenAnswer((invocation) async {
        final onEvent =
            invocation.namedArguments[const Symbol('onEvent')]
                as void Function(Event)?;
        final onComplete =
            invocation.namedArguments[const Symbol('onComplete')]
                as void Function()?;

        if (onEvent != null) {
          Future.delayed(
            const Duration(milliseconds: 10),
            () => onEvent(mockEvent),
          );
        }
        if (onComplete != null) {
          Future.delayed(const Duration(milliseconds: 50), onComplete);
        }
        return 'test-subscription-refresh-id';
      });

      final profile = await container
          .read(userProfileProvider.notifier)
          .fetchProfile(pubkey, forceRefresh: true);

      expect(profile, isNotNull);
      expect(profile!.name, equals('New Name'));

      verify(
        () => mockSubscriptionManager.createSubscription(
          name: any(named: 'name'),
          filters: any(named: 'filters'),
          onEvent: any(named: 'onEvent'),
          onError: any(named: 'onError'),
          onComplete: any(named: 'onComplete'),
          priority: any(named: 'priority'),
        ),
      ).called(1);
    });

    test('should handle errors gracefully', () async {
      const pubkey = 'error-test-pubkey';

      // Make subscription throw
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

      final profile = await container
          .read(userProfileProvider.notifier)
          .fetchProfile(pubkey);

      expect(profile, isNull);
      expect(container.read(userProfileProvider).error, isNull);
    });
  });

  group('fetchUserProfileProvider', () {
    test('should return profile from repository', () async {
      const pubkey = 'test-pubkey-123';

      final mockProfileRepo = _MockProfileRepository();
      final mockUserProfileService = _MockUserProfileService();

      final testProfile = UserProfile(
        pubkey: pubkey,
        name: 'Test User',
        picture: 'https://example.com/avatar.jpg',
        rawData: const {
          'name': 'Test User',
          'picture': 'https://example.com/avatar.jpg',
        },
        createdAt: DateTime.now(),
        eventId: 'event-id-123',
      );

      when(
        () => mockUserProfileService.shouldSkipProfileFetch(pubkey),
      ).thenReturn(false);
      when(
        () => mockProfileRepo.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => testProfile);

      final container = ProviderContainer(
        overrides: [
          userProfileServiceProvider.overrideWithValue(mockUserProfileService),
          profileRepositoryProvider.overrideWithValue(mockProfileRepo),
        ],
      );
      addTearDown(container.dispose);

      final profile = await container.read(
        fetchUserProfileProvider(pubkey).future,
      );

      expect(profile, isNotNull);
      expect(profile!.pubkey, equals(pubkey));
      expect(profile.name, equals('Test User'));
    });

    test('should return null when profile not found', () async {
      const pubkey = 'missing-pubkey';

      final mockProfileRepo = _MockProfileRepository();
      final mockUserProfileService = _MockUserProfileService();

      when(
        () => mockUserProfileService.shouldSkipProfileFetch(pubkey),
      ).thenReturn(false);
      when(
        () => mockUserProfileService.markProfileAsMissing(pubkey),
      ).thenReturn(null);
      when(
        () => mockProfileRepo.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          userProfileServiceProvider.overrideWithValue(mockUserProfileService),
          profileRepositoryProvider.overrideWithValue(mockProfileRepo),
        ],
      );
      addTearDown(container.dispose);

      final profile = await container.read(
        fetchUserProfileProvider(pubkey).future,
      );

      expect(profile, isNull);
      verify(
        () => mockUserProfileService.markProfileAsMissing(pubkey),
      ).called(1);
    });

    test('should return null when repository is not ready', () async {
      const pubkey = 'test-pubkey';

      final mockUserProfileService = _MockUserProfileService();

      final container = ProviderContainer(
        overrides: [
          userProfileServiceProvider.overrideWithValue(mockUserProfileService),
          profileRepositoryProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final profile = await container.read(
        fetchUserProfileProvider(pubkey).future,
      );

      expect(profile, isNull);
    });
  });
}
