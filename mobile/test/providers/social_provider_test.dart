// ABOUTME: Tests for Riverpod SocialProvider state management and social interactions
// ABOUTME: Verifies reactive follows, reposts functionality
// ABOUTME: Note: Likes are now tested in likes_provider_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/state/social_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock classes
class MockNostrService extends Mock implements NostrClient {}

class MockAuthService extends Mock implements AuthService {}

class MockSubscriptionManager extends Mock implements SubscriptionManager {}

class MockEvent extends Mock implements Event {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(MockEvent());
  });

  group('SocialProvider', () {
    late ProviderContainer container;
    late MockNostrService mockNostrService;
    late MockAuthService mockAuthService;
    late MockSubscriptionManager mockSubscriptionManager;
    late SharedPreferences mockSharedPreferences;

    setUp(() async {
      mockNostrService = MockNostrService();
      mockAuthService = MockAuthService();
      mockSubscriptionManager = MockSubscriptionManager();

      // Initialize mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      mockSharedPreferences = await SharedPreferences.getInstance();

      // Set default auth state to prevent null errors
      when(
        () => mockAuthService.authState,
      ).thenReturn(AuthState.unauthenticated);
      when(() => mockAuthService.isAuthenticated).thenReturn(false);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          authServiceProvider.overrideWithValue(mockAuthService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should start with initial state', () {
      final state = container.read(socialProvider);

      expect(state, equals(SocialState.initial));
      expect(state.repostedEventIds, isEmpty);
      expect(state.followingPubkeys, isEmpty);
      expect(state.followerStats, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('should initialize user social data when authenticated', () async {
      // Setup authenticated user
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('test-pubkey');

      // Mock event streams (filters is a positional parameter)
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());

      // Initialize
      await container.read(socialProvider.notifier).initialize();

      final state = container.read(socialProvider);
      expect(state.isInitialized, isTrue);

      // Verify it tried to load user data
      verify(() => mockNostrService.subscribe(any())).called(greaterThan(0));
      // TODO(any): Fix and re-enable this test
    }, skip: true);

    test('should follow and unfollow users', () async {
      const userToFollow = 'pubkey-to-follow';

      // Setup authenticated user
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('test-pubkey');

      // Mock contact list event creation and broadcast
      final mockContactEvent = MockEvent();
      when(() => mockContactEvent.id).thenReturn('contact-event-id');
      when(
        () => mockAuthService.createAndSignEvent(
          kind: 3,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => mockContactEvent);

      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => mockContactEvent);

      // Follow user
      await container.read(socialProvider.notifier).followUser(userToFollow);

      var state = container.read(socialProvider);
      expect(state.followingPubkeys.contains(userToFollow), isTrue);

      // Unfollow user
      await container.read(socialProvider.notifier).unfollowUser(userToFollow);

      state = container.read(socialProvider);
      expect(state.followingPubkeys.contains(userToFollow), isFalse);
    });

    test('should handle auth race condition during initialization', () async {
      // Test scenario 1: Auth is "checking" - should return early without fetching
      when(() => mockAuthService.authState).thenReturn(AuthState.checking);
      when(() => mockAuthService.isAuthenticated).thenReturn(false);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);

      // Call initialize while auth is still checking
      // This should NOT throw and should return early (before fetching contacts)
      await container.read(socialProvider.notifier).initialize();

      var state = container.read(socialProvider);
      // Should mark as initialized even though no contacts fetched yet
      expect(state.isInitialized, isTrue);
      expect(state.followingPubkeys, isEmpty); // No contacts fetched yet

      // Dispose first container to start fresh for scenario 2
      container.dispose();

      // Test scenario 2: Auth is "authenticated" - should fetch contacts
      mockAuthService = MockAuthService();
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn('test-pubkey-123');

      // Mock event streams (filters is a positional parameter)
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());

      // Create new container with authenticated state
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          authServiceProvider.overrideWithValue(mockAuthService),
          subscriptionManagerProvider.overrideWithValue(
            mockSubscriptionManager,
          ),
        ],
      );

      // Now initialize with auth authenticated
      await container.read(socialProvider.notifier).initialize();

      // Should have attempted to fetch contacts (verify subscription called)
      verify(() => mockNostrService.subscribe(any())).called(greaterThan(0));

      state = container.read(socialProvider);
      expect(state.isInitialized, isTrue);
      // TODO(any): Fix and re-enable this test
    }, skip: true);

    test('should prevent duplicate contact fetches (idempotency)', () async {
      // Setup authenticated user
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('test-pubkey');

      // Mock event streams (filters is a positional parameter)
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());

      // Call initialize multiple times rapidly (simulating race condition)
      final futures = [
        container.read(socialProvider.notifier).initialize(),
        container.read(socialProvider.notifier).initialize(),
        container.read(socialProvider.notifier).initialize(),
      ];

      // Wait for all to complete
      await Future.wait(futures);

      // Verify subscribeToEvents was NOT called 3x (should be called once due to idempotency)
      // The first call should succeed, subsequent calls should see isInitialized=true and return early
      final verificationResult = verify(
        () => mockNostrService.subscribe(any()),
      );

      // Should be called 2 times (once for followList, once for reposts in the first initialize)
      // NOT 6 times (which would be 3 initializes * 2 subscriptions each)
      verificationResult.called(2);

      final state = container.read(socialProvider);
      expect(state.isInitialized, isTrue);
      // TODO(any): Fix and re-enable this test
    }, skip: true);
  });
}
